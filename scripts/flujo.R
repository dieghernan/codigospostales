preparar_actualizacion <- function() {
  raiz <- Sys.getenv(
    "CP_LOTE_DIR",
    file.path(
      "data/cartociudad",
      format(Sys.time(), "actualizacion_%Y%m%d_%H%M%S")
    )
  )
  if (dir.exists(raiz)) {
    stop("El directorio del lote ya existe.")
  }
  dir.create(raiz, recursive = TRUE)
  raiz <- normalizePath(raiz, winslash = "/")
  for (d in c("provs", "analisis", "consolidado", "respaldo", "scripts")) {
    dir.create(file.path(raiz, d))
  }
  archivos <- list.files(
    "data/provs",
    "^CP_[0-9]{2}[.]gpkg$",
    full.names = TRUE
  )
  stopifnot(length(archivos) == 52L)
  stopifnot(all(file.copy(archivos, file.path(raiz, "provs"))))
  stopifnot(all(file.copy(archivos, file.path(raiz, "respaldo"))))
  stopifnot(all(file.copy(
    list.files("data/full_analisis", full.names = TRUE),
    file.path(raiz, "analisis")
  )))
  stopifnot(all(file.copy(
    c("data/codigos_postales.gpkg", "data/avance.png"),
    file.path(raiz, "respaldo")
  )))
  stopifnot(file.copy(
    "data/full_analisis/base_admin_publicada.rds",
    file.path(raiz, "base_admin.rds")
  ))
  for (f in c(
    "correcciones.R",
    "flujo.R",
    "ggplot.R",
    "actualizar.R",
    "cp_prov.R",
    "recintos.R"
  )) {
    stopifnot(file.copy(file.path("scripts", f), file.path(raiz, "scripts", f)))
  }
  congelar_evidencia(raiz)
  jsonlite::write_json(
    list(
      tipo = "actualizacion_incremental",
      creado = as.character(Sys.time()),
      base_sha256 = digest::digest(
        file = file.path(raiz, "base_admin.rds"),
        algo = "sha256"
      ),
      metodos = lapply(
        list.files(file.path(raiz, "scripts"), full.names = TRUE),
        function(f) {
          list(
            archivo = basename(f),
            sha256 = digest::digest(file = f, algo = "sha256")
          )
        }
      ),
      consolidado_origen_sha256 = digest::digest(
        file = "data/codigos_postales.gpkg",
        algo = "sha256"
      )
    ),
    file.path(raiz, "origen.json"),
    pretty = TRUE,
    auto_unbox = TRUE
  )
  writeLines(raiz, "data/cartociudad/actualizacion_actual.txt")
  message("ACTUALIZACION PREPARADA: ", raiz)
  invisible(raiz)
}

leer_evidencia <- function(carpeta = "data/evidencia_correcciones") {
  catalogo <- jsonlite::read_json(file.path(carpeta, "catalogo.json"))
  resultado <- list()
  for (paquete in catalogo$paquetes) {
    archivo <- file.path(carpeta, paquete$archivo)
    if (
      !identical(
        digest::digest(file = archivo, algo = "sha256"),
        paquete$sha256
      )
    ) {
      stop("Ha cambiado la evidencia: ", paquete$id)
    }
    for (capa in unlist(paquete$capas)) {
      resultado[[length(resultado) + 1L]] <- sf::st_read(
        archivo,
        layer = capa,
        quiet = TRUE
      )
    }
  }
  resultado
}

congelar_evidencia <- function(raiz) {
  destino <- file.path(raiz, "evidencia")
  if (file.exists(file.path(destino, "catalogo.json"))) {
    return(invisible(destino))
  }
  dir.create(destino, showWarnings = FALSE)
  catalogo <- jsonlite::read_json("data/evidencia_correcciones/catalogo.json")
  leer_evidencia()
  for (p in catalogo$paquetes) {
    ruta <- file.path(destino, p$archivo)
    dir.create(dirname(ruta), recursive = TRUE, showWarnings = FALSE)
    stopifnot(file.copy(
      file.path("data/evidencia_correcciones", p$archivo),
      ruta
    ))
  }
  stopifnot(file.copy(
    "data/evidencia_correcciones/exclusiones_territoriales.gpkg",
    destino
  ))
  stopifnot(file.copy("data/evidencia_correcciones/catalogo.json", destino))
  invisible(destino)
}

