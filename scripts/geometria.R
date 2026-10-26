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

# Elimina solo anillos interiores numéricos en coordenadas métricas.
limpiar_anillos <- function(x, pendientes, umbral_m2 = 1e-6) {
  stopifnot(!st_is_longlat(x), st_crs(x) == st_crs(pendientes))
  original <- st_geometry(x)
  proteccion <- c(original, st_geometry(pendientes))
  cajas <- st_sfc(
    lapply(original, function(g) {
      st_as_sfc(st_bbox(st_sfc(g, crs = st_crs(x))))[[1]]
    }),
    crs = st_crs(x)
  )
  cercanos <- st_intersects(cajas, proteccion)
  eliminados <- 0L
  resultado <- lapply(seq_along(original), function(i) {
    poligonos <- lapply(original[[i]], function(poligono) {
      conservar <- rep(TRUE, length(poligono))
      for (j in seq_along(poligono)[-1L]) {
        anillo <- poligono[[j]]
        # Trasladar al origen evita cancelaciones con coordenadas UTM grandes.
        xy <- sweep(anillo, 2, anillo[1, ], "-")
        area <- abs(sum(
          xy[-nrow(xy), 1] * xy[-1, 2] - xy[-1, 1] * xy[-nrow(xy), 2]
        )) /
          2
        if (area > umbral_m2) {
          next
        }
        hueco <- st_sfc(st_polygon(list(anillo)), crs = st_crs(x))
        vecinos <- setdiff(cercanos[[i]], i)
        vecinos <- vecinos[st_intersects(hueco, proteccion[vecinos])[[1]]]
        ocupado <- length(vecinos) &&
          any(
            as.numeric(st_area(
              suppressWarnings(st_intersection(hueco, proteccion[vecinos]))
            )) >
              0
          )
        if (!ocupado) {
          conservar[j] <- FALSE
          eliminados <<- eliminados + 1L
        }
      }
      poligono[conservar]
    })
    st_multipolygon(poligonos)
  })
  st_geometry(x) <- st_sfc(resultado, crs = st_crs(x))
  if (!all(st_is_valid(x))) {
    stop("La limpieza ha producido geometrías inválidas.")
  }
  message("Anillos numéricos eliminados: ", eliminados)
  x
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
