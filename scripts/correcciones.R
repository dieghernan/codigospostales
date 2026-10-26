area_geometria <- function(g) sum(as.numeric(sf::st_area(g)))

solo_poligonos <- function(g) {
  g <- sf::st_make_valid(g)
  g <- g[!sf::st_is_empty(g) & sf::st_dimension(g) == 2L]
  if (!length(g)) {
    return(g)
  }
  g <- suppressWarnings(sf::st_collection_extract(g, "POLYGON"))
  g[!sf::st_is_empty(g)]
}

disolver_codigos <- function(postal) {
  postal |>
    dplyr::select(COD_POSTAL) |>
    dplyr::group_by(COD_POSTAL) |>
    dplyr::summarise(.groups = "drop") |>
    sf::st_make_valid()
}

limpiar_ranuras_numericas <- function(postal) {
  eliminadas <- 0L
  limpiar_poligono <- function(anillos) {
    conservar <- rep(TRUE, length(anillos))
    for (i in seq_along(anillos)[-1]) {
      r <- anillos[[i]]
      r <- sweep(r[, 1:2, drop = FALSE], 2, r[1, 1:2])
      a <- abs(sum(r[-nrow(r), 1] * r[-1, 2] - r[-1, 1] * r[-nrow(r), 2])) / 2
      longitud <- sum(sqrt(rowSums(
        (r[-1, , drop = FALSE] - r[-nrow(r), , drop = FALSE])^2
      )))
      if (a <= 1e-6 && longitud > 2 && 2 * a / longitud < 1e-8) {
        conservar[i] <- FALSE
        eliminadas <<- eliminadas + 1L
      }
    }
    anillos[conservar]
  }
  g <- sf::st_geometry(postal)
  for (i in seq_along(g)) {
    if (inherits(g[[i]], "POLYGON")) {
      g[[i]] <- sf::st_polygon(limpiar_poligono(g[[i]]))
    } else if (inherits(g[[i]], "MULTIPOLYGON")) {
      g[[i]] <- sf::st_multipolygon(lapply(g[[i]], limpiar_poligono))
    }
  }
  sf::st_geometry(postal) <- g
  list(postal = postal, ranuras_eliminadas = eliminadas)
}

ajustar_precision_submicrometrica <- function(x) {
  sf::st_geometry(x) <- sf::st_as_sfc(
    sf::st_as_binary(sf::st_set_precision(sf::st_geometry(x), 1e7)),
    crs = sf::st_crs(x)
  )
  sf::st_set_precision(x, 0)
}

