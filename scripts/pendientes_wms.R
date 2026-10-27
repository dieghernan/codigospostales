# Revisión manual a requerimiento: no se ejecuta durante la generación provincial.
library(sf)
library(dplyr)
library(httr2)
library(jsonlite)
source("scripts/geometria.R")
if (.Platform$OS.type == "windows") {
  Sys.setlocale("LC_CTYPE", "Spanish_Spain.utf8")
}

consultar_cp_wms <- function(punto) {
  xy <- st_coordinates(punto)[1, ]
  bbox <- paste(
    format(
      c(xy - 0.505, xy + 0.505),
      scientific = FALSE,
      digits = 15,
      trim = TRUE
    ),
    collapse = ","
  )
  peticion <- request(
    "https://www.cartociudad.es/wms-inspire/direcciones-ccpp"
  ) |>
    req_url_query(
      SERVICE = "WMS",
      VERSION = "1.1.1",
      REQUEST = "GetFeatureInfo",
      LAYERS = "codigo-postal",
      QUERY_LAYERS = "codigo-postal",
      STYLES = "codigopostal",
      SRS = "EPSG:25830",
      INFO_FORMAT = "application/json",
      FORMAT = "image/png",
      FEATURE_COUNT = 100,
      WIDTH = 101,
      HEIGHT = 101,
      X = 50,
      Y = 50,
      BBOX = bbox
    ) |>
    req_timeout(30) |>
    req_retry(max_tries = 3)
  tryCatch(
    {
      cuerpo <- peticion |>
        req_perform() |>
        resp_body_string()
      datos <- fromJSON(cuerpo, simplifyVector = FALSE)
      if (!identical(datos$type, "FeatureCollection")) {
        stop("Respuesta WMS inesperada.")
      }
      cp <- character()
      if (length(datos$features)) {
        recintos <- st_read(cuerpo, quiet = TRUE)
        # Evita aceptar vecinos devueltos por la tolerancia del píxel del WMS.
        dentro <- lengths(st_intersects(recintos, punto)) > 0L
        cp <- unique(normalizar_cp(recintos$cod_postal[dentro]))
        cp <- cp[!is.na(cp)]
      }
      list(
        estado = if (length(cp)) "ok" else "sin_valor",
        cp = paste(sort(cp), collapse = ";"),
        error = ""
      )
    },
    error = function(e) {
      list(estado = "error", cp = "", error = conditionMessage(e))
    }
  )
}

pendientes <- st_read(
  "data/codigos_postales.gpkg",
  layer = "pendientes",
  quiet = TRUE
)
# No repite recintos ya consultados en revisiones anteriores.
clave_revision <- function(x) {
  paste(x$PROVINCIA, x$CodMuni, sprintf("%.3f", x$AREA_M2), sep = ":")
}
auditorias <- list.files(
  "data/full_analisis",
  pattern = "^pendientes[.]csv$",
  full.names = TRUE,
  recursive = TRUE
)
revisados <- lapply(auditorias, function(archivo) {
  x <- readr::read_csv(
    archivo,
    show_col_types = FALSE,
    col_types = readr::cols(
      .default = readr::col_character(),
      AREA_M2 = readr::col_double()
    )
  )
  # Si una provincia se regenera, los recintos antes asignados pueden volver
  # a consultarse; solo se omiten los resultados que quedaron sin asignar.
  x <- x[is.na(x$CP_ASIGNADO), ]
  clave_revision(x)
}) |>
  unlist(use.names = FALSE)
