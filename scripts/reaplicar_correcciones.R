# Reaplica la evidencia validada exclusivamente sobre pendientes de un lote nuevo.
if (.Platform$OS.type == "windows") {
  stopifnot(nzchar(Sys.setlocale("LC_CTYPE", "Spanish_Spain.utf8")))
}
library(sf)
library(dplyr)

local({
  raiz <- Sys.getenv("CP_REAPLICACION_DIR", "")
  if (!nzchar(raiz)) {
    stop("Indica CP_REAPLICACION_DIR con el lote provisional.")
  }
  raiz <- normalizePath(raiz, winslash = "/")
  stopifnot(file.exists(file.path(raiz, "GENERACION_VALIDADA.txt")))
  if (file.exists(file.path(raiz, "PUBLICADO.txt"))) {
    stop("No se puede modificar un lote ya publicado.")
  }
  evidencia <- "data/evidencia_correcciones"
  manifiesto <- jsonlite::read_json(file.path(evidencia, "manifest.json"))
  for (fila in manifiesto) {
    stopifnot(identical(
      digest::digest(
        file = file.path(evidencia, fila$archivo),
        algo = "sha256"
      ),
      fila$sha256
    ))
  }
  asignaciones <- st_read(
    file.path(evidencia, "asignaciones_respaldadas.gpkg"),
    quiet = TRUE
  )
  base <- readRDS(file.path(raiz, "base_admin.rds"))
  respaldo <- file.path(raiz, "brutos_wms")
  dir.create(respaldo, showWarnings = FALSE)
  estado_bruto <- file.path(raiz, "estado_bruto.csv")
  if (!file.exists(estado_bruto)) {
    stopifnot(file.copy(file.path(raiz, "estado.csv"), estado_bruto))
  }
  estado <- readr::read_csv(
    estado_bruto,
    col_types = readr::cols(cpro = readr::col_character()),
    show_col_types = FALSE
  )
  operaciones <- list()
  transferencias <- list()
  for (cp in unique(asignaciones$cpro)) {
    nombre <- paste0("CP_", cp, ".gpkg")
    archivo <- file.path(raiz, "provs", nombre)
    original <- file.path(respaldo, nombre)
    if (!file.exists(original)) {
      stopifnot(file.copy(archivo, original))
    }
    stopifnot(identical(
      digest::digest(file = original, algo = "sha256"),
      estado$salida_sha256[match(cp, estado$cpro)]
    ))
    postal <- st_read(original, layer = "codigos_postales", quiet = TRUE)
    pendiente <- st_read(original, layer = "pendientes", quiet = TRUE)
    evidencia_cp <- asignaciones[asignaciones$cpro == cp, ] |>
      st_transform(st_crs(postal))
    for (i in seq_len(nrow(evidencia_cp))) {
      recinto <- evidencia_cp$LAU_CODE[i]
      codigo <- evidencia_cp$COD_POSTAL[i]
      k <- which(pendiente$LAU_CODE == recinto)
      stopifnot(length(k) == 1L)
      region <- st_geometry(pendiente)[k]
      g <- st_geometry(evidencia_cp[i, ])
      transferida <- suppressWarnings(st_intersection(region, g)) |>
        st_make_valid()
      fuera <- sum(as.numeric(st_area(st_difference(g, region))))
      if (fuera >= 1) {
        stop(
          "Revisar evidencia fuera de los nuevos pendientes en ",
          recinto,
          ": ",
          fuera,
          " m²."
        )
      }
      otras <- postal[postal$COD_POSTAL != codigo, ]
      disputa <- sum(as.numeric(st_area(suppressWarnings(st_intersection(
        transferida,
        st_union(st_geometry(otras))
      )))))
      if (disputa >= 1) {
        stop(
          "Revisar asignación incompatible en ",
          recinto,
          ": ",
          disputa,
          " m²."
        )
      }
      if (disputa > 0) {
        transferida <- st_difference(transferida, st_union(st_geometry(otras)))
      }
      area <- sum(as.numeric(st_area(transferida)))
      stopifnot(area > 0, all(st_is_valid(transferida)))
      resto <- st_difference(region, transferida) |> st_make_valid()
      st_geometry(pendiente)[k] <- resto
      destino <- which(postal$COD_POSTAL == codigo)
      if (length(destino)) {
        stopifnot(length(destino) == 1L)
        st_geometry(postal)[destino] <- st_union(c(
          st_geometry(postal)[destino],
          transferida
        )) |>
          st_make_valid()
      } else {
        nueva <- st_sf(COD_POSTAL = codigo, geometry = transferida)
        columna <- attr(postal, "sf_column")
        names(nueva)[names(nueva) == "geometry"] <- columna
        st_geometry(nueva) <- columna
        postal <- bind_rows(postal, nueva)
      }
      operaciones[[recinto]] <- data.frame(
        cpro = cp,
        LAU_CODE = recinto,
        COD_POSTAL = codigo,
        pendiente_antes_km2 = sum(as.numeric(st_area(region))) / 1e6,
        transferido_km2 = area / 1e6,
        fuera_de_nuevo_pendiente_m2 = fuera,
        conflicto_con_otro_cp_m2 = disputa,
        pendiente_despues_km2 = sum(as.numeric(st_area(resto))) / 1e6
      )
      transferencias[[recinto]] <- st_sf(
        cpro = cp,
        LAU_CODE = recinto,
        COD_POSTAL = codigo,
        geometry = st_transform(transferida, 25830)
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
      st_union(st_geometry(provincia))
    ))))
    solape <- sum(as.numeric(st_area(geometria))) -
      sum(as.numeric(st_area(union)))
    stopifnot(
      all(st_is_valid(geometria)),
      !any(st_is_empty(geometria)),
      diferencia < 1,
      abs(solape) < 1,
      anyDuplicated(postal$COD_POSTAL) == 0L
    )
    temporal <- tempfile(
      paste0("wms_", cp, "_"),
      tmpdir = raiz,
      fileext = ".gpkg"
    )
    st_write(postal, temporal, layer = "codigos_postales", quiet = TRUE)
    st_write(pendiente, temporal, layer = "pendientes", quiet = TRUE)
    stopifnot(file.copy(temporal, archivo, overwrite = TRUE))
    unlink(temporal)
    analisis <- file.path(raiz, "analisis")
    readr::write_csv(
      st_drop_geometry(pendiente),
      file.path(analisis, paste0("pendientes_", cp, ".csv"))
    )
    ausentes_path <- file.path(
      analisis,
      paste0("codigos_ausentes_", cp, ".csv")
    )
    ausentes <- readr::read_csv(
      ausentes_path,
      col_types = readr::cols(COD_POSTAL = readr::col_character()),
      show_col_types = FALSE
    )
    ausentes <- ausentes[!ausentes$COD_POSTAL %in% postal$COD_POSTAL, ]
    readr::write_csv(ausentes, ausentes_path)
    validacion_path <- file.path(analisis, paste0("validacion_", cp, ".csv"))
    validacion <- readr::read_csv(
      validacion_path,
      col_types = readr::cols(cpro = readr::col_character()),
      show_col_types = FALSE
    )
    validacion$codigos <- nrow(postal)
    validacion$recintos_pendientes <- nrow(pendiente)
    validacion$pendientes_m2 <- sum(as.numeric(st_area(pendiente)))
    validacion$diferencia_m2 <- diferencia
    validacion$solape_m2 <- solape
    validacion$ausentes <- paste(ausentes$COD_POSTAL, collapse = ";")
    validacion$perdidos_dentro_provincia <- sum(ausentes$dentro_provincia > 0)
    readr::write_csv(validacion, validacion_path)
  }
  readr::write_csv(
    bind_rows(operaciones),
    file.path(raiz, "analisis/reaplicacion_wms.csv")
  )
  st_write(
    bind_rows(transferencias),
    file.path(raiz, "asignaciones_reaplicadas.gpkg"),
    delete_dsn = TRUE,
    quiet = TRUE
  )
  estado$salida_bruta_sha256 <- estado$salida_sha256
  estado$salida_sha256 <- vapply(
    estado$cpro,
    function(cp) {
      digest::digest(
        file = file.path(raiz, "provs", paste0("CP_", cp, ".gpkg")),
        algo = "sha256"
      )
    },
    character(1)
  )
  readr::write_csv(estado, file.path(raiz, "estado.csv"))
  writeLines(as.character(Sys.time()), file.path(raiz, "WMS_REAPLICADA.txt"))
  message("CORRECCIONES REAPLICADAS: ", length(transferencias))
})
