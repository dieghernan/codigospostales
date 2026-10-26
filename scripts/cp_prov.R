# Genera códigos postales para una provincia.

library(sf)
library(dplyr)
library(ggplot2)
library(mapSpain)
source("scripts/geometria.R")

# R en Windows puede heredar una configuración regional no disponible.
if (.Platform$OS.type == "windows") {
  if (
    !nzchar(suppressWarnings(Sys.setlocale("LC_CTYPE", "Spanish_Spain.utf8")))
  ) {
    stop("No se ha podido activar la codificación UTF-8.")
  }
}

# Extrae municipios ----

provincia <- Sys.getenv("CP_PROVINCIA", "SEGOVIA")
provincia <- toupper(iconv(trimws(provincia), to = "ASCII//TRANSLIT"))
provincia <- gsub("_", " ", provincia)

cpro <- esp_dict_region_code(
  if (provincia == "TENERIFE") "SANTA CRUZ DE TENERIFE" else provincia,
  destination = "cpro"
)
if (length(cpro) != 1L || is.na(cpro)) {
  stop("Provincia no reconocida.")
}


# Municipios de Goerlich
munis_all <- read_sf(
  "data/cartociudad/LAU2boundaries4Spain.gpkg",
  query = sprintf(
    'SELECT CodProv, CodMuni, Municipio, geom FROM Municipios2024 WHERE CodProv = \'%s\'',
    cpro
  )
)

condiminios <- read_sf(
  "data/cartociudad/LAU2boundaries4Spain.gpkg",
  query = sprintf(
    'SELECT CodProv, CodMuni, Municipio, geom FROM Condominios WHERE CodProv = \'%s\'',
    cpro
  )
)

provincias <- read_sf(
  "data/cartociudad/LAU2boundaries4Spain.gpkg",
  query = sprintf(
    'SELECT CodProv, Provincia, geom FROM Provincias WHERE CodProv = \'%s\'',
    cpro
  )
)

# El punto representativo queda dentro de la provincia, incluso si es cóncava.
prov <- provincias |> filter(CodProv == cpro)
referencia <- prov |>
  st_transform(25830) |>
  st_point_on_surface() |>
  st_transform(4326)
longitud <- st_coordinates(referencia)[1, "X"]
epsg <- if (cpro %in% c("35", "38")) {
  4083L
} else if (longitud < -6) {
  25829L
} else if (longitud >= 0) {
  25831L
} else {
  25830L
}

# Municipios y condominios proceden de la misma base administrativa.
munis <- munis_all |>
  filter(CodProv == cpro) |>
  bind_rows(
    condiminios |>
      filter(CodProv == cpro)
  ) |>
  st_transform(epsg) |>
  solo_poligonos() |>
  st_cast("POLYGON", warn = FALSE) |>
  resolver_solapes()

# Datos de CartoCiudad ----
# https://centrodedescargas.cnig.es/CentroDescargas/buscadorCatalogo.do?codFamilia=02122

# Descomprime en temp
temp <- file.path(tempdir(), paste0("cartociudad", cpro))
if (!dir.exists(temp)) {
  dir.create(temp, recursive = TRUE)
}


unzip(
  paste0(
    "data/cartociudad/CARTOCIUDAD_CALLEJERO_",
    if (cpro == "38") "TENERIFE" else gsub(" ", "_", provincia),
    ".zip"
  ),
  exdir = temp,
  junkpaths = TRUE
)

file <- list.files(temp, pattern = "gpkg$", full.names = TRUE)

st_layers(file)
cp <- st_read(
  file,
  query = "SELECT poblacion, cod_postal, geom from portalpk_publi",
  quiet = TRUE
)

# Limpia cp
cp_clean <- cp |>
  select(POBLACION = poblacion, COD_POSTAL = cod_postal) |>
  mutate(COD_POSTAL = normalizar_cp(COD_POSTAL)) |>
  st_cast("POINT") |>
  # Elimina si no hay CP
  filter(!is.na(COD_POSTAL))

cp_clean <- st_drop_geometry(cp_clean) |>
  bind_cols(st_coordinates(cp_clean)) |>
  distinct()

