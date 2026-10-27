# Copia para visualización; conserva el consolidado de resolución completa.
library(sf)
library(dplyr)
library(rmapshaper)
source("scripts/geometria.R")

archivo <- "data/codigos_postales.gpkg"
salida <- "data/codigos_postales_simplificado.gpkg"
codigos <- st_read(archivo, layer = "codigos_postales", quiet = TRUE)
pendientes <- st_read(archivo, layer = "pendientes", quiet = TRUE)

# Simplifica ambas capas juntas para compartir los contornos comunes.
conjunto <- bind_rows(
  st_sf(ID = seq_len(nrow(codigos)), geometry = st_geometry(codigos)),
  st_sf(
    ID = nrow(codigos) + seq_len(nrow(pendientes)),
    geometry = st_geometry(pendientes)
  )
)
vertices_antes <- nrow(st_coordinates(conjunto))
simplificado <- ms_simplify(
  conjunto,
  keep = 0.2,
  keep_shapes = TRUE,
  explode = TRUE,
  snap = TRUE,
  drop_null_geometries = FALSE
) |>
  st_make_valid() |>
  group_by(ID) |>
  summarise(.groups = "drop") |>
  solo_poligonos()
simplificado <- simplificado[match(conjunto$ID, simplificado$ID), ]
stopifnot(
  identical(simplificado$ID, conjunto$ID),
  all(st_is_valid(simplificado)),
  !any(st_is_empty(simplificado)),
  all(st_geometry_type(simplificado) == "MULTIPOLYGON")
)
st_geometry(codigos) <- st_geometry(simplificado)[seq_len(nrow(codigos))]
st_geometry(pendientes) <- st_geometry(simplificado)[
  nrow(codigos) + seq_len(nrow(pendientes))
]
# AREA_M2 conserva la superficie medida en la versión completa, no simplificada.
st_write(
  codigos,
  salida,
  layer = "codigos_postales",
  append = FALSE,
  quiet = TRUE
)
st_write(pendientes, salida, layer = "pendientes", append = FALSE, quiet = TRUE)
message("Vértices: ", vertices_antes, " → ", nrow(st_coordinates(simplificado)))
message(
  "CP: ",
  nrow(codigos),
  "; pendientes: ",
  nrow(pendientes),
  "; archivo: ",
  salida
)
