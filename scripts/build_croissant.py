"""Generate Croissant metadata and lossless JSON/WKT views of both GeoPackages."""

import argparse
import contextlib
import hashlib
import io
import json
from pathlib import Path
import sqlite3
import zipfile

import shapely

ROOT = Path(__file__).resolve().parents[1]
HOME = "https://dieghernan.github.io/codigospostales/"
LAYERS = {
    "codigos_postales": ["fid", "COD_POSTAL", "geometry_wkt"],
    "pendientes": ["fid", "CodProv", "CodMuni", "Municipio", "AREA_M2", "PROVINCIA", "geometry_wkt"],
}
DESCRIPTIONS = {
    "fid": "Identificador de la entidad en su capa del GeoPackage de origen.",
    "COD_POSTAL": "Código postal estimado; texto de cinco caracteres, incluidos ceros iniciales.",
    "CodProv": "Código provincial del recinto administrativo, conservado como texto.",
    "CodMuni": "Código municipal del recinto administrativo, conservado como texto.",
    "Municipio": "Nombre del municipio del recinto pendiente de asignación.",
    "AREA_M2": "Superficie del recinto pendiente en metros cuadrados, tal como figura en el GeoPackage.",
    "PROVINCIA": "Código provincial presente en el campo PROVINCIA del GeoPackage.",
    "geometry_wkt": "Geometría MultiPolygon en WKT, sin reproyección ni redondeo de coordenadas; EPSG:25830.",
}


def geometry(blob):
    """Remove the GeoPackage binary header without changing its WKB coordinates."""
    if blob[:2] != b"GP":
        raise ValueError("Expected GeoPackage geometry.")
    envelope = (blob[3] >> 1) & 7
    offset = 8 + {0: 0, 1: 32, 2: 48, 3: 48, 4: 64}[envelope]
    return shapely.from_wkb(blob[offset:])


def export_layer(db, layer):
    columns = LAYERS[layer]
    records = []
    attributes = columns[:-1]
    query = 'SELECT ' + ', '.join('"' + name + '"' for name in attributes) + ', geom FROM "' + layer + '" ORDER BY fid'
    for *values, blob in db.execute(query):
        geom = geometry(blob)
        wkt = shapely.to_wkt(geom, rounding_precision=-1)
        # Reject any conversion that changes a coordinate, ring or polygon order.
        if not shapely.equals_exact(geom, shapely.from_wkt(wkt), tolerance=0):
            raise ValueError(f"WKT changed coordinates in {layer}: {values[0]}")
        records.append(dict(zip(columns, [*values, wkt])))
    return json.dumps(records, ensure_ascii=False, separators=(",", ":"), allow_nan=False).encode("utf-8")


