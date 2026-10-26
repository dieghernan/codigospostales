library(testthat)
library(sf)
source("scripts/recintos.R", local = TRUE, encoding = "UTF-8")

test_that("el tipo original distingue condominios de municipios sin nombre", {
  recintos <- data.frame(
    t_ua = c("4", "99", NA, NA),
    name = c("Condominio", NA, NA, "Municipio")
  )
  expect_equal(es_condominio(recintos), c(TRUE, FALSE, TRUE, FALSE))
  antiguo <- data.frame(name = c(NA, "Municipio"))
  expect_equal(es_condominio(antiguo), c(TRUE, FALSE))
  expect_equal(
    normalizar_campos_recintos(antiguo)$id_prov,
    c(NA_character_, NA_character_)
  )
})

test_that("la provincia original se contrasta con un punto interior", {
  poligono <- st_polygon(list(rbind(
    c(0, 0),
    c(10, 0),
    c(10, 10),
    c(0, 10),
    c(0, 0)
  )))
  provincias <- st_sf(cpro = "09", geometry = st_sfc(poligono, crs = 25830))
  recintos <- st_sf(
    LAU_CODE = "53001",
    name = NA_character_,
    id_prov = 9,
    t_ua = 4,
    geometry = st_sfc(poligono, crs = 25830)
  )
  asignado <- asignar_provincias_condominios(recintos, provincias)
  expect_equal(asignado$cpro, "09")
  expect_equal(asignado$id_prov, "09")
  expect_equal(asignado$t_ua, "4")
  antiguo <- recintos[, c("LAU_CODE", "name")]
  expect_equal(asignar_provincias_condominios(antiguo, provincias)$cpro, "09")
  recintos$id_prov <- "19"
  expect_error(asignar_provincias_condominios(recintos, provincias), "53001")
  duplicadas <- rbind(provincias, provincias)
  expect_error(
    asignar_provincias_condominios(antiguo, duplicadas),
    "provincia única"
  )
  vacio <- recintos[FALSE, ]
  expect_equal(nrow(asignar_provincias_condominios(vacio, provincias)), 0L)
})
