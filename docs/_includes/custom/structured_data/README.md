# Project structured data

These includes generate only the project's Dataset and WebApplication JSON-LD.
They do not replace Chulapa's markup or modify the existing author plugin.

`docs/_data/structured_data.json` holds the shared creator, dataset description,
provenance, reuse terms, application settings and distribution definitions.
`docs/_data/products.json` remains the source of computed file sizes, URLs,
generation dates and product versions; do not copy these values into templates.

`dataset.html` describes the same dataset on the landing page and both viewers.
`application.html` links each viewer to that dataset using its stable identifier.
`distribution.html` and `release.html` resolve each product's own metadata.
The publication date is distinct from file generation dates and source freshness.

Build from `docs/` with `bundle exec jekyll build`, then run
`py -m unittest discover -s tests -p test_site_checks.py` from the repository root.
The checks compare both viewers' datasets with the landing page and validate
file metadata against the generated product catalog.
