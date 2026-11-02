# Croissant and GeoCroissant publication

The landing page and both viewers embed the same Dataset descriptor as
`https://dieghernan.github.io/codigospostales/croissant.json`. Chulapa's JSON-LD,
visible content and microformats remain unchanged.

The descriptor declares Croissant 1.1 and GeoCroissant 1.0. The CRS is
**EPSG:25830**, matching the original GeoPackages. The existing Schema.org
extent, DOI, license, publication dates and methodology remain in place.
The source citation identifies the LAU2boundaries4Spain administrative boundaries
and the Municipios2024, Condominios and Provincias layers used for clipping.

## Resources and records

The two original GeoPackage distributions retain their URLs, versions and dates.
The official mlcroissant reader does not read GeoPackage directly. Additional
gzip-compressed downloads therefore expose each product's two layers as UTF-8 JSON arrays,
with geometry stored as WKT. Non-ASCII characters use JSON Unicode escapes so
the official gzip reader also preserves names on Windows with a legacy default
encoding; decoding yields the original names unchanged. This avoids the CSV reader's numeric inference,
which drops leading zeros from postal and administrative codes even when the
Croissant fields are declared as text.

Four record sets are available:

- `full-codigos_postales`: 10,844 estimated postal areas, original geometry.
- `full-pendientes`: 4,564 unassigned administrative fragments, original geometry.
- `simplified-codigos_postales`: the same postal areas, simplified geometry.
- `simplified-pendientes`: the pending layer from the simplified product.

The `fid` key is unique within each record set. Pending fragments do not acquire
invented postal codes: their entirely null `COD_POSTAL` column is omitted and
this omission is stated in the record-set description. Other attributes are
preserved. `PROVINCIA` contains a provincial code, not a province name.

WKT uses full precision without reprojection or simplification. Generation and
integration tests compare every geometry with its source at zero tolerance,
including coordinate, ring and polygon order. The reader returns WKT as text;
consumers explicitly parse it and assign EPSG:25830 when creating GIS objects.

```python
import mlcroissant as mlc
import shapely

dataset = mlc.Dataset("https://dieghernan.github.io/codigospostales/croissant.json")
record = next(iter(dataset.records(record_set="full-codigos_postales")))
code = record["full-codigos_postales/COD_POSTAL"]
geometry = shapely.from_wkt(record["full-codigos_postales/geometry_wkt"])
# Text can be returned as UTF-8 bytes; decode code if required.
# geometry's coordinates are EPSG:25830; WKT alone does not carry a CRS.
```

## Generate and validate

Use Python 3.12 and the pinned dependencies:

```sh
pip install -r scripts/requirements-croissant.txt
git lfs pull --include="data/codigos_postales.gpkg,data/codigos_postales_simplificado.gpkg" --exclude=""
python scripts/build_croissant.py
mlcroissant validate --jsonld docs/croissant.json
cd docs
bundle exec jekyll build
cd ..
python -m unittest discover -s tests
python scripts/check_site.py
```

The script reads the GeoPackages in read-only mode and verifies their SHA-256
checksums against `docs/_data/products.json`. It writes identical descriptors to
`docs/croissant.json` and `docs/_data/croissant.json`. Compressed JSON files are
generated under
`docs/assets/croissant/<file-sha256>/records.json.gz`, ignored by Git and included
in the published Pages artifact. Fixed gzip timestamps, metadata and compression
make generation reproducible across runs. Checksums cover each compressed file.
Original data files are never rewritten.

The workflow runs `build_croissant.py --check` to regenerate downloads and fail
if committed descriptors differ, then validates and tests before deployment.
Tests map resource URLs to generated local files to exercise the official reader
before publication; after deployment the same URLs work without mapping.
Every distribution is directly downloadable and has both FileObject and
DataDownload types. Internal archive members are avoided because Google reports
their FileObject-only distribution entries as invalid types.
An upstream dependency change that alters generated compressed bytes requires a
reviewed descriptor regeneration. Only downloads referenced by the current
release are published; consumers should retain the descriptor and files for
long-term snapshots. The DOI remains the dataset's persistent citation.

The context's `name` and `description` aliases use plain Schema.org IRIs, avoiding
the language-container definitions rejected by Google's Rich Results Test.

## Updating data

Regenerate `docs/_data/products.json` through the existing product-metadata
workflow first. Review the real version, dates, citation, coverage and any schema
changes, then rebuild Croissant and run the checks above. Do not hand-edit the
generated descriptors or invent new publication dates for the conversion.

Specifications:
- https://docs.mlcommons.org/croissant/docs/croissant-spec-1.1.html
- https://docs.mlcommons.org/croissant/docs/croissant-geo-spec.html
