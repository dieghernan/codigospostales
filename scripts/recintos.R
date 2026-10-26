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