pendientes <- pendientes[!clave_revision(pendientes) %in% revisados, ]
if (!nrow(pendientes)) {
  stop("No quedan recintos pendientes sin revisar.")
}
seleccion <- pendientes[order(-pendientes$AREA_M2), ][
  seq_len(min(50L, nrow(pendientes))),
]
seleccion$ID_REVISION <- seq_len(nrow(seleccion))
carpeta_revision <- file.path(
  "data/full_analisis",
  paste0("wms_", format(Sys.time(), "%Y%m%d_%H%M%S"))
)
dir.create(carpeta_revision, showWarnings = FALSE, recursive = TRUE)
resumen <- list()
consultas <- list()
for (i in seq_len(nrow(seleccion))) {
  recinto <- seleccion[i, ]
  puntos <- st_make_grid(recinto, n = c(3, 3), what = "centers")
  puntos <- puntos[lengths(st_within(puntos, recinto)) > 0L]
  resultados <- lapply(seq_along(puntos), function(j) {
    Sys.sleep(0.15)
    respuesta <- consultar_cp_wms(puntos[j])
    xy <- st_coordinates(puntos[j])[1, ]
    data.frame(
      ID_REVISION = i,
      PUNTO = j,
      X = xy[1],
      Y = xy[2],
      ESTADO = respuesta$estado,
      CP = respuesta$cp,
      ERROR = respuesta$error,
      FECHA_UTC = format(Sys.time(), tz = "UTC", usetz = TRUE),
      row.names = NULL
    )
  })
  respuestas <- bind_rows(resultados)
  cp <- if (nrow(respuestas)) unique(respuestas$CP) else character()
  unico <- nrow(respuestas) > 0L &&
    all(respuestas$ESTADO == "ok") &&
    length(cp) == 1L &&
    grepl("^[0-9]{5}$", cp)
  resumen[[i]] <- data.frame(
    ID_REVISION = i,
    PROVINCIA = recinto$PROVINCIA,
    CodMuni = recinto$CodMuni,
    Municipio = recinto$Municipio,
    AREA_M2 = recinto$AREA_M2,
    PUNTOS = length(puntos),
    CP_ASIGNADO = if (unico) cp else NA_character_,
    VALORES = if (nrow(respuestas)) {
      paste(sort(unique(respuestas$CP)), collapse = ";")
    } else {
      ""
    },
    ESTADO = if (unico) {
      "asignable"
    } else if (!length(puntos)) {
      "sin_puntos"
    } else if (any(respuestas$ESTADO != "ok")) {
      "incompleto"
    } else {
      "varios_cp"
    }
  )
  consultas[[i]] <- respuestas
  readr::write_csv(
    bind_rows(resumen),
    file.path(carpeta_revision, "pendientes.csv"),
    na = ""
  )
  readr::write_csv(
    bind_rows(consultas),
    file.path(carpeta_revision, "puntos.csv"),
    na = ""
  )
  message(
    i,
    "/",
    nrow(seleccion),
    " ",
    recinto$Municipio,
    ": ",
    resumen[[i]]$ESTADO,
    " ",
    resumen[[i]]$CP_ASIGNADO
  )
}
resumen <- bind_rows(resumen)

# Actualiza los resultados provinciales para que la consolidación conserve
# las asignaciones sin añadir consultas WMS al flujo habitual.
asignados <- which(!is.na(resumen$CP_ASIGNADO))
for (prov in unique(resumen$PROVINCIA[asignados])) {
  archivo <- paste0("data/provs/CP_", prov, ".gpkg")
  capa <- paste0("CP_", prov)
  postal <- st_read(archivo, layer = capa, quiet = TRUE)
  sin_cp <- st_read(archivo, layer = "pendientes", quiet = TRUE)
  comparables <- solo_poligonos(sin_cp) |>
    st_transform(st_crs(seleccion)) |>
    solo_poligonos()
  indices <- asignados[resumen$PROVINCIA[asignados] == prov]
  coincidencias <- st_equals(seleccion[indices, ], comparables)
  stopifnot(all(lengths(coincidencias) == 1L))
  filas <- vapply(coincidencias, `[`, integer(1), 1)
  stopifnot(!anyDuplicated(filas), nrow(comparables) == nrow(sin_cp))
  nuevos <- sin_cp[filas, ]
  nuevos$COD_POSTAL <- resumen$CP_ASIGNADO[indices]
  sin_cp <- sin_cp[-filas, ]
  postal <- bind_rows(
    postal[!is.na(postal$COD_POSTAL), ] |> select(COD_POSTAL),
    nuevos |> select(COD_POSTAL),
    sin_cp |> select(COD_POSTAL)
  ) |>
    group_by(COD_POSTAL) |>
    summarise(.groups = "drop") |>
    solo_poligonos()
  stopifnot(all(st_is_valid(postal)), all(st_is_valid(sin_cp)))
  st_write(postal, archivo, layer = capa, append = FALSE, quiet = TRUE)
  st_write(sin_cp, archivo, layer = "pendientes", append = FALSE, quiet = TRUE)
}
if (length(asignados)) {
  source("scripts/consolidado.R")
}
message(
  "Asignados: ",
  length(asignados),
  "; superficie: ",
  round(sum(resumen$AREA_M2[asignados]) / 1e6, 3),
  " km²."
)
