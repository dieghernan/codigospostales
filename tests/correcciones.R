library(testthat)
library(sf)
source("scripts/correcciones.R", encoding = "UTF-8")

test_that("una corrección parcial añade CP y conserva los residuos", {
  caja <- function(x1, x2) {
    st_polygon(list(rbind(c(x1, 0), c(x2, 0), c(x2, 10), c(x1, 10), c(x1, 0))))
  }
  postal <- st_sf(
    COD_POSTAL = "01194",
    geometry = st_sfc(caja(0, 5), crs = 25830)
  )
  pendiente <- st_sf(
    cpro = "01",
    LAU_CODE = "01001",
    geometry = st_sfc(caja(5, 10), crs = 25830)
  )
  asignacion <- st_sf(
    cpro = "01",
    LAU_CODE = "01001",
    COD_POSTAL = "04071",
    geometry = st_sfc(caja(5, 8), crs = 25830)
  )
  resultado <- aplicar_asignaciones(postal, pendiente, asignacion)
  expect_setequal(resultado$postal$COD_POSTAL, c("01194", "04071"))
  expect_equal(area_geometria(resultado$pendientes), 20)
  expect_equal(area_geometria(resultado$postal), 80)
  expect_equal(resultado$solape_m2, 0)
  repetido <- aplicar_asignaciones(
    resultado$postal,
    resultado$pendientes,
    asignacion
  )
  expect_equal(sum(repetido$operaciones$transferido_km2), 0)
  expect_equal(
    area_geometria(st_sym_difference(
      st_union(resultado$postal),
      st_union(repetido$postal)
    )),
    0
  )
  incompatible <- asignacion
  incompatible$COD_POSTAL <- "99999"
  expect_error(
    aplicar_asignaciones(resultado$postal, resultado$pendientes, incompatible),
    "Evidencia incompatible"
  )
})

test_that("la limpieza elimina ranuras numéricas y conserva huecos reales", {
  exterior <- rbind(c(0, 0), c(20, 0), c(20, 20), c(0, 20), c(0, 0))
  ranura <- rbind(c(1, 1), c(1, 1 + 1e-10), c(10, 1 + 1e-10), c(10, 1), c(1, 1))
  hueco <- rbind(c(2, 2), c(2, 4), c(4, 4), c(4, 2), c(2, 2))
  p <- st_sf(
    COD_POSTAL = "01194",
    geometry = st_sfc(st_polygon(list(exterior, ranura, hueco)), crs = 25830)
  )
  limpio <- limpiar_ranuras_numericas(p)
  expect_equal(limpio$ranuras_eliminadas, 1L)
  expect_length(st_geometry(limpio$postal)[[1]], 2L)
  expect_equal(st_geometry(limpio$postal)[[1]][[1]], exterior)
  expect_equal(st_geometry(limpio$postal)[[1]][[2]], hueco)
  expect_equal(limpiar_ranuras_numericas(limpio$postal)$ranuras_eliminadas, 0L)
})