corregir_lote <- function(raiz) {
  if (file.exists(file.path(raiz, "PUBLICADO.txt"))) {
    stop("El lote ya está publicado; prepara otro lote.")
  }
  congelar_evidencia(raiz)
  evidencia <- leer_evidencia(file.path(raiz, "evidencia"))
  operaciones <- list()
  limpieza <- list()
  for (cpro in sprintf("%02d", 1:52)) {
    archivo <- file.path(raiz, "provs", paste0("CP_", cpro, ".gpkg"))
    postal <- sf::st_read(archivo, layer = "codigos_postales", quiet = TRUE)
    pendiente <- sf::st_read(archivo, layer = "pendientes", quiet = TRUE)
    seleccion <- lapply(evidencia, function(x) {
      x <- x[x$cpro == cpro, ]
      x <- sf::st_transform(x, sf::st_crs(postal))
      x <- x[, c("cpro", "LAU_CODE", "COD_POSTAL")]
      names(x)[names(x) == attr(x, "sf_column")] <- "geometry"
      sf::st_geometry(x) <- "geometry"
      x
    }) |>
      dplyr::bind_rows()
    if (nrow(seleccion)) {
      seleccion <- seleccion |>
        dplyr::group_by(cpro, LAU_CODE, COD_POSTAL) |>
        dplyr::summarise(.groups = "drop")
    }
    resultado <- aplicar_asignaciones(postal, pendiente, seleccion)
    operaciones[[cpro]] <- resultado$operaciones
    limpieza[[cpro]] <- data.frame(
      cpro = cpro,
      ranuras_eliminadas = resultado$ranuras_eliminadas
    )
    if (
      sum(resultado$operaciones$transferido_km2) > 0 ||
        resultado$ranuras_eliminadas > 0 ||
        !inherits(sf::st_geometry(postal), "sfc_MULTIPOLYGON") ||
        !inherits(sf::st_geometry(pendiente), "sfc_MULTIPOLYGON") ||
        any(vapply(
          sf::st_layers(archivo)$geomtype,
          function(tipo) !identical(tipo, "Multi Polygon"),
          logical(1)
        ))
    ) {
      temporal <- tempfile(tmpdir = raiz, fileext = ".gpkg")
      sf::st_write(
        resultado$postal,
        temporal,
        layer = "codigos_postales",
        quiet = TRUE
      )
      sf::st_write(
        resultado$pendientes,
        temporal,
        layer = "pendientes",
        quiet = TRUE
      )
      stopifnot(file.copy(temporal, archivo, overwrite = TRUE))
      unlink(temporal)
    }
    message(
      "EVIDENCIA ",
      cpro,
      ": ",
      sum(resultado$operaciones$transferido_km2),
      " km² incorporados."
    )
  }
  readr::write_csv(
    dplyr::bind_rows(operaciones),
    file.path(raiz, "analisis/reaplicacion_evidencia.csv")
  )
  readr::write_csv(
    dplyr::bind_rows(limpieza),
    file.path(raiz, "analisis/limpieza_ranuras.csv")
  )
  archivos <- list.files(
    file.path(raiz, "provs"),
    "^CP_[0-9]{2}[.]gpkg$",
    full.names = TRUE
  )
  readr::write_csv(
    data.frame(
      archivo = basename(archivos),
      sha256 = vapply(
        archivos,
        function(f) digest::digest(file = f, algo = "sha256"),
        character(1)
      )
    ),
    file.path(raiz, "analisis/estado_resultados.csv")
  )
  estado_path <- file.path(raiz, "estado.csv")
  if (file.exists(estado_path)) {
    estado <- readr::read_csv(
      estado_path,
      col_types = readr::cols(cpro = readr::col_character()),
      show_col_types = FALSE
    )
    if (!"salida_bruta_sha256" %in% names(estado)) {
      estado$salida_bruta_sha256 <- estado$salida_sha256
    }
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
    readr::write_csv(estado, estado_path)
    readr::write_csv(estado, file.path(raiz, "analisis/reejecucion_estado.csv"))
  }
  writeLines(
    digest::digest(
      file = file.path(raiz, "evidencia/catalogo.json"),
      algo = "sha256"
    ),
    file.path(raiz, "EVIDENCIA_APLICADA.txt")
  )
  invisible(raiz)
}

