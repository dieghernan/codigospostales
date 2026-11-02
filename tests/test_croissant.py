"""Read every exported record with the official Croissant library."""

import contextlib
import hashlib
import json
from pathlib import Path
import sqlite3
import struct
import unittest
from urllib.parse import urlsplit

import mlcroissant
import shapely

from scripts.build_croissant import geometry
from scripts.check_site import Page

ROOT = Path(__file__).resolve().parents[1]
# Independent expected schema: a generator change must not silently drop attributes.
EXPECTED_COLUMNS = {
    "codigos_postales": ["fid", "COD_POSTAL", "geometry_wkt"],
    "pendientes": ["fid", "CodProv", "CodMuni", "Municipio", "AREA_M2", "PROVINCIA", "geometry_wkt"],
}


class CroissantTests(unittest.TestCase):
    def test_geopackage_headers_preserve_known_coordinates(self):
        expected = shapely.from_wkt("MULTIPOLYGON (((-18.16 27.63, 4.32 27.63, 4.32 43.8, -18.16 27.63)))")
        for little_endian in (False, True):
            for envelope_code, doubles in ((0, 0), (1, 4), (2, 6), (3, 6), (4, 8)):
                with self.subTest(little_endian=little_endian, envelope=envelope_code):
                    header = b"GP" + bytes([0, (envelope_code << 1) | int(little_endian)])
                    header += struct.pack("<i" if little_endian else ">i", 25830)
                    blob = header + bytes(doubles * 8) + shapely.to_wkb(expected)
                    self.assertTrue(shapely.equals_exact(geometry(blob), expected, tolerance=0))
        with self.assertRaisesRegex(ValueError, "Expected GeoPackage geometry"):
            geometry(shapely.to_wkb(expected))

    def test_descriptor_and_public_pages_agree(self):
        descriptor = json.loads((ROOT / "docs/croissant.json").read_text(encoding="utf-8"))
        for relative in ("_data/croissant.json", "_site/croissant.json"):
            self.assertEqual(descriptor, json.loads((ROOT / "docs" / relative).read_text(encoding="utf-8")))
        for relative in ("index.html", "visor/index.html", "visor/mapa/index.html"):
            dataset, = [item for item in Page(ROOT / "docs/_site" / relative).schemas if item.get("@type") == "Dataset"]
            self.assertEqual(dataset, descriptor)
        self.assertEqual(descriptor["@context"]["description"], "sc:description")
        self.assertEqual(descriptor["@context"]["name"], "sc:name")
        self.assertEqual(descriptor["geocr:coordinateReferenceSystem"], "EPSG:25830")
        self.assertIn("http://mlcommons.org/croissant/geo/1.0", descriptor["conformsTo"])
        citation, = [item for item in descriptor["citation"] if item["identifier"].endswith("15345101")]
        self.assertIn("Municipios2024", citation["description"])
        self.assertEqual(len(citation["author"]), 2)
        self.assertEqual(descriptor["version"], "1.0.0")
        self.assertEqual(len(descriptor["distribution"]), 6)
        for resource in descriptor["distribution"]:
            self.assertIn("sc:DataDownload", resource["@type"])
            self.assertTrue(resource["contentUrl"].startswith("https://"))
            self.assertNotIn("containedIn", resource)

    def test_official_reader_preserves_every_attribute_and_geometry(self):
        descriptor = json.loads((ROOT / "docs/croissant.json").read_text(encoding="utf-8"))
        products = json.loads((ROOT / "docs/_data/products.json").read_text(encoding="utf-8"))
        mapping = {}
        for file in descriptor["distribution"]:
            if file["encodingFormat"] == "application/json":
                relative = urlsplit(file["contentUrl"]).path.split("/codigospostales/", 1)[1]
                path = ROOT / "docs" / relative
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), file["sha256"])
                mapping[file["@id"]] = path
        dataset = mlcroissant.Dataset(jsonld=descriptor, mapping=mapping)
        for key, product in products.items():
            source = ROOT / "data" / product["filename"]
            self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), product["revision"])
            with contextlib.closing(sqlite3.connect(f"{source.as_uri()}?mode=ro", uri=True)) as db:
                for layer, columns in EXPECTED_COLUMNS.items():
                    record_id = key + "-" + layer
                    query = 'SELECT ' + ', '.join('"' + name + '"' for name in columns[:-1]) + ', geom FROM "' + layer + '" ORDER BY fid'
                    expected = db.execute(query)
                    count = 0
                    for actual, row in zip(dataset.records(record_set=record_id), expected, strict=True):
                        count += 1
                        for column, value in zip(columns[:-1], row[:-1]):
                            loaded = actual[record_id + "/" + column]
                            if isinstance(loaded, bytes):
                                loaded = loaded.decode("utf-8")
                            self.assertEqual(loaded, value, (record_id, row[0], column))
                        wkt = actual[record_id + "/geometry_wkt"]
                        self.assertTrue(shapely.equals_exact(geometry(row[-1]), shapely.from_wkt(wkt), tolerance=0), (record_id, row[0]))
                    self.assertEqual(count, product["postal_codes" if layer == "codigos_postales" else "pending"])


if __name__ == "__main__":
    unittest.main()
