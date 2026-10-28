"""Regression checks for publication failures and product facts (standard library)."""

import contextlib
import hashlib
import io
import json
from pathlib import Path
import sqlite3
import tempfile
import unittest
from unittest.mock import patch

from scripts.check_site import check
from scripts import product_metadata


def built_site(root):
    for name in ("index.html", "visor/index.html", "visor/mapa/index.html", "ejemplos/index.html"):
        path = root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        canonical = "https://example.org/project/" + name.removesuffix("index.html")
        metadata = "".join(f'<meta name="{key}" content="Example">' for key in (
            "description", "og:title", "og:description", "og:image", "twitter:title", "twitter:image", "viewport"
        ))
        schema = json.dumps({"@type": "Dataset", "distribution": [{}, {}]})
        path.write_text(f'<title>{name}</title>{metadata}<link rel="canonical" href="{canonical}">'
                        f'<script type="application/ld+json">{schema}</script><h1 id="content">Example</h1>', encoding="utf-8")
    data = root / "assets/data"
    data.mkdir(parents=True)
    (data / "prefijos.json").write_text('["08"]', encoding="utf-8")
    (data / "cp-08.geojson").write_text('{}', encoding="utf-8")


class PublicationChecks(unittest.TestCase):
    def test_valid_site_passes(self):
        with tempfile.TemporaryDirectory() as folder, contextlib.redirect_stdout(io.StringIO()):
            root = Path(folder)
            built_site(root)
            check(root, "/project", "https://example.org")

    def test_missing_anchor_blocks_publication(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            built_site(root)
            with (root / "index.html").open("a", encoding="utf-8") as page:
                page.write('<a href="/project/visor/#missing">Map</a>')
            with self.assertRaisesRegex(SystemExit, "missing anchor"):
                check(root, "/project", "https://example.org")

    def test_missing_metadata_blocks_publication(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            built_site(root)
            page = root / "visor/index.html"
            page.write_text(page.read_text(encoding="utf-8").replace('name="description"', 'name="removed"'), encoding="utf-8")
            with self.assertRaisesRegex(SystemExit, "missing title/description"):
                check(root, "/project", "https://example.org")

    def test_missing_viewer_asset_blocks_publication(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            built_site(root)
            (root / "assets/data/cp-08.geojson").unlink()
            with self.assertRaisesRegex(SystemExit, "Missing viewer asset"):
                check(root, "/project", "https://example.org")

    def test_product_facts_come_from_file_contents(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "data").mkdir()
            path = root / "data/sample.gpkg"
            with contextlib.closing(sqlite3.connect(path)) as db:
                db.executescript("""
                    CREATE TABLE gpkg_contents (table_name TEXT, last_change TEXT);
                    INSERT INTO gpkg_contents VALUES ('codigos_postales', '2024-03-01T12:00:00Z');
                    INSERT INTO gpkg_contents VALUES ('pendientes', '2024-03-02T12:00:00Z');
                    CREATE TABLE codigos_postales (COD_POSTAL TEXT);
                    INSERT INTO codigos_postales VALUES ('08001'), ('28013');
                    CREATE TABLE pendientes (AREA_M2 REAL);
                    INSERT INTO pendientes VALUES (1250000);
                """)
                db.commit()
            original = path.read_bytes()
            with patch.object(product_metadata, "ROOT", root):
                facts = product_metadata.product("sample.gpkg")
            self.assertEqual(facts["generated"], "2024-03-02")
            self.assertEqual(facts["postal_codes"], 2)
            self.assertEqual(facts["prefixes"], ["08", "28"])
            self.assertEqual(facts["pending_km2"], 1.25)
            self.assertEqual(facts["bytes"], len(original))
            self.assertEqual(facts["revision"], hashlib.sha256(original).hexdigest())
            self.assertEqual(path.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