cp_clean_sf <- st_as_sf(cp_clean, coords = c("X", "Y"))

st_crs(cp_clean_sf) <- st_crs(cp)
cp_clean_sf <- st_transform(cp_clean_sf, epsg)

# Empieza el loop, pero sobre polígonos ----

munis <- munis |>
  st_cast("POLYGON", warn = FALSE)

finalcp <- list()


i <- 1

message("Recintos totales: ", nrow(munis))

for (i in seq_len(nrow(munis))) {
  m <- munis[i, ]

  message("Loop ", i, ", muni ", m$Municipio)

  # Extrae direcciones en el recinto m. pero antes se aplica
  # un buffer negativo
  m_buf <- st_buffer(m, -200)

  logi <- if (all(st_is_empty(m_buf))) {
    rep(FALSE, nrow(cp_clean_sf))
  } else {
    st_intersects(cp_clean_sf, m_buf, sparse = FALSE)
  }
  cp_m <- cp_clean_sf[as.vector(logi), ]

  # Si no hay direcciones, reduce buffer
  if (nrow(cp_m) == 0) {
    m_buf <- st_buffer(m, -50)

    logi <- if (all(st_is_empty(m_buf))) {
      rep(FALSE, nrow(cp_clean_sf))
    } else {
      st_intersects(cp_clean_sf, m_buf, sparse = FALSE)
    }
    cp_m <- cp_clean_sf[as.vector(logi), ]
  }

  # Si aún no hay direcciones, conserva el recinto con COD_POSTAL NA.
  if (nrow(cp_m) == 0) {
    message("Sin códigos postales")

    end <- data.frame(COD_POSTAL = NA) |>
      bind_cols(st_drop_geometry(m))

    vorcpend <- st_sf(
      end,
      geom = st_geometry(m)
    )

    finalcp <- bind_rows(finalcp, vorcpend)
  } else if (length(unique(cp_m$COD_POSTAL)) == 1) {
    # Si sólo hay un CP misma operación para optimizar el cruce
    message("Código postal único")

    end <- data.frame(COD_POSTAL = unique(cp_m$COD_POSTAL)) |>
      bind_cols(st_drop_geometry(m))

    vorcpend <- st_sf(
      end,
      geom = st_geometry(m)
    )

    finalcp <- bind_rows(finalcp, vorcpend)
  } else {
    # Crea teselación de esos puntos
    vor <- cp_m |>
      st_union() |>
      st_voronoi(envelope = st_geometry(m)) |>
      st_collection_extract("POLYGON")

    vor <- vor |>
      st_sf(id = seq_len(length(vor))) |>
      st_intersection(st_geometry(m))

    # Añade a cada polígono su Código postal y crea polígonos
    # finales
    vorcp <- st_join(vor, cp_m) |>
      group_by(COD_POSTAL) |>
      summarise(n = n()) |>
      st_make_valid() |>
      select(COD_POSTAL)

    vorcp <- vorcp |> bind_cols(st_drop_geometry(m))
    vorcpend <- st_sf(
      st_drop_geometry(vorcp),
      geom = st_geometry(vorcp)
    )

    finalcp <- bind_rows(finalcp, vorcpend)
  }
}

# Conserva los pendientes y disuelve por código postal.

sin_cp <- sum(is.na(finalcp$COD_POSTAL))
finalcp <- recuperar_cp_municipal(finalcp)
message(
  "Recintos completados con el CP único del municipio: ",
  sin_cp - sum(is.na(finalcp$COD_POSTAL))
)

pendientes <- finalcp |>
  filter(is.na(COD_POSTAL)) |>
  solo_poligonos()

finalcp <- finalcp |>
  group_by(COD_POSTAL) |>
  count() |>
  select(-n) |>
  solo_poligonos()

filename <- file.path("data", "provs", paste0("CP_", cpro, ".gpkg"))


st_write(finalcp, filename, append = FALSE)
st_write(pendientes, filename, layer = "pendientes", append = FALSE)


source("scripts/ggplot.R")