def archive(path, product):
    content = path.read_bytes()
    if hashlib.sha256(content).hexdigest() != product["revision"]:
        raise ValueError(f"Product metadata does not match {path}; regenerate product metadata first.")
    tables = {}
    with contextlib.closing(sqlite3.connect(f"{path.as_uri()}?mode=ro", uri=True)) as db:
        for layer in LAYERS:
            crs, kind = db.execute("SELECT srs_id, geometry_type_name FROM gpkg_geometry_columns WHERE table_name = ?", (layer,)).fetchone()
            if (crs, kind) != (25830, "MULTIPOLYGON"):
                raise ValueError(f"Unexpected CRS or geometry type in {layer}.")
            if layer == "pendientes" and db.execute("SELECT COUNT(*) FROM pendientes WHERE COD_POSTAL IS NOT NULL").fetchone()[0]:
                raise ValueError("Pending layer now has postal assignments; review its schema.")
            tables[layer] = export_layer(db, layer)
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as zipped:
        for layer, content in tables.items():
            info = zipfile.ZipInfo(layer + ".json", date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            zipped.writestr(info, content, compresslevel=6)
    return output.getvalue(), tables


def build(check=False):
    metadata = json.loads((ROOT / "docs/_data/structured_data.json").read_text(encoding="utf-8"))
    products = json.loads((ROOT / "docs/_data/products.json").read_text(encoding="utf-8"))
    context = json.loads((ROOT / "docs/_data/croissant_context.json").read_text(encoding="utf-8"))
    dataset = {**metadata["dataset"], "@context": context, "@type": "Dataset", "@id": HOME + "#dataset", "url": HOME,
               "creator": metadata["creator"], **metadata["publication"], "dateModified": products["full"]["generated"],
               "version": products["full"]["version"], "citeAs": metadata["croissant"]["citeAs"],
               "conformsTo": ["http://mlcommons.org/croissant/1.1", "http://mlcommons.org/croissant/geo/1.0"],
               "geocr:coordinateReferenceSystem": "EPSG:25830", "distribution": [], "recordSet": []}
    # Preserve the two original downloads and their existing URLs, dates and versions.
    for definition in metadata["distributions"]:
        key = definition["product"]
        product = products[key]
        dataset["distribution"].append({"@type": ["cr:FileObject", "sc:DataDownload"], "@id": key + "-gpkg",
            "name": definition["name"], "encodingFormat": definition["encodingFormat"], "contentUrl": product["url"],
            "contentSize": f'{product["bytes"]} bytes', "sha256": product["revision"],
            "dateModified": product["generated"], "version": product["version"]})
    archives = set()
    for key, product in products.items():
        content, tables = archive(ROOT / "data" / product["filename"], product)
        digest = hashlib.sha256(content).hexdigest()
        relative = f"assets/croissant/{digest}/records.zip"
        path = ROOT / "docs" / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        archives.add(path.resolve())
        dataset["distribution"].append({"@type": ["cr:FileObject", "sc:DataDownload"], "@id": key + "-json-zip",
            "name": definition_name(key) + " (JSON/WKT)", "description": "Dos capas en JSON; los recintos pendientes carecen de código postal. Coordenadas originales en EPSG:25830.",
            "contentUrl": HOME + relative, "encodingFormat": "application/zip", "contentSize": f"{len(content)} bytes",
            "sha256": digest, "dateModified": product["generated"], "version": product["version"]})
        for layer, table in tables.items():
            file_id, record_id = key + "-" + layer + "-json", key + "-" + layer
            dataset["distribution"].append({"@type": "cr:FileObject", "@id": file_id, "name": layer + ".json",
                "containedIn": {"@id": key + "-json-zip"}, "contentUrl": layer + ".json", "encodingFormat": "application/json",
                "sha256": hashlib.sha256(table).hexdigest()})
            fields = []
            for column in LAYERS[layer]:
                fields.append({"@type": "cr:Field", "@id": record_id + "/" + column, "name": column,
                    "description": DESCRIPTIONS[column], "dataType": "sc:Integer" if column == "fid" else "sc:Float" if column == "AREA_M2" else "sc:Text",
                    "source": {"fileObject": {"@id": file_id}, "extract": {"jsonPath": "$[*]." + column}}})
            dataset["recordSet"].append({"@type": "cr:RecordSet", "@id": record_id, "name": record_id,
                "description": definition_name(key) + ": " + ("áreas con código postal estimado." if layer == "codigos_postales" else "recintos sin código postal asignado; se omite COD_POSTAL, que es nulo en toda esta capa."),
                "key": {"@id": record_id + "/fid"}, "field": fields})
    # Remove only obsolete generated archives from this dedicated output folder.
    for path in (ROOT / "docs/assets/croissant").glob("*/records.zip"):
        if path.resolve() not in archives:
            path.unlink()
            if not any(path.parent.iterdir()):
                path.parent.rmdir()
    output = json.dumps(dataset, ensure_ascii=False, indent=2) + "\n"
    for path in (ROOT / "docs/croissant.json", ROOT / "docs/_data/croissant.json"):
        if check:
            if not path.exists() or path.read_text(encoding="utf-8") != output:
                raise ValueError(f"Stale descriptor: {path}. Run scripts/build_croissant.py.")
        else:
            path.write_text(output, encoding="utf-8", newline="\n")
    return dataset


def definition_name(key):
    return "Consolidado completo" if key == "full" else "Consolidado simplificado"


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    build(check=parser.parse_args().check)
