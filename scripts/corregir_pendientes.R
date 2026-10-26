# Prepara una corrección localizada sin sobrescribir resultados publicados.
if (.Platform$OS.type == "windows") {
  stopifnot(nzchar(Sys.setlocale("LC_CTYPE", "Spanish_Spain.utf8")))
}
library(sf)
library(dplyr)

local({
  origen <- trimws(readLines("data/cartociudad/reejecucion_actual.txt"))
  destino <- Sys.getenv(
    "CP_CORRECCION_DIR",
    file.path(
      "data/cartociudad",
      paste0("correccion_pendientes_", format(Sys.time(), "%Y%m%d_%H%M%S"))
    )
  )
  if (dir.exists(destino)) {
    stop("El directorio de corrección ya existe.")
  }
  dir.create(destino, recursive = TRUE)
  destino <- normalizePath(destino, winslash = "/")
  for (nombre in c(
    "provs",
    "analisis",
    "consolidado",
    "respaldo",
    "evidencia"
  )) {
    dir.create(file.path(destino, nombre))
  }
  provinciales <- list.files(
    "data/provs",
    "^CP_[0-9]{2}[.]gpkg$",
    full.names = TRUE
  )
  stopifnot(length(provinciales) == 52L)
  stopifnot(all(file.copy(provinciales, file.path(destino, "provs"))))
  stopifnot(all(file.copy(provinciales, file.path(destino, "respaldo"))))
  stopifnot(file.copy(
    "data/codigos_postales.gpkg",
    file.path(destino, "respaldo")
  ))
  stopifnot(file.copy("data/avance.png", file.path(destino, "respaldo")))
  stopifnot(all(file.copy(
    list.files("data/full_analisis", full.names = TRUE),
    file.path(destino, "analisis")
  )))
  stopifnot(file.copy(
    "scripts/corregir_pendientes.R",
    file.path(destino, "evidencia")
  ))
  base <- readRDS(file.path(origen, "base_admin.rds"))
  nacional <- st_read(
    "data/codigos_postales.gpkg",
    layer = "codigos_postales",
    quiet = TRUE
  )
  pendientes <- st_read(
    "data/codigos_postales.gpkg",
    layer = "pendientes",
    quiet = TRUE
  )
  prioridad <- readr::read_csv(
    "data/full_analisis/pendientes_priorizacion.csv",
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE
  )
  alcance <- match.arg(
    Sys.getenv("CP_CORRECCION_ALCANCE", "piloto"),
    c("piloto", "monocodigo")
  )
  seleccion <- if (alcance == "piloto") {
    prioridad[grepl(">=99", prioridad$prioridad_revision, fixed = TRUE), ]
  } else {
    prioridad[
      !is.na(prioridad$cp_ine_coincidente) &
        nzchar(prioridad$cp_ine_coincidente) &
        !grepl(";", prioridad$cp_en_muestras, fixed = TRUE) &
        !grepl(";", prioridad$cp_sectores_mayores, fixed = TRUE),
    ]
  }
  stopifnot(nrow(seleccion) == if (alcance == "piloto") 7L else 34L)
  stopifnot(!anyDuplicated(seleccion$LAU_CODE))
  readr::write_csv(
    seleccion,
    file.path(destino, "evidencia/seleccion_recintos.csv")
  )
  writeLines(alcance, file.path(destino, "evidencia/alcance.txt"))
  stopifnot(all(seleccion$cp_ine_coincidente %in% nacional$COD_POSTAL))
  operaciones <- list()
  asignaciones <- list()
  cambios <- list()

  # Identifica un único componente en Gibraltar, sin utilizar un bbox de recorte.
  gap <- pendientes[pendientes$LAU_CODE == "PROV_GAP_11", ]
  partes <- suppressWarnings(st_cast(st_geometry(gap), "POLYGON"))
  punto_gibraltar <- st_sfc(
    st_point(c(-5.348341746262135, 36.13172236017171)),
    crs = 4326
  ) |>
    st_transform(st_crs(pendientes))
  indice <- st_intersects(punto_gibraltar, partes)[[1]]
  stopifnot(length(indice) == 1L)
  exclusion <- partes[indice]
  area_excluida <- sum(as.numeric(st_area(exclusion)))
  stopifnot(abs(area_excluida - 6203289.492664926) < 0.1)
  st_write(
    st_sf(
      motivo = "Fuera del alcance postal español: Gibraltar",
      geometry = exclusion
    ),
    file.path(destino, "evidencia/exclusiones_territoriales.gpkg"),
    quiet = TRUE
  )
  indice_prov <- which(base$provincias$cpro == "11")
  base$provincias <- st_transform(base$provincias, 25830)
  st_geometry(base$provincias)[indice_prov] <- st_difference(
    st_geometry(base$provincias)[indice_prov],
    st_transform(exclusion, st_crs(base$provincias))
  )
  saveRDS(base, file.path(destino, "base_admin_corregida.rds"))

  for (cp in unique(c("11", seleccion$cpro))) {
    archivo <- file.path(destino, "provs", paste0("CP_", cp, ".gpkg"))
    postal <- st_read(archivo, layer = "codigos_postales", quiet = TRUE)
    pendiente <- st_read(archivo, layer = "pendientes", quiet = TRUE)
    if (cp == "11") {
      k <- which(pendiente$LAU_CODE == "PROV_GAP_11")
      st_geometry(pendiente)[k] <- st_difference(
        st_geometry(pendiente)[k],
        st_transform(exclusion, st_crs(pendiente))
      )
    }
    for (codigo in seleccion$LAU_CODE[seleccion$cpro == cp]) {
      fila <- seleccion[seleccion$LAU_CODE == codigo, ]
      cod_postal <- fila$cp_ine_coincidente
      k <- which(pendiente$LAU_CODE == codigo)
      stopifnot(length(k) == 1L)
      region <- st_geometry(pendiente)[k]
      archivos <- list.files(
        "data/cartociudad/analisis_pendientes_ampliado/geometrias_wms",
        pattern = "[.]geojson$",
        full.names = TRUE
      )
      capas <- lapply(archivos, function(f) {
        g <- st_read(f, quiet = TRUE) |>
          st_transform(st_crs(pendiente)) |>
          st_make_valid()
        g$archivo_evidencia <- f
        g |> select(cod_postal, ine_mun, archivo_evidencia)
      }) |>
        bind_rows()
      w <- capas[
        capas$cod_postal == cod_postal &
          lengths(st_intersects(capas, region)) > 0L,
      ]
      stopifnot(nrow(w) > 0L, any(w$ine_mun == codigo))
      evidencia <- unique(w$archivo_evidencia)
      for (f in evidencia) {
        copia <- file.path(destino, "evidencia", basename(f))
        if (!file.exists(copia)) stopifnot(file.copy(f, copia))
      }
      transferida <- suppressWarnings(st_intersection(
        region,
        st_union(st_geometry(w))
      )) |>
        st_make_valid()
      area_respaldada <- sum(as.numeric(st_area(transferida)))
      otras <- capas[
        capas$cod_postal != cod_postal &
          lengths(st_intersects(capas, transferida)) > 0L,
      ]
      if (nrow(otras)) {
        transferida <- st_difference(
          transferida,
          st_union(st_geometry(otras))
        ) |>
          st_make_valid()
        for (f in unique(otras$archivo_evidencia)) {
          copia <- file.path(destino, "evidencia", basename(f))
          if (!file.exists(copia)) stopifnot(file.copy(f, copia))
        }
      }
      stopifnot(
        !any(st_is_empty(transferida)),
        all(st_dimension(transferida) == 2L)
      )
      antes <- sum(as.numeric(st_area(region)))
      area <- sum(as.numeric(st_area(transferida)))
      stopifnot(area > 0, area <= antes + 0.01)
      if (alcance == "piloto") {
        stopifnot(area / antes >= 0.99)
      }
      resto <- st_difference(region, transferida) |> st_make_valid()
      st_geometry(pendiente)[k] <- resto
      destino_cp <- which(postal$COD_POSTAL == cod_postal)
      if (length(destino_cp)) {
        stopifnot(length(destino_cp) == 1L)
        st_geometry(postal)[destino_cp] <- st_union(c(
          st_geometry(postal)[destino_cp],
          transferida
        )) |>
          st_make_valid()
      } else {
        nueva <- st_sf(COD_POSTAL = cod_postal, geometry = transferida)
        columna <- attr(postal, "sf_column")
        names(nueva)[names(nueva) == "geometry"] <- columna
        st_geometry(nueva) <- columna
        postal <- bind_rows(postal, nueva)
      }
      asignaciones[[codigo]] <- st_sf(
        cpro = cp,
        LAU_CODE = codigo,
        COD_POSTAL = cod_postal,
        geometry = st_transform(transferida, 25830)
      )
      operaciones[[codigo]] <- data.frame(
        cpro = cp,
        LAU_CODE = codigo,
        COD_POSTAL = cod_postal,
        pendiente_antes_km2 = antes / 1e6,
        transferido_km2 = area / 1e6,
        conflicto_con_otro_cp_m2 = max(0, area_respaldada - area),
        pendiente_despues_km2 = sum(as.numeric(st_area(resto))) / 1e6,
        evidencia = paste(basename(evidencia), collapse = ";"),
        evidencia_sha256 = paste(
          vapply(
            evidencia,
            function(f) digest::digest(file = f, algo = "sha256"),
            character(1)
          ),
          collapse = ";"
        )
      )
    }
    pendiente <- pendiente[
      !st_is_empty(pendiente) & st_dimension(pendiente) == 2L,
    ]
    geometria <- c(st_geometry(postal), st_geometry(pendiente))
    provincia <- base$provincias[base$provincias$cpro == cp, ] |>
      st_transform(st_crs(postal))
    union <- st_union(geometria)
    diferencia <- sum(as.numeric(st_area(st_sym_difference(
      union,
      st_union(provincia)
    ))))
    solape <- sum(as.numeric(st_area(geometria))) -
      sum(as.numeric(st_area(union)))
    message("VALIDACION ", cp, ": diferencia=", diferencia, ", solape=", solape)
    stopifnot(
      all(st_is_valid(geometria)),
      !any(st_is_empty(geometria)),
      diferencia < 1,
      abs(solape) < 1,
      anyDuplicated(postal$COD_POSTAL) == 0L
    )
    # Escribe un archivo nuevo para no depender de triggers ni de capas antiguas.
    nuevo <- file.path(destino, paste0("nuevo_", cp, ".gpkg"))
    st_write(postal, nuevo, layer = "codigos_postales", quiet = TRUE)
    st_write(pendiente, nuevo, layer = "pendientes", quiet = TRUE)
    stopifnot(file.copy(nuevo, archivo, overwrite = TRUE))
    unlink(nuevo)
    cambios[[cp]] <- data.frame(
      cpro = cp,
      diferencia_m2 = diferencia,
      solape_m2 = solape
    )
    readr::write_csv(
      st_drop_geometry(pendiente),
      file.path(destino, "analisis", paste0("pendientes_", cp, ".csv"))
    )
  }
  readr::write_csv(
    bind_rows(operaciones),
    file.path(destino, "analisis/correcciones_pendientes.csv")
  )
  readr::write_csv(
    bind_rows(cambios),
    file.path(destino, "analisis/validacion_correcciones.csv")
  )
  st_write(
    bind_rows(asignaciones),
    file.path(destino, "evidencia/asignaciones_respaldadas.gpkg"),
    quiet = TRUE
  )
  Sys.setenv(
    CP_OUTPUT_DIR = file.path(destino, "provs"),
    CP_CONSOLIDADO_DIR = file.path(destino, "consolidado"),
    CP_ANALISIS_DIR = file.path(destino, "analisis"),
    CP_BASE_ADMIN_RDS = file.path(destino, "base_admin_corregida.rds")
  )
  source("scripts/ggplot.R", local = TRUE, encoding = "UTF-8")
  nuevo <- st_read(
    file.path(destino, "consolidado/codigos_postales.gpkg"),
    layer = "codigos_postales",
    quiet = TRUE
  )
  stopifnot(
    setequal(nacional$COD_POSTAL, nuevo$COD_POSTAL),
    nrow(nacional) == nrow(nuevo)
  )
  writeLines(destino, "data/cartociudad/correccion_pendientes_actual.txt")
  message("PROPUESTA PREPARADA: ", destino)
})
