library(testthat)
library(sf)

carpeta <- "data/evidencia_correcciones"
consolidado <- Sys.getenv("CP_TEST_CONSOLIDADO", "data/codigos_postales.gpkg")
analisis <- Sys.getenv("CP_TEST_ANALISIS", "data/full_analisis")
cierre <- jsonlite::read_json(file.path(analisis, "cierre_generacion.json"))
despues <- st_read(
  consolidado,
  layer = "codigos_postales",
  quiet = TRUE
)
asignaciones <- st_read(
  file.path(carpeta, "asignaciones_respaldadas.gpkg"),
  quiet = TRUE
)
exclusion <- st_read(
  file.path(carpeta, "exclusiones_territoriales.gpkg"),
  quiet = TRUE
)
pendientes_despues <- st_read(
  consolidado,
  layer = "pendientes",
  quiet = TRUE
)

test_that("la evidencia conserva las huellas de la publicación", {
  manifiesto <- jsonlite::read_json(file.path(carpeta, "manifest.json"))
  for (registro in manifiesto) {
    expect_equal(
      digest::digest(
        file = file.path(carpeta, registro$archivo),
        algo = "sha256"
      ),
      registro$sha256
    )
  }
  expect_equal(
    digest::digest(file = consolidado, algo = "sha256"),
    cierre$consolidado_sha256
  )
})

test_that("las ampliaciones seleccionadas están en los CP publicados", {
  seleccion <- readr::read_csv(
    file.path(carpeta, "seleccion_recintos.csv"),
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE
  )
  expect_setequal(asignaciones$LAU_CODE, seleccion$LAU_CODE)
  expect_equal(nrow(asignaciones), nrow(seleccion))
  expect_equal(anyDuplicated(asignaciones$LAU_CODE), 0L)
  expect_equal(sum(grepl(";", seleccion$cp_en_muestras, fixed = TRUE)), 0L)
  expect_equal(sum(!nzchar(seleccion$cp_ine_coincidente)), 0L)
  expect_equal(sum(is.na(seleccion$cp_ine_coincidente)), 0L)
  expect_equal(nrow(despues), 10851L)
  expect_equal(nrow(asignaciones), 34L)
  for (cp in unique(asignaciones$COD_POSTAL)) {
    nuevo <- st_geometry(despues[despues$COD_POSTAL == cp, ])
    ampliacion <- st_union(st_geometry(
      asignaciones[asignaciones$COD_POSTAL == cp, ]
    ))
    expect_length(nuevo, 1L)
    expect_lt(sum(as.numeric(st_area(st_difference(ampliacion, nuevo)))), 1)
  }
  for (i in seq_len(nrow(asignaciones))) {
    expect_gt(
      sum(as.numeric(st_area(pendientes_despues[
        pendientes_despues$LAU_CODE == asignaciones$LAU_CODE[i],
      ]))),
      0
    )
  }
})

test_that("las ampliaciones y Gibraltar quedan fuera de los pendientes", {
  expect_all_true(st_is_valid(pendientes_despues))
  expect_equal(nrow(pendientes_despues), cierre$registros_pendientes)
  expect_equal(
    sum(as.numeric(st_area(pendientes_despues))) / 1e6,
    cierre$area_pendiente_km2,
    tolerance = 1e-8
  )
  expect_lt(
    sum(as.numeric(st_area(st_intersection(
      st_geometry(pendientes_despues),
      st_union(c(st_geometry(exclusion), st_geometry(asignaciones)))
    )))),
    1
  )
  expect_lt(
    sum(as.numeric(st_area(st_intersection(
      st_geometry(despues),
      st_union(st_geometry(exclusion))
    )))),
    1
  )
})

test_that("cada ampliación tiene respaldo espacial sin disputa conocida", {
  archivos <- list.files(
    carpeta,
    "[.]geojson$",
    full.names = TRUE
  )
  capas <- lapply(archivos, function(f) {
    st_read(f, quiet = TRUE) |>
      st_transform(st_crs(asignaciones)) |>
      st_make_valid() |>
      dplyr::select(cod_postal, ine_mun)
  }) |>
    dplyr::bind_rows()
  for (i in seq_len(nrow(asignaciones))) {
    g <- st_geometry(asignaciones[i, ])
    compatibles <- capas[capas$cod_postal == asignaciones$COD_POSTAL[i], ]
    expect_gt(nrow(compatibles), 0L)
    expect_gt(sum(compatibles$ine_mun == asignaciones$LAU_CODE[i]), 0L)
    expect_lt(
      sum(as.numeric(st_area(st_difference(
        g,
        st_union(st_geometry(compatibles))
      )))),
      1
    )
    otras <- capas[
      capas$cod_postal != asignaciones$COD_POSTAL[i] &
        lengths(st_intersects(capas, g)) > 0L,
    ]
    if (nrow(otras)) {
      expect_lt(
        sum(as.numeric(st_area(suppressWarnings(st_intersection(
          g,
          st_union(st_geometry(otras))
        ))))),
        1
      )
    }
  }
})

test_that("se conserva una geometría para el CP nuevo en la provincia", {
  provincia <- st_read(
    file.path(Sys.getenv("CP_TEST_DIR", "data/provs"), "CP_09.gpkg"),
    layer = "codigos_postales",
    quiet = TRUE
  )
  cp <- provincia[provincia$COD_POSTAL == "42140", ]
  expect_equal(nrow(cp), 1L)
  expect_equal(st_is_empty(cp), FALSE)
  expect_gt(as.numeric(st_area(cp)), 870000)
})
