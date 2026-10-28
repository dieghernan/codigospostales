"""Refresh the website product facts from the two consolidated GeoPackages.

Run from any directory after updating the published products. Uses only Python's
standard library; does not modify the geographic data.
"""

from contextlib import closing
import hashlib
import json
from pathlib import Path
import sqlite3

ROOT = Path(__file__).resolve().parents[1]


def product(filename):
    path = ROOT / "data" / filename
    with closing(sqlite3.connect(f"{path.as_uri()}?mode=ro", uri=True)) as database:
        dates = dict(database.execute("SELECT table_name, last_change FROM gpkg_contents"))
        count = database.execute("SELECT count(*) FROM codigos_postales").fetchone()[0]
        pending, area = database.execute("SELECT count(*), sum(AREA_M2) FROM pendientes").fetchone()
        prefixes = [row[0] for row in database.execute(
            "SELECT DISTINCT substr(COD_POSTAL, 1, 2) FROM codigos_postales ORDER BY 1"
        )]
    with path.open("rb") as source:
        revision = hashlib.file_digest(source, "sha256").hexdigest()
    return {
        "filename": filename,
        "url": "https://media.githubusercontent.com/media/dieghernan/codigospostales/main/data/" + filename,
        "bytes": path.stat().st_size,
        "size_mb": round(path.stat().st_size / 1_000_000, 1),
        "generated": max(dates.values())[:10],
        "revision": revision,
        "postal_codes": count,
        "pending": pending,
        "pending_km2": round(area / 1_000_000, 2),
        "prefixes": prefixes,
    }


if __name__ == "__main__":
    products = {
        "full": product("codigos_postales.gpkg"),
        "simplified": product("codigos_postales_simplificado.gpkg"),
    }
    destination = ROOT / "docs" / "_data" / "products.json"
    destination.parent.mkdir(exist_ok=True)
    destination.write_text(json.dumps(products, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Product facts updated: {destination.relative_to(ROOT)}")
