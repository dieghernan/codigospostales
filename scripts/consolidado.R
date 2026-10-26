library(ggplot2)
library(dplyr)
library(sf)
library(mapSpain)
source("scripts/geometria.R")

# Une todos
files <- list.files(
  "data/provs",
  pattern = "^CP_[0-9]{2}[.]gpkg$",
  full.names = TRUE
)

if (length(files) == 0L) {
  stop("No hay resultados provinciales en data/provs/.")
}

all <- lapply(files, function(file) {
  capa <- tools::file_path_sans_ext(basename(file))
  x <- st_read(file, layer = capa, quiet = TRUE) |>
    st_transform(25830) |>
    solo_poligonos()
  x$COD_POSTAL <- normalizar_cp(x$COD_POSTAL)
  x
})

all <- bind_rows(all)

# Un CP puede abarcar varias provincias: disolver sin filtrar por su prefijo.
codigos <- all |>
  filter(!is.na(COD_POSTAL)) |>
  select(COD_POSTAL) |>
  group_by(COD_POSTAL) |>
  summarise(.groups = "drop") |>
  solo_poligonos()

pendientes <- lapply(files, function(file) {
  capas <- st_layers(file)$name
  if ("pendientes" %in% capas) {
    x <- st_read(file, layer = "pendientes", quiet = TRUE)
  } else {
    capa <- tools::file_path_sans_ext(basename(file))
    x <- st_read(file, layer = capa, quiet = TRUE) |>
      filter(is.na(COD_POSTAL))
  }
  x <- solo_poligonos(x)
  x$AREA_M2 <- as.numeric(st_area(x))
  x <- st_transform(x, 25830) |> solo_poligonos()
  x$PROVINCIA <- rep(substr(basename(file), 4, 5), nrow(x))
  x
}) |>
  bind_rows()

codigos <- limpiar_anillos(codigos, pendientes)
st_write(
  codigos,
  "data/codigos_postales.gpkg",
  layer = "codigos_postales",
  append = FALSE,
  quiet = TRUE
)
st_write(
  pendientes,
  "data/codigos_postales.gpkg",
  layer = "pendientes",
  append = FALSE,
  quiet = TRUE
)

provs <- st_read(
  "data/cartociudad/LAU2boundaries4Spain.gpkg",
  layer = "Provincias",
  quiet = TRUE
) |>
  st_transform(st_crs(all))

p <- ggplot(provs) +
  geom_sf(size = 0.01) +
  geom_sf(data = codigos, fill = "blue", size = 0.01) +
  theme_void() +
  theme(plot.title = element_text(hjust = .5)) +
  labs(title = "Grado de avance")

ggsave("data/avance.png", p, dpi = 300)


# Registros provinciales sin CP, excluidos del producto consolidado.

pendientes |>
  st_drop_geometry() |>
  filter(is.na(COD_POSTAL)) |>
  readr::write_csv("data//full_analisis/missing.csv")
