# Crea Códigos Postales para una provincia Provincia

library(sf)
library(dplyr)
library(ggplot2)
library(mapSpain)

# Extrae municipios ----


provincia <- "HUELVA"

cpro <- esp_dict_region_code(provincia, destination = "cpro")


munis <- esp_get_munic_siane(
  region = cpro,
  moveCAN = FALSE
) %>%
  st_transform(25830)

# Datos de CartoCiudad ----
# https://centrodedescargas.cnig.es/CentroDescargas/buscadorCatalogo.do?codFamilia=02122

# Descomprime en temp
temp <- file.path(tempdir(), paste0("cartociudad", cpro))
if (!dir.exists(temp)) dir.create(temp, recursive = TRUE)


unzip(paste0(
  "data/cartociudad/CARTOCIUDAD_CALLEJERO_",
  gsub(" ", "_", provincia), ".zip"
),
exdir = temp, junkpaths = TRUE
)

file <- list.files(temp,
  pattern = "^PORTAL.*.shp$",
  full.names = TRUE
)

cp <- st_read(file)

# Limpia cp
cp_clean <- cp %>%
  select(POBLACION, COD_POSTAL) %>%
  st_cast("POINT") %>%
  # Elimina si no hay CP
  filter(!is.na(COD_POSTAL))

cp_clean <- st_drop_geometry(cp_clean) %>%
  bind_cols(st_coordinates(cp_clean)) %>%
  distinct()

cp_clean_sf <- st_as_sf(cp_clean, coords = c("X", "Y"))

st_crs(cp_clean_sf) <- st_crs(cp)
cp_clean_sf <- st_transform(cp_clean_sf, 25830)

# Empieza el loop ----

finalcp <- list()


i <- 1

message("Municipios totales: ", nrow(munis))

for (i in seq_len(nrow(munis))) {
  m <- munis[i, ]

  message("Loop ", i, ", muni ", m$name)

  # Extrae direcciones en el recinto m. pero antes se aplica
  # un buffer negativo
  m_buf <- st_buffer(m, -200)

  logi <- st_intersects(cp_clean_sf, m_buf, sparse = FALSE)
  cp_m <- cp_clean_sf[as.vector(logi), ]

  # Si no hay direcciones, reduce buffer
  if (nrow(cp_m) == 0) {
    m_buf <- st_buffer(m, -50)

    logi <- st_intersects(cp_clean_sf, m_buf, sparse = FALSE)
    cp_m <- cp_clean_sf[as.vector(logi), ]
  }

  # Si aun asi no hay direcciones, crea un recinto con COD_POSTAl NA
  if (nrow(cp_m) == 0) {
    message("Sin códigos postales")

    end <- data.frame(COD_POSTAL = NA) %>%
      bind_cols(st_drop_geometry(m))


    vorcpend <- st_sf(
      end,
      geom = st_geometry(m)
    )

    finalcp <- bind_rows(finalcp, vorcpend)
  }

  # Si sólo hay un CP misma operación para optimizar el cruce
  else if (length(unique(cp_m$COD_POSTAL)) == 1) {
    message("Código Postal único")

    end <- data.frame(COD_POSTAL = unique(cp_m$COD_POSTAL)) %>%
      bind_cols(st_drop_geometry(m))


    vorcpend <- st_sf(
      end,
      geom = st_geometry(m)
    )

    finalcp <- bind_rows(finalcp, vorcpend)
  } else {


    # Crea teselación de esos puntos
    vor <- cp_m %>%
      st_union() %>%
      st_voronoi(envelope = st_geometry(m)) %>%
      st_collection_extract("POLYGON")

    vor <- vor %>%
      st_sf(id = seq_len(length(vor))) %>%
      st_intersection(st_geometry(m))

    # Añade a cada polígono su Código postal y crea polígonos
    # finales
    vorcp <- st_join(vor, cp_m) %>%
      group_by(COD_POSTAL) %>%
      summarise(n = n()) %>%
      st_make_valid() %>%
      select(COD_POSTAL)

    vorcp <- vorcp %>% bind_cols(st_drop_geometry(m))
    vorcpend <- st_sf(
      st_drop_geometry(vorcp),
      geom = st_geometry(vorcp)
    )

    finalcp <- bind_rows(finalcp, vorcpend)
  }
}


filename <- file.path("data", "provs", paste0("CP_", cpro, ".gpkg"))


st_write(finalcp,
  filename,
  append = FALSE
)


rm(list = ls())

source("scripts/ggplot.R")
