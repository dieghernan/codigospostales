# Consolida los resultados provinciales y mantiene separados los pendientes.
local({
  library(ggplot2)
  library(dplyr)
  library(sf)
  library(mapSpain)
  metodo <- file.path(Sys.getenv("CP_METODO_DIR", "scripts"), "correcciones.R")
  source(
    if (file.exists(metodo)) metodo else "scripts/correcciones.R",
    local = TRUE,
    encoding = "UTF-8"
  )
  entrada <- Sys.getenv("CP_OUTPUT_DIR", "data/provs")
  destino <- Sys.getenv("CP_CONSOLIDADO_DIR", "data")
  analisis <- Sys.getenv("CP_ANALISIS_DIR", "data/full_analisis")
  dir.create(destino, recursive = TRUE, showWarnings = FALSE)
  dir.create(analisis, recursive = TRUE, showWarnings = FALSE)
  archivos <- list.files(
    entrada,
    pattern = "^CP_[0-9]{2}[.]gpkg$",
    full.names = TRUE
  )
  if (!length(archivos)) {
    stop("No hay GeoPackage provinciales para consolidar.")
  }
  capas <- lapply(archivos, function(archivo) {
    capa <- st_read(archivo, layer = "codigos_postales", quiet = TRUE)
    capa$COD_POSTAL <- as.character(capa$COD_POSTAL)
    capa |>
      filter(!is.na(COD_POSTAL)) |>
      select(COD_POSTAL) |>
      st_transform(25830)
  })
  codigos <- bind_rows(capas) |>
    group_by(COD_POSTAL) |>
    summarise(.groups = "drop") |>
    st_make_valid(geos_method = "valid_linework")
  codigos <- normalizar_poligonos(codigos)
  codigos <- limpiar_ranuras_numericas(codigos)$postal
  pendientes <- lapply(archivos, function(archivo) {
    if (!"pendientes" %in% st_layers(archivo)$name) {
      return(NULL)
    }
    st_read(archivo, layer = "pendientes", quiet = TRUE) |> st_transform(25830)
  }) |>
    bind_rows() |>
    st_make_valid(geos_method = "valid_linework") |>
    normalizar_poligonos()
  if (anyDuplicated(codigos$COD_POSTAL) || !all(st_is_valid(codigos))) {
    stop(
      "El consolidado no supera la validación de códigos únicos o geometrías."
    )
  }
  provisional <- tempfile("consolidado_", tmpdir = destino, fileext = ".gpkg")
  st_write(codigos, provisional, layer = "codigos_postales", quiet = TRUE)
  if (inherits(pendientes, "sf")) {
    st_write(pendientes, provisional, layer = "pendientes", quiet = TRUE)
    readr::write_csv(
      st_drop_geometry(pendientes),
      file.path(analisis, "missing.csv")
    )
  }
  if (
    !file.copy(
      provisional,
      file.path(destino, "codigos_postales.gpkg"),
      overwrite = TRUE
    )
  ) {
    stop("No se ha podido guardar el consolidado.")
  }
  unlink(provisional)
  base_path <- Sys.getenv("CP_BASE_ADMIN_RDS", "")
  provincias <- if (nzchar(base_path)) {
    readRDS(base_path)$provincias
  } else {
    esp_get_prov_siane(moveCAN = FALSE)
  }
  provincias <- st_transform(provincias, st_crs(codigos))
  mapa <- ggplot(provincias) +
    geom_sf(linewidth = 0.1, fill = "grey95") +
    geom_sf(data = codigos, fill = "blue", linewidth = 0.03)
  if (inherits(pendientes, "sf") && nrow(pendientes)) {
    mapa <- mapa + geom_sf(data = pendientes, fill = "orange", linewidth = 0.03)
  }
  mapa <- mapa +
    theme_void() +
    theme(plot.title = element_text(hjust = 0.5)) +
    labs(
      title = "Grado de avance",
      caption = "Azul: códigos postales. Naranja: recintos pendientes de asignación."
    )
  ggsave(
    file.path(destino, "avance.png"),
    mapa,
    width = 9,
    height = 7,
    units = "in",
    dpi = 300,
    bg = "white"
  )
})