resumir_lote <- function(raiz) {
  base <- readRDS(file.path(raiz, "base_admin.rds"))
  analisis <- file.path(raiz, "analisis")
  for (cpro in sprintf("%02d", 1:52)) {
    f <- file.path(raiz, "provs", paste0("CP_", cpro, ".gpkg"))
    cp <- sf::st_read(f, layer = "codigos_postales", quiet = TRUE)
    p <- sf::st_read(f, layer = "pendientes", quiet = TRUE)
    readr::write_csv(
      sf::st_drop_geometry(p),
      file.path(analisis, paste0("pendientes_", cpro, ".csv"))
    )
    vfile <- file.path(analisis, paste0("validacion_", cpro, ".csv"))
    v <- readr::read_csv(
      vfile,
      col_types = readr::cols(cpro = readr::col_character()),
      show_col_types = FALSE
    )
    g <- c(sf::st_geometry(cp), sf::st_geometry(p))
    union <- sf::st_union(g)
    prov <- sf::st_transform(
      base$provincias[base$provincias$cpro == cpro, ],
      sf::st_crs(cp)
    )
    v$diferencia_m2 <- area_geometria(sf::st_sym_difference(
      union,
      sf::st_union(sf::st_geometry(prov))
    ))
    v$solape_m2 <- area_geometria(g) - area_geometria(union)
    stopifnot(v$diferencia_m2 < 1, abs(v$solape_m2) < 1)
    v$codigos <- nrow(cp)
    v$recintos_pendientes <- nrow(p)
    v$pendientes_m2 <- area_geometria(p)
    afile <- file.path(analisis, paste0("codigos_ausentes_", cpro, ".csv"))
    ausentes <- readr::read_csv(
      afile,
      col_types = readr::cols(COD_POSTAL = readr::col_character()),
      show_col_types = FALSE
    )
    ausentes <- ausentes[!ausentes$COD_POSTAL %in% cp$COD_POSTAL, ]
    readr::write_csv(ausentes, afile)
    v$ausentes <- paste(ausentes$COD_POSTAL, collapse = ";")
    v$perdidos_dentro_provincia <- sum(ausentes$dentro_provincia > 0)
    stopifnot(v$perdidos_dentro_provincia == 0)
    readr::write_csv(v, vfile)
  }
  Sys.setenv(
    CP_OUTPUT_DIR = file.path(raiz, "provs"),
    CP_CONSOLIDADO_DIR = file.path(raiz, "consolidado"),
    CP_ANALISIS_DIR = analisis,
    CP_BASE_ADMIN_RDS = file.path(raiz, "base_admin.rds")
  )
  mapa <- file.path(raiz, "scripts/ggplot.R")
  source(
    if (file.exists(mapa)) mapa else "scripts/ggplot.R",
    local = new.env(),
    encoding = "UTF-8"
  )
  archivo <- file.path(raiz, "consolidado/codigos_postales.gpkg")
  cp <- sf::st_read(archivo, layer = "codigos_postales", quiet = TRUE)
  p <- sf::st_read(archivo, layer = "pendientes", quiet = TRUE)
  contar <- function(g) {
    length(suppressWarnings(sf::st_cast(solo_poligonos(g), "POLYGON")))
  }
  p$poligonos <- vapply(
    sf::st_geometry(p),
    function(g) contar(sf::st_sfc(g, crs = sf::st_crs(p))),
    integer(1)
  )
  p$area_km2 <- as.numeric(sf::st_area(p)) / 1e6
  p$provincia <- base$provincias$ine.prov.name[match(
    p$cpro,
    base$provincias$cpro
  )]
  anterior_cp <- sf::st_read(
    file.path(raiz, "respaldo/codigos_postales.gpkg"),
    layer = "codigos_postales",
    quiet = TRUE
  )
  anterior_p <- sf::st_read(
    file.path(raiz, "respaldo/codigos_postales.gpkg"),
    layer = "pendientes",
    quiet = TRUE
  )
  readr::write_csv(
    data.frame(
      indicador = c(
        "codigos_postales",
        "registros_pendientes",
        "poligonos_pendientes",
        "area_pendiente_km2"
      ),
      antes = c(
        nrow(anterior_cp),
        nrow(anterior_p),
        contar(sf::st_geometry(anterior_p)),
        area_geometria(anterior_p) / 1e6
      ),
      despues = c(nrow(cp), nrow(p), sum(p$poligonos), sum(p$area_km2))
    ),
    file.path(analisis, "comparacion_antes_despues.csv")
  )
  readr::write_csv(
    sf::st_drop_geometry(p) |> dplyr::arrange(dplyr::desc(area_km2)),
    file.path(analisis, "pendientes_detalle.csv")
  )
  provincial <- lapply(sprintf("%02d", 1:52), function(cpro) {
    x <- p[p$cpro == cpro, ]
    data.frame(
      cpro = cpro,
      provincia = base$provincias$ine.prov.name[match(
        cpro,
        base$provincias$cpro
      )],
      registros = nrow(x),
      poligonos = sum(x$poligonos),
      area_km2 = sum(x$area_km2)
    )
  }) |>
    dplyr::bind_rows() |>
    dplyr::arrange(dplyr::desc(area_km2))
  readr::write_csv(
    provincial,
    file.path(analisis, "resumen_pendientes_provincia.csv")
  )
  fuentes <- lapply(sprintf("%02d", 1:52), function(cpro) {
    readr::read_csv(
      file.path(analisis, paste0("codigos_fuente_", cpro, ".csv")),
      col_types = readr::cols(COD_POSTAL = readr::col_character()),
      show_col_types = FALSE
    )$COD_POSTAL
  }) |>
    unlist() |>
    unique()
  stopifnot(all(fuentes %in% cp$COD_POSTAL))
  evidencia <- leer_evidencia(file.path(raiz, "evidencia"))
  esperados <- unique(c(
    fuentes,
    unlist(lapply(evidencia, function(x) x$COD_POSTAL))
  ))
  stopifnot(setequal(esperados, cp$COD_POSTAL))
  cierre <- list(
    fecha = as.character(Sys.Date()),
    provincias_y_ciudades_autonomas = 52L,
    codigos_fuente = length(fuentes),
    codigos_resultado = nrow(cp),
    codigos_adicionales_wms = sort(setdiff(cp$COD_POSTAL, fuentes)),
    codigos_ausentes = setdiff(fuentes, cp$COD_POSTAL),
    registros_pendientes = nrow(p),
    poligonos_pendientes = sum(p$poligonos),
    area_pendiente_km2 = sum(p$area_km2),
    consolidado_sha256 = digest::digest(file = archivo, algo = "sha256"),
    evidencia_sha256 = digest::digest(
      file = file.path(raiz, "evidencia/catalogo.json"),
      algo = "sha256"
    ),
    metodo = "Voronoi por componente; correcciones locales validadas; disolución por CP y limpieza de ranuras numéricas"
  )
  jsonlite::write_json(
    cierre,
    file.path(analisis, "cierre_generacion.json"),
    pretty = TRUE,
    auto_unbox = TRUE,
    digits = NA
  )
  invisible(cierre)
}

