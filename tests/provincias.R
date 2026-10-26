library(testthat)

asignacion_script <- function(archivo, nombre) {
  buscar <- function(x) {
    if (
      is.call(x) &&
        identical(x[[1]], as.name("<-")) &&
        identical(x[[2]], as.name(nombre))
    ) {
      return(list(x[[3]]))
    }
    if (!is.call(x) && !is.expression(x)) {
      return(list())
    }
    unlist(lapply(as.list(x), buscar), recursive = FALSE)
  }
  resultados <- buscar(parse(archivo))
  stopifnot(length(resultados) == 1L)
  resultados[[1]]
}

test_that("el inventario reconoce las 52 fuentes sin duplicados", {
  inventario <- eval(asignacion_script("scripts/reejecutar.R", "equivalencias"))
  expect_setequal(unname(inventario), sprintf("%02d", 1:52))
  expect_equal(anyDuplicated(inventario), 0L)
  expect_equal(anyDuplicated(names(inventario)), 0L)
  fuentes <- readr::read_csv(
    "data/full_analisis/reejecucion_manifest.csv",
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE
  )
  zips <- basename(fuentes$archivo_zip)
  nombres <- sub("[.]zip$", "", sub("^CARTOCIUDAD_CALLEJERO_", "", zips))
  expect_length(zips, 52L)
  expect_setequal(nombres, names(inventario))
})

test_that("el manifiesto y el cálculo eligen el mismo EPSG", {
  codigos <- sprintf("%02d", 1:52)
  esperado <- rep(25830L, 52)
  esperado[c(6, 10, 15, 21, 27, 32, 36, 37)] <- 25829L
  esperado[c(7, 8, 17, 25, 43)] <- 25831L
  esperado[c(35, 38)] <- 4083L
  expresion <- asignacion_script("scripts/cp_prov.R", "epsg")
  actual <- vapply(codigos, function(cpro) eval(expresion), integer(1))
  expect_equal(unname(actual), esperado)
  manifiesto <- data.frame(cpro = codigos)
  texto <- parse("scripts/reejecutar.R")
  buscar <- function(x) {
    if (
      is.call(x) &&
        identical(x[[1]], as.name("<-")) &&
        identical(x[[2]], quote(manifiesto$epsg))
    ) {
      return(list(x[[3]]))
    }
    if (!is.call(x) && !is.expression(x)) {
      return(list())
    }
    unlist(lapply(as.list(x), buscar), recursive = FALSE)
  }
  expect_equal(eval(buscar(texto)[[1]]), esperado)
})
