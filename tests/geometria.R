# Ejecutar desde la raíz con source("tests/geometria.R").
library(sf)
source("scripts/geometria.R")

local({
  cuadrado <- function(x, lado) {
    st_polygon(list(matrix(
      c(x, 0, x + lado, 0, x + lado, lado, x, lado, x, 0),
      ncol = 2,
      byrow = TRUE
    )))
  }
  recintos <- st_sf(
    id = 1:2,
    geometry = st_sfc(cuadrado(0, 10), cuadrado(5, 2), crs = 25830)
  )
  resultado <- resolver_solapes(recintos)
  stopifnot(
    identical(as.numeric(st_area(resultado)), c(96, 4)),
    as.numeric(st_area(st_union(resultado))) == 100,
    all(st_is_valid(resultado))
  )
  mezcla <- st_geometrycollection(list(
    cuadrado(0, 1),
    cuadrado(3, 1),
    st_linestring(matrix(c(0, 0, 1, 1), ncol = 2))
  ))
  superficies <- solo_poligonos(st_sf(
    id = 1,
    geometry = st_sfc(mezcla, crs = 25830)
  ))
  stopifnot(
    nrow(superficies) == 1L,
    as.character(st_geometry_type(superficies)) == "MULTIPOLYGON",
    as.numeric(st_area(superficies)) == 2,
    identical(
      normalizar_cp(c("1001", "01001", "", NA)),
      c("01001", "01001", NA_character_, NA_character_)
    )
  )
  vacio <- solo_poligonos(recintos[FALSE, ])
  stopifnot(nrow(vacio) == 0L, st_crs(vacio) == st_crs(recintos))
  linea <- st_sf(
    id = 1,
    geometry = st_sfc(
      st_linestring(matrix(c(0, 0, 1, 1), ncol = 2)),
      crs = 25830
    )
  )
  stopifnot(nrow(solo_poligonos(linea)) == 0L)

  casos <- st_sf(
    CodMuni = c("a", "a", "b", "b", "b", "c", NA),
    COD_POSTAL = c("01001", NA, "02001", "02002", NA, NA, NA),
    geometry = st_sfc(rep(list(cuadrado(0, 1)), 7), crs = 25830)
  )
  stopifnot(identical(
    recuperar_cp_municipal(casos)$COD_POSTAL,
    c("01001", "01001", "02001", "02002", NA, NA, NA)
  ))

  micro <- unclass(cuadrado(2, 0.0005))[[1]]
  enclave <- unclass(cuadrado(4, 1))[[1]]
  micro[, 2] <- micro[, 2] + 2
  enclave[, 2] <- enclave[, 2] + 2
  prueba <- st_sf(
    COD_POSTAL = c("00001", "00002"),
    geometry = st_sfc(
      st_multipolygon(list(list(
        unclass(cuadrado(0, 10))[[1]],
        micro,
        enclave
      ))),
      st_multipolygon(list(list(enclave))),
      crs = 25830
    )
  )
  limpio <- limpiar_anillos(prueba, prueba[FALSE, ])
  protegido <- limpiar_anillos(
    prueba,
    st_sf(
      geometry = st_sfc(
        st_multipolygon(list(list(micro))),
        crs = 25830
      )
    )
  )
  stopifnot(
    length(st_geometry(limpio)[[1]][[1]]) == 2L,
    length(st_geometry(protegido)[[1]][[1]]) == 3L,
    identical(st_geometry(limpio)[[2]], st_geometry(prueba)[[2]])
  )
})