validar_lote <- function(raiz, publicado = FALSE) {
  Sys.setenv(
    CP_TEST_DIR = if (publicado) "data/provs" else file.path(raiz, "provs"),
    CP_TEST_ANALISIS = if (publicado) {
      "data/full_analisis"
    } else {
      file.path(raiz, "analisis")
    },
    CP_TEST_BASE = if (publicado) {
      "data/full_analisis/base_admin_publicada.rds"
    } else {
      file.path(raiz, "base_admin.rds")
    },
    CP_TEST_CONSOLIDADO = if (publicado) {
      "data/codigos_postales.gpkg"
    } else {
      file.path(raiz, "consolidado/codigos_postales.gpkg")
    },
    CP_TEST_EVIDENCIA = file.path(raiz, "evidencia"),
    CP_TEST_SOLO_PROVINCIAS = "false"
  )
  registro <- file(
    file.path(
      raiz,
      if (publicado) {
        "validacion_publicacion.log"
      } else {
        "validacion_propuesta.log"
      }
    ),
    open = "wt",
    encoding = "UTF-8"
  )
  sink(registro)
  sink(registro, type = "message")
  on.exit(
    {
      sink(type = "message")
      sink()
      close(registro)
    },
    add = TRUE
  )
  source("tests/ejecutar.R", local = new.env(), encoding = "UTF-8")
  invisible(TRUE)
}

