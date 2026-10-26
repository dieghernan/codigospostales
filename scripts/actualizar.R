# Ejecutar: Rscript scripts/actualizar.R preparar | corregir | publicar
if (.Platform$OS.type == "windows") {
  stopifnot(nzchar(Sys.setlocale("LC_CTYPE", "Spanish_Spain.utf8")))
}
local({
  fase <- commandArgs(trailingOnly = TRUE)
  fase <- if (length(fase)) fase[1] else "preparar"
  if (!fase %in% c("preparar", "corregir", "publicar")) {
    stop("Fase desconocida.")
  }
  if (fase == "preparar") {
    source("scripts/correcciones.R", local = TRUE, encoding = "UTF-8")
    source("scripts/flujo.R", local = TRUE, encoding = "UTF-8")
    preparar_actualizacion()
  } else {
    raiz <- normalizePath(
      trimws(readLines("data/cartociudad/actualizacion_actual.txt")),
      winslash = "/"
    )
    if (file.exists(file.path(raiz, "PUBLICADO.txt"))) {
      stop("El lote ya está publicado; prepara otro lote.")
    }
    origen <- jsonlite::read_json(file.path(raiz, "origen.json"))
    if (
      !is.null(origen$base_sha256) &&
        !identical(
          origen$base_sha256,
          digest::digest(
            file = file.path(raiz, "base_admin.rds"),
            algo = "sha256"
          )
        )
    ) {
      stop("Ha cambiado la base administrativa congelada.")
    }
    for (m in origen$metodos) {
      if (
        !identical(
          m$sha256,
          digest::digest(
            file = file.path(raiz, "scripts", m$archivo),
            algo = "sha256"
          )
        )
      ) {
        stop("Ha cambiado un archivo congelado: ", m$archivo)
      }
    }
    bloqueo <- file.path(raiz, "ejecucion.lock")
    if (!dir.create(bloqueo, showWarnings = FALSE)) {
      stop("Hay una ejecución o un bloqueo pendiente de revisión.")
    }
    on.exit(
      {
        if (
          identical(normalizePath(dirname(bloqueo), winslash = "/"), raiz) &&
            !length(list.files(bloqueo, all.files = TRUE, no.. = TRUE))
        ) {
          unlink(bloqueo, recursive = TRUE)
        }
      },
      add = TRUE
    )
    source(
      file.path(raiz, "scripts/correcciones.R"),
      local = TRUE,
      encoding = "UTF-8"
    )
    source(file.path(raiz, "scripts/flujo.R"), local = TRUE, encoding = "UTF-8")
    if (fase == "corregir") corregir_lote(raiz) else publicar_lote(raiz)
  }
})
