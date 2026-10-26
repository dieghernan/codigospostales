library(testthat)
library(sf)
source("scripts/recintos.R", local = TRUE, encoding = "UTF-8")

test_that("una parte principal alargada no recibe el CP de un enclave cercano", {
  principal <- rbind(c(0, 0), c(1000, 0), c(1000, 10000), c(0, 10000), c(0, 0))
  enclave <- rbind(
    c(-2000, 0),
    c(-1000, 0),
    c(-1000, 1000),
    c(-2000, 1000),
    c(-2000, 0)
  )
  municipio <- st_sf(
    LAU_CODE = "01001",
    geometry = st_sfc(
      st_multipolygon(list(list(principal), list(enclave))),
      crs = 25830
    )
  )
  puntos <- st_as_sf(
    data.frame(
      COD_POSTAL = c("01240", "01193"),
      INE_MUN = "01001",
      x = c(500, -1500),
      y = c(9000, 500)
    ),
    coords = c("x", "y"),
    crs = 25830
  )
  componentes <- separar_componentes_recintos(municipio)
  resultado <- lapply(seq_len(nrow(componentes)), function(i) {
    parte <- componentes[i, ]
    propios <- st_intersects(parte, puntos)[[1]]
    generar_codigos_componente(parte, puntos[propios, ])
  }) |>
    dplyr::bind_rows()
  extremo <- st_sfc(st_point(c(500, 500)), crs = 25830)
  expect_equal(
    resultado$COD_POSTAL[unlist(st_intersects(extremo, resultado))],
    "01240"
  )
  expect_equal(
    as.numeric(st_area(resultado[resultado$COD_POSTAL == "01240", ])),
    1e7
  )
})

test_that("los componentes conservan huecos y no heredan códigos de otra parte", {
  caja <- function(x, y, ancho, alto) {
    rbind(
      c(x, y),
      c(x + ancho, y),
      c(x + ancho, y + alto),
      c(x, y + alto),
      c(x, y)
    )
  }
  geometria <- st_multipolygon(list(
    list(caja(0, 0, 1000, 1000), caja(400, 400, 100, 100)),
    list(caja(3000, 0, 1000, 1000)),
    list(caja(6000, 0, 1000, 1000))
  ))
  municipio <- st_sf(
    LAU_CODE = "01001",
    geometry = st_sfc(geometria, crs = 25830)
  )
  componentes <- separar_componentes_recintos(municipio)
  expect_equal(nrow(componentes), 3L)
  expect_equal(componentes$componente, 1:3)
  expect_equal(sum(as.numeric(st_area(componentes))), 2990000)
  puntos <- st_as_sf(
    data.frame(
      COD_POSTAL = c("01240", "01193"),
      INE_MUN = "01001",
      x = c(200, 3500),
      y = 500
    ),
    coords = c("x", "y"),
    crs = 25830
  )
  resultado <- lapply(seq_len(nrow(componentes)), function(i) {
    componente <- componentes[i, ]
    indices <- st_intersects(componente, puntos)[[1]]
    seleccion <- seleccionar_direcciones_componente(
      puntos,
      componente,
      indices,
      st_intersects(st_buffer(componente, -200), puntos)[[1]],
      st_intersects(st_buffer(componente, -50), puntos)[[1]]
    )
    generar_codigos_componente(componente, seleccion$puntos)
  }) |>
    dplyr::bind_rows()
  expect_equal(resultado$COD_POSTAL, c("01240", "01193", NA_character_))
  expect_equal(sum(as.numeric(st_area(resultado))), 2990000)
  expect_equal(st_is_valid(resultado), rep(TRUE, 3))
})

test_that("cada componente aplica su margen y su recuperación de direcciones", {
  componente <- st_sf(
    LAU_CODE = "01001",
    geometry = st_sfc(
      st_polygon(list(rbind(
        c(0, 0),
        c(200, 0),
        c(200, 1000),
        c(0, 1000),
        c(0, 0)
      ))),
      crs = 25830
    )
  )
  puntos <- st_as_sf(
    data.frame(
      COD_POSTAL = c("01240", "01193", "01194"),
      INE_MUN = c("otro", "01001", "otro"),
      x = c(100, 10, 10),
      y = c(500, 400, 300)
    ),
    coords = c("x", "y"),
    crs = 25830
  )
  seleccion <- seleccionar_direcciones_componente(
    puntos,
    componente,
    1:3,
    st_intersects(st_buffer(componente, -200), puntos)[[1]],
    st_intersects(st_buffer(componente, -50), puntos)[[1]]
  )
  expect_equal(seleccion$margen, 50L)
  expect_equal(seleccion$puntos$COD_POSTAL, c("01240", "01193"))
  expect_equal(seleccion$recuperados, 2L)
  recortadas <- generar_codigos_componente(componente, seleccion$puntos)
  expect_setequal(recortadas$COD_POSTAL, c("01240", "01193"))
  expect_equal(sum(as.numeric(st_area(recortadas))), 200000, tolerance = 1e-8)
  expect_equal(anyDuplicated(recortadas$COD_POSTAL), 0L)
})
