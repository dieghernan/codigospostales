# Ejecutar desde la raíz: Rscript tests/ejecutar.R
if (.Platform$OS.type == "windows") {
  stopifnot(nzchar(Sys.setlocale("LC_CTYPE", "Spanish_Spain.utf8")))
}
for (archivo in c(
  "provincias.R",
  "solapes_recintos.R",
  "correcciones_pendientes.R",
  "regeneracion.R"
)) {
  source(file.path("tests", archivo), local = new.env(), encoding = "UTF-8")
}
