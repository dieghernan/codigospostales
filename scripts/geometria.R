# Extrae únicamente superficies y conserva una geometría por registro.
solo_poligonos <- function(x) {
  g <- st_make_valid(st_geometry(x))
  g <- lapply(g, function(part) {
    if (!inherits(part, c("POLYGON", "MULTIPOLYGON", "GEOMETRYCOLLECTION"))) {
      return(st_multipolygon())
    }
    surface <- suppressWarnings(st_collection_extract(st_sfc(part), "POLYGON"))
    if (length(surface) == 0L || all(st_is_empty(surface))) {
      return(st_multipolygon())
    }
    st_cast(st_union(surface), "MULTIPOLYGON", warn = FALSE)[[1]]
  })
  st_geometry(x) <- st_sfc(g, crs = st_crs(x))
  x[!st_is_empty(x), ]
}

# En cada solape conserva la superficie del recinto original más pequeño.
resolver_solapes <- function(x) {
  x <- solo_poligonos(x)
  area <- as.numeric(st_area(x))
  orden <- order(area, seq_along(area))
  vecinos <- st_intersects(x)
  original <- st_geometry(x)
  resultado <- original
  for (i in orden) {
    menores <- vecinos[[i]]
    menores <- menores[
      area[menores] < area[i] |
        (area[menores] == area[i] & menores < i)
    ]
    if (length(menores)) {
      resultado[i] <- st_difference(original[i], st_union(original[menores]))
    }
  }
  st_geometry(x) <- resultado
  solo_poligonos(x)
}

# CP siempre como texto, incluidos los ceros iniciales.
normalizar_cp <- function(x) {
  x <- trimws(as.character(x))
  x[x == ""] <- NA_character_
  cortos <- !is.na(x) & grepl("^[0-9]{1,4}$", x)
  x[cortos] <- sprintf("%05d", as.integer(x[cortos]))
  if (any(!is.na(x) & !grepl("^[0-9]{5}$", x))) {
    stop("Hay códigos postales con formato incorrecto.")
  }
  x
}

# Completa pendientes solo cuando el municipio tiene un único CP recuperado.
recuperar_cp_municipal <- function(x) {
  conocidos <- st_drop_geometry(x)[, c("CodMuni", "COD_POSTAL")]
  conocidos <- unique(conocidos[
    !is.na(conocidos$CodMuni) & !is.na(conocidos$COD_POSTAL),
  ])
  varios <- duplicated(conocidos$CodMuni) |
    duplicated(conocidos$CodMuni, fromLast = TRUE)
  unicos <- conocidos[!varios, ]
  pendientes <- is.na(x$COD_POSTAL)
  x$COD_POSTAL <- as.character(x$COD_POSTAL)
  x$COD_POSTAL[pendientes] <- unicos$COD_POSTAL[
    match(x$CodMuni[pendientes], unicos$CodMuni)
  ]
  x
}
