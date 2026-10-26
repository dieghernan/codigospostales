# Reaplica toda la evidencia aprobada sobre un lote provisional.
if (.Platform$OS.type == "windows") {
  stopifnot(nzchar(Sys.setlocale("LC_CTYPE", "Spanish_Spain.utf8")))
}
local({
  raiz <- Sys.getenv("CP_REAPLICACION_DIR", "")
  if (!nzchar(raiz)) {
    stop("Indica CP_REAPLICACION_DIR con el lote provisional.")
  }
  raiz <- normalizePath(raiz, winslash = "/")
  source("scripts/correcciones.R", local = TRUE, encoding = "UTF-8")
  source("scripts/flujo.R", local = TRUE, encoding = "UTF-8")
  corregir_lote(raiz)
})
