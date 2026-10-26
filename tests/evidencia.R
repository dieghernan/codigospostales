library(testthat)
library(sf)
source("scripts/correcciones.R", encoding = "UTF-8")
source("scripts/flujo.R", encoding = "UTF-8")

test_that("el paquete nuevo conserva sus bytes y el respaldo WMS", {
  carpeta <- "data/evidencia_correcciones/componentes_20261026"
  for (f in jsonlite::read_json(file.path(carpeta, "manifest.json"))) {
    expect_equal(
      digest::digest(file = file.path(carpeta, f$archivo), algo = "sha256"),
      f$sha256
    )
  }
  respaldo <- st_read(
    file.path(carpeta, "respaldo.gpkg"),
    layer = "respaldo",
    quiet = TRUE
  )
  disputas <- st_read(
    file.path(carpeta, "respaldo.gpkg"),
    layer = "disputas",
    quiet = TRUE
  )
  archivo <- file.path(carpeta, "asignaciones.gpkg")
  for (capa in st_layers(archivo)$name) {
    a <- st_read(archivo, layer = capa, quiet = TRUE)
    for (i in seq_len(nrow(a))) {
      compatible <- respaldo[
        respaldo$cpro == a$cpro[i] &
          respaldo$LAU_CODE == a$LAU_CODE[i] &
          respaldo$COD_POSTAL == a$COD_POSTAL[i],
      ] |>
        st_transform(st_crs(a))
      expect_gt(nrow(compatible), 0L)
      expect_lt(
        area_geometria(st_difference(
          st_geometry(a[i, ]),
          st_union(st_geometry(compatible))
        )),
        1
      )
      conflicto <- disputas[
        disputas$cpro == a$cpro[i] &
          disputas$LAU_CODE == a$LAU_CODE[i] &
          disputas$COD_POSTAL == a$COD_POSTAL[i],
      ] |>
        st_transform(st_crs(a))
      if (nrow(conflicto)) {
        expect_lt(
          area_geometria(suppressWarnings(st_intersection(
            st_geometry(a[i, ]),
            st_union(st_geometry(conflicto))
          ))),
          1
        )
      }
    }
  }
})

test_that("la evidencia aprobada está asignada sin pendientes superpuestos", {
  carpeta <- Sys.getenv("CP_TEST_EVIDENCIA", "data/evidencia_correcciones")
  evidencia <- leer_evidencia(carpeta)
  entrada <- Sys.getenv("CP_TEST_DIR", "data/provs")
  for (cpro in sprintf("%02d", 1:52)) {
    postal <- st_read(
      file.path(entrada, paste0("CP_", cpro, ".gpkg")),
      layer = "codigos_postales",
      quiet = TRUE
    )
    pendientes <- st_read(
      file.path(entrada, paste0("CP_", cpro, ".gpkg")),
      layer = "pendientes",
      quiet = TRUE
    )
    for (lote in evidencia) {
      a <- lote[lote$cpro == cpro, ] |> st_transform(st_crs(postal))
      for (i in seq_len(nrow(a))) {
        destino <- postal[postal$COD_POSTAL == a$COD_POSTAL[i], ]
        expect_equal(nrow(destino), 1L)
        expect_lt(
          area_geometria(st_difference(
            st_geometry(a[i, ]),
            st_geometry(destino)
          )),
          1
        )
        expect_lt(
          area_geometria(suppressWarnings(st_intersection(
            st_geometry(a[i, ]),
            st_union(st_geometry(pendientes))
          ))),
          1
        )
      }
    }
  }
})

test_that("01194 conserva su exterior sin ranuras numéricas", {
  p <- st_read(
    file.path(Sys.getenv("CP_TEST_DIR", "data/provs"), "CP_01.gpkg"),
    query = "SELECT * FROM codigos_postales WHERE COD_POSTAL = '01194'",
    quiet = TRUE
  )
  expect_equal(limpiar_ranuras_numericas(p)$ranuras_eliminadas, 0L)
  expect_equal(nrow(p), 1L)
})
