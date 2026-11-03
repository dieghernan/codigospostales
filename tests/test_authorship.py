"""Check authorship in the generated project pages, including the custom map."""

from pathlib import Path
import unittest

import mf2py

SITE = Path(__file__).resolve().parents[1] / "docs/_site"
HOME = "https://dieghernan.github.io/"
PROJECT = HOME + "codigospostales/"


class AuthorshipTests(unittest.TestCase):
    def test_pages_identify_the_author_with_the_visual_card_hidden(self):
        for relative in ("index.html", "visor/index.html", "visor/mapa/index.html", "ejemplos/index.html"):
            with self.subTest(page=relative):
                url = PROJECT + relative.removesuffix("index.html")
                parsed = mf2py.parse(doc=(SITE / relative).read_text(encoding="utf-8"), url=url)
                entry, = [item for item in parsed["items"] if "h-entry" in item["type"]]
                self.assertEqual(entry["properties"]["url"], [url])
                author, = entry["properties"]["author"]
                self.assertIn("h-card", author["type"])
                self.assertEqual(author["properties"]["name"], ["Diego HH"])
                self.assertEqual(author["properties"]["url"], [HOME])


if __name__ == "__main__":
    unittest.main()
