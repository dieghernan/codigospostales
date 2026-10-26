# Conserva la compatibilidad con bases congeladas sin los campos originales.
normalizar_campos_recintos <- function(recintos) {
  for (campo in c("id_prov", "t_ua")) {
    if (!campo %in% names(recintos)) {
      recintos[[campo]] <- NA_character_
    } else {
      recintos[[campo]] <- as.character(recintos[[campo]])
    }
  }
  recintos
}

separar_componentes_recintos <- function(recintos) {
  partes <- lapply(seq_len(nrow(recintos)), function(i) {
    geometria <- suppressWarnings(sf::st_collection_extract(
      sf::st_geometry(recintos[i, ]),
      "POLYGON"
    )) |>
      sf::st_cast("POLYGON")
    geometria <- geometria[!sf::st_is_empty(geometria)]
    resultado <- recintos[rep(i, length(geometria)), ]
    sf::st_geometry(resultado) <- geometria
    resultado$componente <- seq_along(geometria)
    resultado
  })
  dplyr::bind_rows(partes)
}

seleccionar_direcciones_componente <- function(
  portales,
  recinto,
  candidatos,
  interior_200,
  interior_50
) {
  seleccion <- interior_200
  margen <- 200L
  if (!length(seleccion)) {
    seleccion <- interior_50
    margen <- 50L
  }
  codigos_interior <- unique(portales$COD_POSTAL[seleccion])
  recuperados <- candidatos[
    !portales$COD_POSTAL[candidatos] %in% codigos_interior &
      !is.na(portales$INE_MUN[candidatos]) &
      portales$INE_MUN[candidatos] == recinto$LAU_CODE
  ]
  puntos <- portales[union(seleccion, recuperados), ]
  claves <- data.frame(
    sf::st_coordinates(puntos),
    COD_POSTAL = puntos$COD_POSTAL
  )
  puntos <- puntos[!duplicated(claves), ]
  list(
    puntos = puntos,
    margen = margen,
    recuperados = recuperados,
    codigos_interior = codigos_interior,
    codigos_originales = unique(portales$COD_POSTAL[candidatos])
  )
}

generar_codigos_componente <- function(recinto, puntos) {
  codigos <- unique(puntos$COD_POSTAL)
  if (length(codigos) <= 1L) {
    recinto$COD_POSTAL <- if (length(codigos)) codigos else NA_character_
    return(recinto)
  }
  if (anyDuplicated(data.frame(sf::st_coordinates(puntos)))) {
    stop("Hay coordenadas con códigos postales distintos en ", recinto$LAU_CODE)
  }
  celdas <- puntos |>
    sf::st_union() |>
    sf::st_voronoi(envelope = sf::st_as_sfc(sf::st_bbox(recinto))) |>
    sf::st_collection_extract("POLYGON")
  celdas <- sf::st_sf(geometry = celdas)
  asignacion <- sf::st_intersects(celdas, puntos)
  if (any(lengths(asignacion) != 1L)) {
    stop(
      "No se puede asignar un único portal a cada celda en ",
      recinto$LAU_CODE
    )
  }
  celdas$COD_POSTAL <- puntos$COD_POSTAL[unlist(asignacion)]
  sf::st_agr(celdas) <- "constant"
  recortadas <- sf::st_intersection(celdas, sf::st_geometry(recinto))
  recortadas <- recortadas[!sf::st_is_empty(recortadas), ] |>
    dplyr::group_by(COD_POSTAL) |>
    dplyr::summarise(.groups = "drop") |>
    sf::st_make_valid()
  atributos <- sf::st_drop_geometry(recinto)
  for (nombre in names(atributos)) {
    recortadas[[nombre]] <- atributos[[nombre]][1]
  }
  recortadas
}

es_condominio <- function(recintos) {
  recintos <- normalizar_campos_recintos(recintos)
  disponible <- !is.na(recintos$t_ua) & nzchar(recintos$t_ua)
  ifelse(disponible, recintos$t_ua == "4", is.na(recintos$name))
}

asignar_provincias_condominios <- function(recintos, provincias) {
  condominios <- normalizar_campos_recintos(recintos)
  condominios <- condominios[es_condominio(condominios), ]
  puntos <- condominios |>
    sf::st_transform(25830) |>
    sf::st_make_valid() |>
    sf::st_geometry() |>
    sf::st_point_on_surface()
  cruces <- sf::st_intersects(puntos, sf::st_transform(provincias, 25830))
  if (any(lengths(cruces) != 1L)) {
    stop("Hay condominios sin provincia única para su punto interior.")
  }
  espacial <- as.character(provincias$cpro[unlist(cruces)])
  original <- condominios$id_prov
  disponible <- !is.na(original) & nzchar(original)
  original[disponible] <- sprintf("%02d", as.integer(original[disponible]))
  discrepancia <- disponible & (is.na(original) | original != espacial)
  if (any(discrepancia)) {
    stop(
      "id_prov no coincide con la provincia del punto interior en: ",
      paste(condominios$LAU_CODE[discrepancia], collapse = ", "),
      "."
    )
  }
  data.frame(
    LAU_CODE = condominios$LAU_CODE,
    cpro = ifelse(disponible, original, espacial),
    id_prov = original,
    t_ua = condominios$t_ua,
    criterio_provincia = ifelse(
      disponible,
      "id_prov contrastado con punto interior",
      "punto interior"
    )
  )
}
