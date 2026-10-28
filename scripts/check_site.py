"""Check generated local links, metadata and viewer assets before deployment."""

import argparse
from html.parser import HTMLParser
import json
from pathlib import Path
from urllib.parse import unquote, urljoin, urlsplit


class Page(HTMLParser):
    def __init__(self, path):
        super().__init__(convert_charrefs=True)
        self.links = []
        self.ids = set()
        self.meta = {}
        self.canonicals = []
        self.title = ""
        self.schemas = []
        self._capture = None
        self._text = ""
        self.feed(path.read_text(encoding="utf-8"))

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if attrs.get("id"):
            self.ids.add(attrs["id"])
        if tag in ("a", "link") and attrs.get("href"):
            self.links.append(attrs["href"])
        if tag in ("img", "script", "iframe") and attrs.get("src"):
            self.links.append(attrs["src"])
        if tag == "meta":
            self.meta[attrs.get("name", attrs.get("property", ""))] = attrs.get("content", "")
        if tag == "link" and attrs.get("rel") == "canonical":
            self.canonicals.append(attrs.get("href"))
        if tag == "title" or (tag == "script" and attrs.get("type") == "application/ld+json"):
            self._capture = tag
            self._text = ""

    def handle_data(self, data):
        if self._capture:
            self._text += data

    def handle_endtag(self, tag):
        if tag == self._capture:
            if tag == "title":
                self.title = self._text.strip()
            else:
                self.schemas.append(json.loads(self._text))
            self._capture = None


def check(root, baseurl, origin):
    root = root.resolve()
    pages = {path.resolve(): Page(path) for path in root.rglob("*.html")}
    failures = []
    for path, page in pages.items():
        relative = path.relative_to(root).as_posix()
        page_url = f"{origin}{baseurl}/{relative}"
        for link in page.links:
            target = urlsplit(urljoin(page_url, link))
            if target.scheme not in ("https", "http") or target.netloc != urlsplit(origin).netloc:
                continue
            if baseurl and not target.path.startswith(baseurl + "/"):
                # Other projects on the same GitHub Pages domain are external.
                continue
            local_path = unquote(target.path[len(baseurl):]).lstrip("/")
            destination = (root / local_path).resolve()
            if destination.is_dir():
                destination /= "index.html"
            if not destination.is_relative_to(root) or not destination.exists():
                failures.append(f"{relative}: broken local link {link}")
            elif target.fragment and destination in pages and unquote(target.fragment) not in pages[destination].ids:
                failures.append(f"{relative}: missing anchor {link}")

    required = ["index.html", "visor/index.html", "visor/mapa/index.html", "ejemplos/index.html"]
    titles = []
    for name in required:
        page = pages.get((root / name).resolve())
        if page is None:
            failures.append(f"Missing page: {name}")
            continue
        titles.append(page.title)
        expected = origin + baseurl + "/" + name.removesuffix("index.html")
        if not page.title or not page.meta.get("description"):
            failures.append(f"{name}: missing title/description")
        if page.canonicals != [expected]:
            failures.append(f"{name}: invalid canonical {page.canonicals}")
        for key in ("og:title", "og:description", "og:image", "twitter:title", "twitter:image", "viewport"):
            if not page.meta.get(key):
                failures.append(f"{name}: missing {key}")
        if "noindex" in page.meta.get("robots", ""):
            failures.append(f"{name}: unexpectedly noindex")
    if len(set(titles)) != len(titles):
        failures.append("Main pages must have distinct titles")
    home = pages.get((root / "index.html").resolve())
    datasets = [item for item in home.schemas if item.get("@type") == "Dataset"] if home else []
    if len(datasets) != 1 or len(datasets[0].get("distribution", [])) != 2:
        failures.append("Home must describe one Dataset with two distributions")
    data = root / "assets/data"
    prefixes = json.loads((data / "prefijos.json").read_text(encoding="utf-8"))
    for prefix in prefixes:
        path = data / f"cp-{prefix}.geojson"
        if not path.is_file():
            failures.append(f"Missing viewer asset: {path.name}")
    if not prefixes:
        failures.append("Empty viewer prefix catalogue")
    if failures:
        raise SystemExit("\n".join(failures))
    print(f"Site checks passed: {len(pages)} HTML pages, local links, metadata and viewer assets.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--site", type=Path, default=Path("docs/_site"))
    parser.add_argument("--baseurl", default="/codigospostales")
    parser.add_argument("--origin", default="https://dieghernan.github.io")
    args = parser.parse_args()
    check(args.site, args.baseurl.rstrip("/"), args.origin.rstrip("/"))