aplicar_asignaciones <- function(
  postal,
  pendientes,
  asignaciones,
  reintentar = TRUE
) {
  original_postal <- postal
  original_pendientes <- pendientes
  stopifnot(!anyDuplicated(postal$COD_POSTAL))
  asignaciones <- sf::st_transform(asignaciones, sf::st_crs(postal))
  antes <- sf::st_union(c(sf::st_geometry(postal), sf::st_geometry(pendientes)))
  operaciones <- list()
  aplicadas <- list()
  for (i in seq_len(nrow(asignaciones))) {
    a <- asignaciones[i, ]
    cp <- a$COD_POSTAL
    k <- which(pendientes$LAU_CODE == a$LAU_CODE)
    region <- if (length(k)) {
      sf::st_union(sf::st_geometry(pendientes)[k])
    } else {
      sf::st_sfc(crs = sf::st_crs(postal))
    }
    destino <- which(postal$COD_POSTAL == cp)
    propia <- sf::st_geometry(postal)[destino]
    g <- solo_poligonos(sf::st_geometry(a))
    if (length(propia) && area_geometria(sf::st_difference(g, propia)) < 1e-4) {
      operaciones[[i]] <- data.frame(
        cpro = a$cpro,
        LAU_CODE = a$LAU_CODE,
        COD_POSTAL = cp,
        transferido_km2 = 0,
        fuera_de_base_m2 = 0,
        conflicto_otro_cp_m2 = 0
      )
      next
    }
    permitida <- sf::st_union(c(region, propia))
    fuera <- area_geometria(sf::st_difference(g, permitida))
    if (fuera >= 1) {
      stop("Evidencia incompatible con la base actual: ", a$LAU_CODE, "/", cp)
    }
    otras <- postal[postal$COD_POSTAL != cp, ]
    disputa <- if (nrow(otras)) {
      area_geometria(suppressWarnings(sf::st_intersection(
        g,
        sf::st_union(sf::st_geometry(otras))
      )))
    } else {
      0
    }
    if (disputa >= 1) {
      stop("La evidencia invade otro CP: ", a$LAU_CODE, "/", cp)
    }
    transferida <- if (length(region)) {
      solo_poligonos(suppressWarnings(sf::st_intersection(g, region)))
    } else {
      region
    }
    if (length(transferida) && nrow(otras)) {
      transferida <- solo_poligonos(sf::st_difference(
        transferida,
        sf::st_union(sf::st_geometry(otras))
      ))
    }
    area <- area_geometria(transferida)
    if (area > 1e-4) {
      nueva_asignacion <- a
      sf::st_geometry(nueva_asignacion) <- sf::st_union(transferida)
      aplicadas[[length(aplicadas) + 1L]] <- nueva_asignacion
      stopifnot(length(k) == 1L)
      sf::st_geometry(pendientes)[k] <- sf::st_difference(
        region,
        sf::st_union(transferida)
      )
      if (length(destino)) {
        sf::st_geometry(postal)[destino] <- sf::st_union(c(propia, transferida))
      } else {
        nueva <- sf::st_sf(
          COD_POSTAL = cp,
          geometry = sf::st_union(transferida)
        )
        columna <- attr(postal, "sf_column")
        names(nueva)[names(nueva) == "geometry"] <- columna
        sf::st_geometry(nueva) <- columna
        postal <- dplyr::bind_rows(postal, nueva)
      }
    }
    if (area <= 1e-4) {
      area <- 0
    }
    operaciones[[i]] <- data.frame(
      cpro = a$cpro,
      LAU_CODE = a$LAU_CODE,
      COD_POSTAL = cp,
      transferido_km2 = area / 1e6,
      fuera_de_base_m2 = fuera,
      conflicto_otro_cp_m2 = disputa
    )
  }
  pendientes <- pendientes[
    !sf::st_is_empty(pendientes) & sf::st_dimension(pendientes) == 2L,
  ]
  limpieza <- limpiar_ranuras_numericas(disolver_codigos(postal))
  postal <- limpieza$postal
  despues <- sf::st_union(c(
    sf::st_geometry(postal),
    sf::st_geometry(pendientes)
  ))
  diferencia <- area_geometria(sf::st_sym_difference(antes, despues))
  solape <- area_geometria(c(
    sf::st_geometry(postal),
    sf::st_geometry(pendientes)
  )) -
    area_geometria(despues)
  if (diferencia >= 1 || abs(solape) >= 1) {
    if (!reintentar) {
      stop(
        "La corrección altera la cobertura: diferencia=",
        diferencia,
        " m²; solape=",
        solape,
        " m²."
      )
    }
    resultado <- aplicar_asignaciones(
      ajustar_precision_submicrometrica(original_postal),
      ajustar_precision_submicrometrica(original_pendientes),
      ajustar_precision_submicrometrica(asignaciones),
      reintentar = FALSE
    )
    cobertura <- sf::st_union(c(
      sf::st_geometry(resultado$postal),
      sf::st_geometry(resultado$pendientes)
    ))
    diferencia_original <- area_geometria(sf::st_sym_difference(
      antes,
      cobertura
    ))
    if (diferencia_original >= 1) {
      stop(
        "La estabilización numérica altera la cobertura original: ",
        diferencia_original,
        " m²."
      )
    }
    resultado$diferencia_m2 <- diferencia_original
    resultado$precision_m <- 1e-7
    return(resultado)
  }
  stopifnot(
    all(sf::st_is_valid(postal)),
    all(sf::st_is_valid(pendientes)),
    !anyDuplicated(postal$COD_POSTAL)
  )
  list(
    postal = postal,
    pendientes = pendientes,
    operaciones = if (length(operaciones)) {
      dplyr::bind_rows(operaciones)
    } else {
      data.frame(
        cpro = character(),
        LAU_CODE = character(),
        COD_POSTAL = character(),
        transferido_km2 = double(),
        fuera_de_base_m2 = double(),
        conflicto_otro_cp_m2 = double()
      )
    },
    asignaciones_aplicadas = dplyr::bind_rows(aplicadas),
    diferencia_m2 = diferencia,
    solape_m2 = solape,
    ranuras_eliminadas = limpieza$ranuras_eliminadas,
    precision_m = 0
  )
}