publicar_lote <- function(raiz) {
  if (file.exists(file.path(raiz, "PUBLICADO.txt"))) {
    stop("El lote ya está publicado; prepara otro lote.")
  }
  stopifnot(file.exists(file.path(raiz, "EVIDENCIA_APLICADA.txt")))
  stopifnot(identical(
    trimws(readLines(file.path(raiz, "EVIDENCIA_APLICADA.txt"))),
    digest::digest(
      file = file.path(raiz, "evidencia/catalogo.json"),
      algo = "sha256"
    )
  ))
  estado_path <- file.path(raiz, "analisis/estado_resultados.csv")
  if (file.exists(estado_path)) {
    estado <- readr::read_csv(estado_path, show_col_types = FALSE)
    for (i in seq_len(nrow(estado))) {
      stopifnot(identical(
        estado$sha256[i],
        digest::digest(
          file = file.path(raiz, "provs", estado$archivo[i]),
          algo = "sha256"
        )
      ))
    }
  }
  for (cpro in sprintf("%02d", 1:52)) {
    nombre <- paste0("CP_", cpro, ".gpkg")
    copia <- file.path(raiz, "respaldo", nombre)
    if (!file.exists(copia)) {
      copia <- file.path(raiz, "respaldo/provs", nombre)
    }
    stopifnot(identical(
      digest::digest(file = copia, algo = "sha256"),
      digest::digest(file = file.path("data/provs", nombre), algo = "sha256")
    ))
  }
  for (nombre in c("codigos_postales.gpkg", "avance.png")) {
    stopifnot(identical(
      digest::digest(
        file = file.path(raiz, "respaldo", nombre),
        algo = "sha256"
      ),
      digest::digest(file = file.path("data", nombre), algo = "sha256")
    ))
  }
  cierre <- resumir_lote(raiz)
  validar_lote(raiz)
  for (cpro in sprintf("%02d", 1:52)) {
    stopifnot(file.copy(
      file.path(raiz, "provs", paste0("CP_", cpro, ".gpkg")),
      "data/provs",
      overwrite = TRUE
    ))
  }
  archivos <- list.files(
    file.path(raiz, "analisis"),
    "[.](csv|json)$",
    full.names = TRUE
  )
  stopifnot(all(file.copy(archivos, "data/full_analisis", overwrite = TRUE)))
  stopifnot(all(file.copy(
    file.path(raiz, "consolidado", c("codigos_postales.gpkg", "avance.png")),
    "data",
    overwrite = TRUE
  )))
  stopifnot(file.copy(
    file.path(raiz, "base_admin.rds"),
    "data/full_analisis/base_admin_publicada.rds",
    overwrite = TRUE
  ))
  for (cpro in sprintf("%02d", 1:52)) {
    stopifnot(identical(
      digest::digest(
        file = file.path(raiz, "provs", paste0("CP_", cpro, ".gpkg")),
        algo = "sha256"
      ),
      digest::digest(
        file = file.path("data/provs", paste0("CP_", cpro, ".gpkg")),
        algo = "sha256"
      )
    ))
  }
  for (nombre in c("codigos_postales.gpkg", "avance.png")) {
    stopifnot(identical(
      digest::digest(
        file = file.path(raiz, "consolidado", nombre),
        algo = "sha256"
      ),
      digest::digest(file = file.path("data", nombre), algo = "sha256")
    ))
  }
  validar_lote(raiz, publicado = TRUE)
  archivos <- c(
    list.files("data/provs", "^CP_[0-9]{2}[.]gpkg$", full.names = TRUE),
    "data/codigos_postales.gpkg",
    "data/avance.png",
    "data/full_analisis/base_admin_publicada.rds"
  )
  manifiesto <- data.frame(
    ruta = archivos,
    bytes = file.info(archivos)$size,
    sha256 = vapply(
      archivos,
      function(f) digest::digest(file = f, algo = "sha256"),
      character(1)
    )
  )
  readr::write_csv(
    manifiesto,
    "data/full_analisis/manifest_publicacion_actual.csv"
  )
  cierre$estado <- "publicada_y_verificada"
  cierre$directorio_local <- raiz
  cierre$catalogo <- "data/evidencia_correcciones/catalogo.json"
  jsonlite::write_json(
    cierre,
    "data/full_analisis/publicacion_actual.json",
    pretty = TRUE,
    auto_unbox = TRUE,
    digits = NA
  )
  writeLines(as.character(Sys.time()), file.path(raiz, "PUBLICADO.txt"))
  message(
    "PUBLICADO Y VERIFICADO: ",
    cierre$codigos_resultado,
    " CP; ",
    cierre$area_pendiente_km2,
    " km² pendientes."
  )
  invisible(cierre)
}
