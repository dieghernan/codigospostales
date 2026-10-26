# Ejecutar desde la raíz: Rscript tests/regeneracion.R
library(testthat)
library(sf)

entrada <- Sys.getenv("CP_TEST_DIR", "data/provs")
base_path <- Sys.getenv(
  "CP_TEST_BASE",
  "data/full_analisis/base_admin_publicada.rds"
)
base <- if (nzchar(base_path)) {
  readRDS(base_path)
} else {
  list(
    municipios = mapSpain::esp_get_munic_siane(moveCAN = FALSE),
    provincias = mapSpain::esp_get_prov_siane(moveCAN = FALSE)
  )
}
archivos <- list.files(
  entrada,
  pattern = "^CP_[0-9]{2}[.]gpkg$",
  full.names = TRUE
)

test_that("el punto interior resuelve los recintos cóncavos", {
  poligono <- st_sfc(
    st_polygon(list(rbind(
      c(0, 0),
      c(4, 0),
      c(4, 4),
      c(3, 4),
      c(3, 1),
      c(1, 1),
      c(1, 4),
      c(0, 4),
      c(0, 0)
    ))),
    crs = 25830
  )
  expect_equal(lengths(st_within(st_centroid(poligono), poligono)), 0L)
  expect_equal(lengths(st_within(st_point_on_surface(poligono), poligono)), 1L)
})

test_that("cada condominio tiene una única provincia para su punto interior", {
  condominios <- base$municipios[is.na(base$municipios$name), ] |>
    st_transform(25830) |>
    st_make_valid()
  puntos <- st_point_on_surface(st_geometry(condominios))
  expect_equal(
    lengths(st_within(puntos, st_geometry(condominios))),
    rep(1L, nrow(condominios))
  )
  asignacion <- st_intersects(puntos, st_transform(base$provincias, 25830))
  expect_equal(lengths(asignacion), rep(1L, nrow(condominios)))
  expect_equal(anyDuplicated(condominios$LAU_CODE), 0L)
})

test_that("los resultados provinciales cubren la provincia sin solaparse", {
  expect_gt(length(archivos), 0L)
  for (archivo in archivos) {
    cp <- sub("^CP_([0-9]{2})[.]gpkg$", "\\1", basename(archivo))
    expect_setequal(
      st_layers(archivo)$name,
      c("codigos_postales", "pendientes")
    )
    resultado <- st_read(archivo, layer = "codigos_postales", quiet = TRUE)
    expect_gt(nrow(resultado), 0L)
    pendientes <- st_read(archivo, layer = "pendientes", quiet = TRUE)
    expect_equal(names(st_drop_geometry(resultado)), "COD_POSTAL")
    expect_equal(anyDuplicated(resultado$COD_POSTAL), 0L)
    expect_all_true(
      !is.na(resultado$COD_POSTAL) & grepl("^[0-9]{5}$", resultado$COD_POSTAL)
    )
    if (nrow(pendientes)) {
      expect_equal(unique(pendientes$cpro), cp)
      expect_equal(sum(is.na(pendientes$LAU_CODE)), 0L)
      expect_equal(anyDuplicated(pendientes$LAU_CODE), 0L)
    }
    geometria <- c(st_geometry(resultado), st_geometry(pendientes))
    expect_all_true(st_is_valid(geometria))
    expect_equal(sum(st_is_empty(geometria)), 0L)
    provincia <- base$provincias[base$provincias$cpro == cp, ] |>
      st_transform(st_crs(resultado)) |>
      st_make_valid()
    cobertura <- st_union(geometria)
    diferencia <- st_sym_difference(cobertura, st_union(provincia))
    expect_lt(sum(as.numeric(st_area(diferencia))), 1)
    solape <- sum(as.numeric(st_area(geometria))) -
      sum(as.numeric(st_area(cobertura)))
    expect_lt(abs(solape), 1)
    analisis <- Sys.getenv("CP_TEST_ANALISIS", "data/full_analisis")
    diagnostico_path <- file.path(analisis, paste0("diagnostico_", cp, ".csv"))
    if (file.exists(diagnostico_path)) {
      diagnostico <- readr::read_csv(
        diagnostico_path,
        col_types = readr::cols(.default = readr::col_character())
      )
      expect_equal(anyDuplicated(diagnostico$LAU_CODE), 0L)
      expect_equal(sum(is.na(diagnostico$LAU_CODE)), 0L)
      codigos_originales <- base$municipios$LAU_CODE[base$municipios$cpro == cp]
      expect_all_true(codigos_originales %in% diagnostico$LAU_CODE)
    }
  }
})

test_that("se conserva el CP 41760 sin filtrar por provincia", {
  archivo <- file.path(entrada, "CP_11.gpkg")
  if (!file.exists(archivo)) {
    skip("Cádiz no forma parte de esta fase.")
  }
  resultado <- st_read(archivo, layer = "codigos_postales", quiet = TRUE)
  portal <- st_sfc(
    st_point(c(273038.71999615082, 4088908.7499948079)),
    crs = 25830
  ) |>
    st_transform(st_crs(resultado))
  expect_equal(sum(resultado$COD_POSTAL == "41760"), 1L)
  expect_equal(
    lengths(st_intersects(
      portal,
      resultado[resultado$COD_POSTAL == "41760", ]
    )),
    1L
  )
})

test_that("el consolidado contiene un registro por CP y una capa de pendientes", {
  if (identical(Sys.getenv("CP_TEST_SOLO_PROVINCIAS"), "true")) {
    skip("El consolidado se comprueba al finalizar el lote.")
  }
  consolidado <- Sys.getenv("CP_TEST_CONSOLIDADO", "data/codigos_postales.gpkg")
  if (!nzchar(consolidado)) {
    skip("El consolidado se construye al finalizar el lote.")
  }
  expect_setequal(
    st_layers(consolidado)$name,
    c("codigos_postales", "pendientes")
  )
  resultado <- st_read(consolidado, layer = "codigos_postales", quiet = TRUE)
  codigos_entrada <- unique(unlist(lapply(archivos, function(f) {
    st_read(f, layer = "codigos_postales", quiet = TRUE)$COD_POSTAL
  })))
  expect_equal(names(st_drop_geometry(resultado)), "COD_POSTAL")
  expect_equal(anyDuplicated(resultado$COD_POSTAL), 0L)
  expect_setequal(resultado$COD_POSTAL, codigos_entrada)
  expect_all_true(st_is_valid(resultado))
})
