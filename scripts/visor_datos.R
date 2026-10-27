# Exporta la copia simplificada para el visor, por prefijo postal.
library(sf)

cp <- st_read(
  "data/codigos_postales_simplificado.gpkg",
  layer = "codigos_postales",
  quiet = TRUE
)
stopifnot(
  nrow(cp) > 0L,
  all(grepl("^[0-9]{5}$", cp$COD_POSTAL)),
  !anyDuplicated(cp$COD_POSTAL),
  !any(st_is_empty(cp))
)
cp <- st_transform(cp["COD_POSTAL"], 4326)
prefijos <- sort(unique(substr(cp$COD_POSTAL, 1, 2)))
destino <- "docs/assets/data"
dir.create(destino, recursive = TRUE, showWarnings = FALSE)

for (prefijo in prefijos) {
  datos <- cp[substr(cp$COD_POSTAL, 1, 2) == prefijo, ]
  st_write(
    datos,
    file.path(destino, paste0("cp-", prefijo, ".geojson")),
    driver = "GeoJSON",
    delete_dsn = TRUE,
    layer_options = "COORDINATE_PRECISION=6",
    quiet = TRUE
  )
}
jsonlite::write_json(
  prefijos,
  file.path(destino, "prefijos.json"),
  auto_unbox = FALSE
)
message(length(prefijos), " dominios postales exportados para el visor.")
