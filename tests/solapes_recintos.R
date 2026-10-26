library(testthat)
library(sf)
eval(parse("scripts/cp_prov.R")[[1]])

test_that("los solapes pertenecen al menor recinto con prioridad estable", {
  caja <- function(x, y, ancho, alto) {
    st_polygon(list(rbind(
      c(x, y),
      c(x + ancho, y),
      c(x + ancho, y + alto),
      c(x, y + alto),
      c(x, y)
    )))
  }
  recintos <- st_sf(
    LAU_CODE = c("grande", "pequeno", "tercero"),
    geometry = st_sfc(
      caja(0, 0, 10, 10),
      caja(8, 0, 4, 4),
      caja(9, 2, 5, 5),
      crs = 25830
    )
  )
  corregidos <- resolver_solapes_recintos(recintos)
  expect_equal(as.numeric(st_area(corregidos$recintos[2, ])), 16)
  expect_equal(
    sum(as.numeric(st_area(corregidos$recintos))),
    as.numeric(st_area(st_union(recintos)))
  )
  expect_equal(
    sum(as.numeric(st_area(st_sym_difference(
      st_union(corregidos$recintos),
      st_union(recintos)
    )))),
    0
  )
  invertidos <- resolver_solapes_recintos(recintos[3:1, ])$recintos[3:1, ]
  expect_equal(st_geometry(invertidos), st_geometry(corregidos$recintos))
  expect_gt(nrow(corregidos$auditoria), 0)
})

test_that("áreas iguales se resuelven por LAU_CODE", {
  recintos <- st_sf(
    LAU_CODE = c("B", "A"),
    geometry = st_sfc(
      st_polygon(list(rbind(c(0, 0), c(2, 0), c(2, 2), c(0, 2), c(0, 0)))),
      st_polygon(list(rbind(c(1, 0), c(3, 0), c(3, 2), c(1, 2), c(1, 0)))),
      crs = 25830
    )
  )
  resultado <- resolver_solapes_recintos(recintos)
  expect_equal(as.numeric(st_area(resultado$recintos)), c(2, 4))
  expect_equal(resultado$auditoria$receptor, "A")
})
