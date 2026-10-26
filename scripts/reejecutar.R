# Ejecutar: Rscript scripts/reejecutar.R piloto | resto | publicar
if (.Platform$OS.type == "windows") {
  if (!nzchar(Sys.setlocale("LC_CTYPE", "Spanish_Spain.utf8"))) {
    stop("No se ha podido activar el locale UTF-8.")
  }
}
suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
})
local({
  fase <- commandArgs(trailingOnly = TRUE)
  fase <- if (length(fase)) fase[1] else "piloto"
  if (!fase %in% c("piloto", "resto", "publicar")) {
    stop("Fase desconocida.")
  }
  raiz <- normalizePath(
    trimws(readLines("data/cartociudad/reejecucion_actual.txt", warn = FALSE)[
      1
    ]),
    winslash = "/"
  )
  for (carpeta in c("scripts", "provs", "analisis", "logs", "consolidado")) {
    dir.create(file.path(raiz, carpeta), showWarnings = FALSE)
  }
  bloqueo <- file.path(raiz, "ejecucion.lock")
  if (!dir.create(bloqueo, showWarnings = FALSE)) {
    stop("Hay otra ejecución o un bloqueo pendiente de revisión.")
  }
  on.exit(unlink(bloqueo, recursive = TRUE), add = TRUE)
  manifiesto_path <- file.path(raiz, "manifiesto.csv")
  if (!file.exists(manifiesto_path)) {
    equivalencias <- c(
      A_CORUNA = "15",
      ALAVA = "01",
      ALBACETE = "02",
      ALICANTE = "03",
      ALMERIA = "04",
      ASTURIAS = "33",
      AVILA = "05",
      BADAJOZ = "06",
      BALEARES = "07",
      BARCELONA = "08",
      BURGOS = "09",
      CACERES = "10",
      CADIZ = "11",
      CANTABRIA = "39",
      CASTELLON = "12",
      CEUTA = "51",
      CIUDAD_REAL = "13",
      CORDOBA = "14",
      CUENCA = "16",
      GIRONA = "17",
      GRANADA = "18",
      GUADALAJARA = "19",
      GUIPUZCOA = "20",
      HUELVA = "21",
      HUESCA = "22",
      JAEN = "23",
      LA_RIOJA = "26",
      LAS_PALMAS = "35",
      LEON = "24",
      LLEIDA = "25",
      LUGO = "27",
      MADRID = "28",
      MALAGA = "29",
      MELILLA = "52",
      MURCIA = "30",
      NAVARRA = "31",
      OURENSE = "32",
      PALENCIA = "34",
      PONTEVEDRA = "36",
      SALAMANCA = "37",
      SEGOVIA = "40",
      SEVILLA = "41",
      SORIA = "42",
      TARRAGONA = "43",
      TENERIFE = "38",
      TERUEL = "44",
      TOLEDO = "45",
      VALENCIA = "46",
      VALLADOLID = "47",
      VIZCAYA = "48",
      ZAMORA = "49",
      ZARAGOZA = "50"
    )
    archivos <- list.files(
      "data/cartociudad",
      pattern = "[.]zip$",
      full.names = TRUE,
      ignore.case = TRUE
    )
    nombres <- sub("^CARTOCIUDAD_CALLEJERO_|[.]zip$", "", basename(archivos))
    nombres <- sub("[.]zip$", "", nombres, ignore.case = TRUE)
    if (any(!nombres %in% names(equivalencias))) {
      stop("Hay ZIP sin correspondencia provincial explícita.")
    }
    manifiesto <- data.frame(
      cpro = unname(equivalencias[nombres]),
      provincia = nombres,
      archivo_zip = normalizePath(archivos, winslash = "/"),
      bytes = file.info(archivos)$size,
      fuente_mtime = as.character(file.info(archivos)$mtime),
      sha256 = vapply(
        archivos,
        function(f) digest::digest(file = f, algo = "sha256"),
        character(1)
      )
    )
    if (anyDuplicated(manifiesto$cpro)) {
      stop("Hay varias fuentes para la misma provincia.")
    }
    manifiesto$epsg <- ifelse(
      manifiesto$cpro %in% c("35", "38"),
      4083L,
      ifelse(
        manifiesto$cpro %in% c("07", "08", "17", "25", "43"),
        25831L,
        ifelse(
          manifiesto$cpro %in%
            c("06", "10", "15", "21", "27", "32", "36", "37"),
          25829L,
          25830L
        )
      )
    )
    manifiesto <- manifiesto[order(manifiesto$cpro), ]
    municipios <- mapSpain::esp_get_munic_siane(moveCAN = FALSE)
    provincias <- mapSpain::esp_get_prov_siane(moveCAN = FALSE) |>
      st_make_valid()
    condominios <- municipios |>
      filter(is.na(name)) |>
      st_transform(25830) |>
      st_make_valid()
    asignacion <- st_intersects(
      st_point_on_surface(st_geometry(condominios)),
      st_transform(provincias, 25830)
    )
    if (any(lengths(asignacion) != 1L)) {
      stop("Hay condominios sin provincia única para su punto interior.")
    }
    asignacion <- data.frame(
      LAU_CODE = condominios$LAU_CODE,
      cpro = provincias$cpro[unlist(asignacion)]
    )
    readr::write_csv(
      asignacion,
      file.path(raiz, "analisis/asignacion_condominios.csv")
    )
    saveRDS(
      list(municipios = municipios, provincias = provincias),
      file.path(raiz, "base_admin.rds")
    )
    manifiesto$municipios <- vapply(
      manifiesto$cpro,
      function(cp) sum(municipios$cpro == cp),
      integer(1)
    )
    manifiesto$condominios <- vapply(
      manifiesto$cpro,
      function(cp) sum(asignacion$cpro == cp),
      integer(1)
    )
    for (f in c("cp_prov.R", "ggplot.R", "reejecutar.R")) {
      file.copy(
        file.path("scripts", f),
        file.path(raiz, "scripts", f),
        overwrite = FALSE
      )
    }
    manifiesto$metodo_sha256 <- digest::digest(
      file = file.path(raiz, "scripts/cp_prov.R"),
      algo = "sha256"
    )
    manifiesto$admin_sha256 <- digest::digest(
      file = file.path(raiz, "base_admin.rds"),
      algo = "sha256"
    )
    readr::write_csv(manifiesto, manifiesto_path)
    readr::write_csv(manifiesto, "data/full_analisis/reejecucion_manifest.csv")
    capture.output(sessionInfo(), file = file.path(raiz, "sessionInfo.txt"))
  }
  manifiesto <- readr::read_csv(
    manifiesto_path,
    col_types = readr::cols(cpro = readr::col_character()),
    show_col_types = FALSE
  )
  if (
    !identical(
      unique(manifiesto$metodo_sha256),
      digest::digest(
        file = file.path(raiz, "scripts/cp_prov.R"),
        algo = "sha256"
      )
    )
  ) {
    stop("Ha cambiado la copia congelada del método.")
  }
  Sys.setenv(
    CP_OUTPUT_DIR = file.path(raiz, "provs"),
    CP_ANALISIS_DIR = file.path(raiz, "analisis"),
    CP_BASE_ADMIN_RDS = file.path(raiz, "base_admin.rds"),
    CP_CONSOLIDAR = "false",
    CP_CONSOLIDADO_DIR = file.path(raiz, "consolidado")
  )
  estado_path <- file.path(raiz, "estado.csv")
  estados <- if (file.exists(estado_path)) {
    readr::read_csv(
      estado_path,
      col_types = readr::cols(cpro = readr::col_character()),
      show_col_types = FALSE
    )
  } else {
    data.frame(
      cpro = character(),
      provincia = character(),
      estado = character(),
      segundos = double(),
      detalle = character(),
      salida_sha256 = character()
    )
  }
  piloto <- c("51", "09", "31", "28", "38")
  comparaciones <- function(codigos) {
    filas <- lapply(codigos, function(cp) {
      nuevo <- st_read(
        file.path(raiz, "provs", paste0("CP_", cp, ".gpkg")),
        layer = "codigos_postales",
        quiet = TRUE
      )
      anterior_path <- file.path(
        raiz,
        "respaldo/provs",
        paste0("CP_", cp, ".gpkg")
      )
      anterior <- if (file.exists(anterior_path)) {
        st_read(anterior_path, quiet = TRUE)
      } else {
        NULL
      }
      data.frame(
        cpro = cp,
        cp_anteriores = if (is.null(anterior)) {
          NA_integer_
        } else {
          n_distinct(anterior$COD_POSTAL, na.rm = TRUE)
        },
        cp_nuevos = nrow(nuevo),
        cp_incorporados = if (is.null(anterior)) {
          paste(nuevo$COD_POSTAL, collapse = ";")
        } else {
          paste(setdiff(nuevo$COD_POSTAL, anterior$COD_POSTAL), collapse = ";")
        },
        cp_no_representados = if (is.null(anterior)) {
          ""
        } else {
          paste(
            setdiff(na.omit(anterior$COD_POSTAL), nuevo$COD_POSTAL),
            collapse = ";"
          )
        }
      )
    })
    readr::write_csv(
      bind_rows(filas),
      file.path(raiz, "analisis", paste0("comparacion_", fase, ".csv"))
    )
  }
  ejecutar <- function(fila) {
    cp <- fila$cpro
    archivo <- file.path(raiz, "provs", paste0("CP_", cp, ".gpkg"))
    if (
      cp %in% estados$cpro[estados$estado == "validado"] && file.exists(archivo)
    ) {
      esperado <- estados$salida_sha256[match(cp, estados$cpro)]
      if (
        identical(esperado, digest::digest(file = archivo, algo = "sha256"))
      ) {
        return(NULL)
      }
    }
    if (
      !identical(
        fila$sha256,
        digest::digest(file = fila$archivo_zip, algo = "sha256")
      )
    ) {
      stop("Ha cambiado el ZIP: ", fila$provincia)
    }
    message("INICIO ", cp, " ", fila$provincia)
    inicio <- Sys.time()
    resultado <- local({
      con <- file(
        file.path(raiz, "logs", paste0(cp, ".log")),
        open = "wt",
        encoding = "UTF-8"
      )
      sink(con)
      sink(con, type = "message")
      on.exit(
        {
          sink(type = "message")
          sink()
          close(con)
        },
        add = TRUE
      )
      tryCatch(
        {
          Sys.setenv(
            CP_CPRO = cp,
            CP_PROVINCIA = fila$provincia,
            CP_ARCHIVO_ZIP = fila$archivo_zip
          )
          source(
            file.path(raiz, "scripts/cp_prov.R"),
            local = TRUE,
            encoding = "UTF-8"
          )
          ""
        },
        error = function(e) conditionMessage(e)
      )
    })
    fila_estado <- data.frame(
      cpro = cp,
      provincia = fila$provincia,
      estado = if (nzchar(resultado)) "error" else "validado",
      segundos = as.numeric(difftime(Sys.time(), inicio, units = "secs")),
      detalle = resultado,
      salida_sha256 = if (!nzchar(resultado)) {
        digest::digest(file = archivo, algo = "sha256")
      } else {
        ""
      }
    )
    estados <<- bind_rows(estados[estados$cpro != cp, ], fila_estado)
    readr::write_csv(estados, estado_path)
    readr::write_csv(estados, "data/full_analisis/reejecucion_estado.csv")
    message("FIN ", cp, " ", fila_estado$estado, " ", resultado)
    invisible(fila_estado)
  }
  if (fase %in% c("piloto", "resto")) {
    if (
      fase == "resto" &&
        !all(piloto %in% estados$cpro[estados$estado == "validado"])
    ) {
      stop("El piloto no está completamente validado.")
    }
    seleccion <- if (fase == "piloto") {
      manifiesto[match(piloto, manifiesto$cpro), ]
    } else {
      manifiesto
    }
    if (fase == "resto") {
      seleccion <- seleccion[order(seleccion$municipios), ]
    }
    for (i in seq_len(nrow(seleccion))) {
      ejecutar(seleccion[i, ])
    }
    comparaciones(seleccion$cpro[
      seleccion$cpro %in% estados$cpro[estados$estado == "validado"]
    ])
    if (any(estados$estado == "error")) {
      stop("Hay provincias con errores; consultar estado.csv y logs.")
    }
  } else {
    if (!all(manifiesto$cpro %in% estados$cpro[estados$estado == "validado"])) {
      stop("Faltan provincias validadas.")
    }
    for (i in seq_len(nrow(manifiesto))) {
      cp <- manifiesto$cpro[i]
      f <- file.path(raiz, "provs", paste0("CP_", cp, ".gpkg"))
      if (
        !identical(
          estados$salida_sha256[match(cp, estados$cpro)],
          digest::digest(file = f, algo = "sha256")
        )
      ) {
        stop("Ha cambiado un resultado validado: ", cp)
      }
    }
    source(
      file.path(raiz, "scripts/ggplot.R"),
      local = TRUE,
      encoding = "UTF-8"
    )
    pruebas <- file.path(raiz, "scripts/regeneracion-tests.R")
    if (!file.exists(pruebas)) {
      file.copy("tests/regeneracion.R", pruebas, overwrite = FALSE)
    }
    Sys.setenv(
      CP_TEST_DIR = file.path(raiz, "provs"),
      CP_TEST_BASE = file.path(raiz, "base_admin.rds"),
      CP_TEST_ANALISIS = file.path(raiz, "analisis"),
      CP_TEST_CONSOLIDADO = file.path(raiz, "consolidado/codigos_postales.gpkg")
    )
    source("tests/solapes_recintos.R", local = new.env(), encoding = "UTF-8")
    source(pruebas, local = new.env(), encoding = "UTF-8")
    archivos <- list.files(file.path(raiz, "provs"), full.names = TRUE)
    for (f in archivos) {
      if (
        !file.copy(f, file.path("data/provs", basename(f)), overwrite = TRUE)
      ) {
        stop("No se pudo publicar ", f)
      }
    }
    for (f in list.files(file.path(raiz, "analisis"), full.names = TRUE)) {
      if (
        !file.copy(
          f,
          file.path("data/full_analisis", basename(f)),
          overwrite = TRUE
        )
      ) {
        stop("No se pudo publicar ", f)
      }
    }
    for (f in c("codigos_postales.gpkg", "avance.png")) {
      if (
        !file.copy(
          file.path(raiz, "consolidado", f),
          file.path("data", f),
          overwrite = TRUE
        )
      ) {
        stop("No se pudo publicar ", f)
      }
    }
    writeLines(as.character(Sys.time()), file.path(raiz, "PUBLICADO.txt"))
    message("PUBLICADAS ", nrow(manifiesto), " PROVINCIAS")
  }
})
