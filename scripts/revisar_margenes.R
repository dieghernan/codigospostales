library(sf)
library(dplyr)
local({
  directorio <- tempfile("revision_cadiz_")
  dir.create(directorio)
  on.exit(unlink(directorio, recursive = TRUE))
  archivo_zip <- "data/cartociudad/CARTOCIUDAD_CALLEJERO_CADIZ.zip"
  listado <- unzip(archivo_zip, list = TRUE)
  miembro <- listado$Name[grepl("[.]gpkg$", listado$Name)]
  unzip(archivo_zip, files = miembro, exdir = directorio, junkpaths = TRUE)
  puntos <- st_read(
    file.path(directorio, basename(miembro)),
    query = "SELECT cod_postal, ine_mun, geom FROM portalpk_publi",
    quiet = TRUE
  ) |>
    mutate(COD_POSTAL = trimws(as.character(cod_postal))) |>
    filter(!is.na(COD_POSTAL), grepl("^[0-9]{5}$", COD_POSTAL)) |>
    st_transform(25830)
  munis <- mapSpain::esp_get_munic_siane(region = "11", moveCAN = FALSE) |>
    st_transform(25830) |>
    st_make_valid()
  dentro <- st_intersects(munis, puntos)
  interior <- st_intersects(st_buffer(st_geometry(munis), -200), puntos)
  codigos_interior <- unique(puntos$COD_POSTAL[unique(unlist(interior))])
  actual <- st_read("data/provs/CP_11.gpkg", quiet = TRUE)
  revision <- vector("list", nrow(munis))
  for (i in seq_len(nrow(munis))) {
    p <- puntos[dentro[[i]], ]
    conteos <- p |>
      st_drop_geometry() |>
      group_by(COD_POSTAL) |>
      summarise(
        direcciones = n(),
        municipio_coincide = sum(
          ine_mun == paste0("11", munis$cmun[i]),
          na.rm = TRUE
        ),
        municipios_origen = paste(sort(unique(ine_mun)), collapse = ";"),
        .groups = "drop"
      )
    conteos$interior_200 <- vapply(
      conteos$COD_POSTAL,
      function(cp) {
        sum(puntos$COD_POSTAL[interior[[i]]] == cp)
      },
      integer(1)
    )
    conteos$cmun <- munis$cmun[i]
    conteos$municipio <- munis$name[i]
    conteos$presente_provincia <- conteos$COD_POSTAL %in% actual$COD_POSTAL
    conteos$presente_sin_recuperacion <- conteos$COD_POSTAL %in%
      codigos_interior
    conteos$decision <- case_when(
      conteos$interior_200 > 0 ~ "Conservar interior",
      conteos$municipio_coincide >
        0 ~ "Recuperar direcciones con municipio coincidente",
      TRUE ~ "Revisar discrepancia entre atributo municipal y geometría"
    )
    revision[[i]] <- conteos
  }
  revision <- bind_rows(revision)
  readr::write_csv(revision, "data/full_analisis/revision_margenes_11.csv")
  excluidos <- filter(revision, interior_200 == 0)
  print(excluidos, n = Inf, width = Inf)
  cat("PARES EXCLUIDOS:", nrow(excluidos), "\n")
  cat(
    "CODIGOS AUSENTES EN RESULTADO:",
    paste(
      setdiff(unique(puntos$COD_POSTAL), actual$COD_POSTAL),
      collapse = ", "
    ),
    "\n"
  )
  cat("RESUMEN MUNICIPIOS ATRIBUTO:\n")
  print(
    excluidos |>
      summarise(
        direcciones = sum(direcciones),
        coincide = sum(municipio_coincide)
      )
  )
  saveRDS(
    list(puntos = puntos, municipios = munis),
    "data/cartociudad/revision_cadiz.rds"
  )
})
