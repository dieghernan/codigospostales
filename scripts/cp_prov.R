# Asigna los solapes al recinto de menor área original; desempata por LAU_CODE.
resolver_solapes_recintos <- function(recintos) {
  areas <- as.numeric(sf::st_area(recintos))
  prioridad <- order(areas, recintos$LAU_CODE)
  vecinos <- sf::st_intersects(recintos)
  geometria <- sf::st_geometry(recintos)
  auditoria <- list()
  anteriores <- integer()
  for (i in prioridad) {
    for (j in intersect(anteriores, vecinos[[i]])) {
      comun <- suppressWarnings(sf::st_intersection(geometria[i], geometria[j]))
      area <- sum(as.numeric(sf::st_area(comun)))
      if (area > 0) {
        auditoria[[length(auditoria) + 1L]] <- data.frame(
          receptor = recintos$LAU_CODE[j],
          recortado = recintos$LAU_CODE[i],
          area_receptor_original_m2 = areas[j],
          area_recortado_original_m2 = areas[i],
          solape_m2 = area
        )
        geometria[i] <- sf::st_difference(geometria[i], geometria[j])
      }
    }
    anteriores <- c(anteriores, i)
  }
  sf::st_geometry(recintos) <- geometria
  if (any(sf::st_is_empty(recintos))) {
    stop("La resolución de solapes ha eliminado un recinto completo.")
  }
  list(recintos = recintos, auditoria = dplyr::bind_rows(auditoria))
}

# Genera la cartografía postal de una provincia desde la raíz del proyecto.
local({
  if (.Platform$OS.type == "windows") {
    if (!nzchar(Sys.setlocale("LC_CTYPE", "Spanish_Spain.utf8"))) {
      stop("No se ha podido activar el locale UTF-8.")
    }
  }
  library(sf)
  library(dplyr)
  library(mapSpain)
  helper_correcciones <- file.path(
    Sys.getenv("CP_METODO_DIR", "scripts"),
    "correcciones.R"
  )
  source(
    if (file.exists(helper_correcciones)) {
      helper_correcciones
    } else {
      "scripts/correcciones.R"
    },
    local = TRUE,
    encoding = "UTF-8"
  )
  source(
    file.path(Sys.getenv("CP_METODO_DIR", "scripts"), "recintos.R"),
    local = TRUE,
    encoding = "UTF-8"
  )

  provincia <- Sys.getenv("CP_PROVINCIA", "CADIZ")
  cpro <- Sys.getenv("CP_CPRO", "")
  if (!nzchar(cpro)) {
    cpro <- esp_dict_region_code(provincia, destination = "cpro")
  }
  if (length(cpro) != 1L || is.na(cpro)) {
    stop("No se ha identificado una única provincia: ", provincia)
  }
  # Los márgenes se calculan en una proyección local adecuada.
  epsg <- if (cpro %in% c("35", "38")) {
    4083L
  } else if (cpro %in% c("07", "08", "17", "25", "43")) {
    25831L
  } else if (cpro %in% c("06", "10", "15", "21", "27", "32", "36", "37")) {
    25829L
  } else {
    25830L
  }

  # El nombre del ZIP no lleva tildes.
  provincia_zip <- provincia |>
    iconv(to = "ASCII//TRANSLIT") |>
    toupper() |>
    gsub(" ", "_", x = _)
  if (cpro == "07") {
    provincia_zip <- "BALEARES"
  }
  if (cpro == "01") {
    provincia_zip <- "ALAVA"
  }
  if (cpro == "15") {
    provincia_zip <- "A_CORUNA"
  }
  if (cpro == "03") {
    provincia_zip <- "ALICANTE"
  }
  if (cpro == "38") {
    provincia_zip <- "TENERIFE"
  }
  archivo_zip <- file.path(
    "data",
    "cartociudad",
    paste0("CARTOCIUDAD_CALLEJERO_", provincia_zip, ".zip")
  )
  archivo_zip <- Sys.getenv("CP_ARCHIVO_ZIP", archivo_zip)
  salida <- Sys.getenv("CP_OUTPUT_DIR", "data/provs")
  analisis <- Sys.getenv("CP_ANALISIS_DIR", "data/full_analisis")
  dir.create(salida, recursive = TRUE, showWarnings = FALSE)
  dir.create(analisis, recursive = TRUE, showWarnings = FALSE)
  if (!file.exists(archivo_zip)) {
    stop("No se encuentra el archivo: ", archivo_zip)
  }

  # Un directorio nuevo evita reutilizar capas de una extracción anterior.
  directorio <- tempfile(paste0("cartociudad_", cpro, "_"))
  dir.create(directorio)
  on.exit(unlink(directorio, recursive = TRUE), add = TRUE)
  contenido <- unzip(archivo_zip, list = TRUE)
  capas_zip <- contenido$Name[grepl(
    "[.]gpkg$",
    contenido$Name,
    ignore.case = TRUE
  )]
  if (length(capas_zip) != 1L) {
    stop("El ZIP debe contener un único GeoPackage.")
  }
  unzip(archivo_zip, files = capas_zip, exdir = directorio, junkpaths = TRUE)
  archivo <- file.path(directorio, basename(capas_zip))
  if (!"portalpk_publi" %in% st_layers(archivo)$name) {
    stop("No se encuentra la capa portalpk_publi.")
  }
  portales <- st_read(
    archivo,
    query = 'SELECT cod_postal, ine_mun, geom FROM portalpk_publi',
    quiet = TRUE
  ) |>
    transmute(
      COD_POSTAL = trimws(as.character(cod_postal)),
      INE_MUN = as.character(ine_mun)
    ) |>
    filter(!is.na(COD_POSTAL), grepl("^[0-9]{5}$", COD_POSTAL)) |>
    st_transform(epsg)
  if (!nrow(portales)) {
    stop("No hay direcciones con códigos postales válidos.")
  }

  base_admin <- Sys.getenv("CP_BASE_ADMIN_RDS", "")
  base_admin <- if (nzchar(base_admin)) readRDS(base_admin) else NULL
  todos_municipios <- normalizar_campos_recintos(
    if (is.null(base_admin)) {
      esp_get_munic_siane(moveCAN = FALSE, rawcols = TRUE)
    } else {
      base_admin$municipios
    }
  )
  munis_init <- todos_municipios[
    todos_municipios$cpro == cpro & !es_condominio(todos_municipios),
  ] |>
    st_transform(epsg) |>
    st_make_valid()

  todas_provincias <- if (is.null(base_admin)) {
    esp_get_prov_siane(moveCAN = FALSE)
  } else {
    base_admin$provincias
  }
  prov <- todas_provincias[todas_provincias$cpro == cpro, ] |>
    st_transform(epsg)

  asignacion_condominios <- asignar_provincias_condominios(
    todos_municipios,
    todas_provincias
  )
  extra_munis <- todos_municipios[
    todos_municipios$LAU_CODE %in%
      asignacion_condominios$LAU_CODE[asignacion_condominios$cpro == cpro],
  ] |>
    st_transform(epsg) |>
    st_make_valid()

  if (nrow(extra_munis) > 0) {
    munis <- munis_init |> bind_rows(extra_munis)
  } else {
    munis <- munis_init
  }

  corregidos <- resolver_solapes_recintos(munis)
  munis <- corregidos$recintos
  readr::write_csv(
    corregidos$auditoria,
    file.path(analisis, paste0("solapes_recintos_", cpro, ".csv"))
  )

  munis <- separar_componentes_recintos(munis)

  # Cada componente selecciona sus direcciones y aplica sus propios márgenes.
  indices <- st_intersects(st_geometry(munis), st_geometry(portales))
  indices_200 <- st_intersects(st_buffer(st_geometry(munis), -200), portales)
  indices_50 <- st_intersects(st_buffer(st_geometry(munis), -50), portales)
  resultados <- vector("list", nrow(munis))
  diagnosticos <- vector("list", nrow(munis))
  message(
    "Recintos: ",
    nrow(munis_init),
    " municipios y ",
    nrow(extra_munis),
    " condominios"
  )

  for (i in seq_len(nrow(munis))) {
    municipio <- munis[i, ]
    message(
      "Recinto ",
      i,
      "/",
      nrow(munis),
      ": ",
      municipio$LAU_CODE,
      " ",
      municipio$name
    )
    seleccion <- seleccionar_direcciones_componente(
      portales,
      municipio,
      indices[[i]],
      indices_200[[i]],
      indices_50[[i]]
    )
    puntos <- seleccion$puntos
    codigos <- unique(puntos$COD_POSTAL)
    descartados <- setdiff(seleccion$codigos_originales, codigos)
    diagnosticos[[i]] <- data.frame(
      cpro = cpro,
      LAU_CODE = municipio$LAU_CODE,
      componente = municipio$componente,
      tipo_recinto = if (es_condominio(municipio)) {
        "condominio"
      } else {
        "municipio"
      },
      id_prov = municipio$id_prov,
      t_ua = municipio$t_ua,
      cmun = municipio$cmun,
      municipio = municipio$name,
      direcciones = length(indices[[i]]),
      seleccionadas = nrow(puntos),
      margen = seleccion$margen,
      direcciones_recuperadas = length(seleccion$recuperados),
      codigos_recuperados = paste(
        sort(setdiff(codigos, seleccion$codigos_interior)),
        collapse = ";"
      ),
      codigos = length(codigos),
      codigos_seleccionados = paste(sort(codigos), collapse = ";"),
      codigos_descartados = paste(sort(descartados), collapse = ";")
    )

    resultados[[i]] <- generar_codigos_componente(municipio, puntos)
  }

  por_municipio <- bind_rows(resultados)
  finalcp <- por_municipio |>
    filter(!is.na(COD_POSTAL)) |>
    select(COD_POSTAL) |>
    group_by(COD_POSTAL) |>
    summarise(.groups = "drop") |>
    st_make_valid()
  pendientes <- por_municipio |>
    filter(is.na(COD_POSTAL)) |>
    transmute(
      cpro = .env$cpro,
      LAU_CODE,
      nombre = name,
      motivo = "Sin direcciones seleccionadas con código postal"
    ) |>
    group_by(cpro, LAU_CODE, nombre, motivo) |>
    summarise(.groups = "drop")
  # Ajusta las dos capas al contorno provincial sin rellenar huecos postales.
  finalcp <- limpiar_ranuras_numericas(finalcp)$postal
  st_agr(finalcp) <- "constant"
  st_agr(pendientes) <- "constant"
  finalcp <- st_intersection(finalcp, st_geometry(prov)) |>
    st_make_valid()
  finalcp <- finalcp[!st_is_empty(finalcp) & st_dimension(finalcp) == 2L, ]
  if (nrow(pendientes)) {
    pendientes <- st_intersection(pendientes, st_geometry(prov)) |>
      st_make_valid()
    pendientes <- pendientes[
      !st_is_empty(pendientes) & st_dimension(pendientes) == 2L,
    ]
  }
  cubierto <- st_union(c(st_geometry(finalcp), st_geometry(pendientes)))
  huecos <- st_difference(st_union(st_geometry(prov)), cubierto) |>
    st_make_valid()
  if (sum(as.numeric(st_area(huecos))) > 0.0001) {
    pendientes <- bind_rows(
      pendientes,
      st_sf(
        cpro = cpro,
        LAU_CODE = paste0("PROV_GAP_", cpro),
        nombre = NA_character_,
        motivo = "Superficie provincial fuera de los recintos seleccionados",
        geometry = huecos
      )
    )
  }
  geometria <- c(st_geometry(finalcp), st_geometry(pendientes))
  union_total <- st_union(geometria)
  diferencia_m2 <- sum(as.numeric(st_area(st_sym_difference(
    union_total,
    st_union(st_geometry(prov))
  ))))
  solape_m2 <- sum(as.numeric(st_area(geometria))) -
    sum(as.numeric(st_area(union_total)))
  if (
    any(st_is_empty(geometria)) ||
      !all(st_is_valid(geometria)) ||
      diferencia_m2 > 1 ||
      abs(solape_m2) > 1 ||
      anyDuplicated(finalcp$COD_POSTAL)
  ) {
    stop(
      "Falló la validación de geometrías, cobertura, solapamientos o códigos únicos."
    )
  }
  componentes_diagnostico <- bind_rows(diagnosticos)
  unir_codigos <- function(x) {
    valores <- unlist(strsplit(x, ";", fixed = TRUE))
    paste(sort(unique(valores[nzchar(valores)])), collapse = ";")
  }
  diagnosticos <- componentes_diagnostico |>
    group_by(cpro, LAU_CODE, tipo_recinto, id_prov, t_ua, cmun, municipio) |>
    summarise(
      componentes = n(),
      componentes_sin_cp = sum(codigos == 0L),
      direcciones = sum(direcciones),
      seleccionadas = sum(seleccionadas),
      margen = paste(sort(unique(margen)), collapse = ";"),
      direcciones_recuperadas = sum(direcciones_recuperadas),
      codigos_recuperados = unir_codigos(codigos_recuperados),
      codigos_seleccionados = unir_codigos(codigos_seleccionados),
      codigos_descartados = unir_codigos(codigos_descartados),
      .groups = "drop"
    )
  diagnosticos$codigos <- lengths(strsplit(
    diagnosticos$codigos_seleccionados,
    ";",
    fixed = TRUE
  ))
  diagnosticos$codigos_descartados <- vapply(
    seq_len(nrow(diagnosticos)),
    function(i) {
      paste(
        setdiff(
          strsplit(diagnosticos$codigos_descartados[i], ";", fixed = TRUE)[[1]],
          strsplit(diagnosticos$codigos_seleccionados[i], ";", fixed = TRUE)[[
            1
          ]]
        ),
        collapse = ";"
      )
    },
    character(1)
  )
  readr::write_csv(
    componentes_diagnostico,
    file.path(analisis, paste0("diagnostico_componentes_", cpro, ".csv"))
  )
  fuente <- portales |>
    st_drop_geometry() |>
    count(COD_POSTAL, name = "direcciones")
  ausentes <- setdiff(fuente$COD_POSTAL, finalcp$COD_POSTAL)
  puntos_ausentes <- portales[portales$COD_POSTAL %in% ausentes, ]
  puntos_ausentes$dentro_provincia <- lengths(st_intersects(
    puntos_ausentes,
    prov
  )) >
    0L
  puntos_ausentes$dentro_recintos <- lengths(st_intersects(
    puntos_ausentes,
    munis
  )) >
    0L
  informe_ausentes <- puntos_ausentes |>
    st_drop_geometry() |>
    group_by(COD_POSTAL) |>
    summarise(
      direcciones = n(),
      dentro_provincia = sum(dentro_provincia),
      dentro_recintos = sum(dentro_recintos),
      .groups = "drop"
    ) |>
    mutate(
      motivo = if_else(
        dentro_provincia == 0L,
        "Fuera del límite provincial",
        "Excluido por margen o atribución municipal"
      )
    )
  validacion <- data.frame(
    cpro = cpro,
    municipios = nrow(munis_init),
    condominios = nrow(extra_munis),
    codigos = nrow(finalcp),
    fuente = nrow(fuente),
    recintos_pendientes = nrow(pendientes),
    pendientes_m2 = sum(as.numeric(st_area(pendientes))),
    diferencia_m2 = diferencia_m2,
    solape_m2 = solape_m2,
    ausentes = paste(ausentes, collapse = ";"),
    perdidos_dentro_provincia = sum(informe_ausentes$dentro_provincia > 0L)
  )
  provisional <- tempfile(
    paste0("CP_", cpro, "_"),
    tmpdir = salida,
    fileext = ".gpkg"
  )
  st_write(
    finalcp,
    provisional,
    layer = "codigos_postales",
    quiet = TRUE
  )
  st_write(pendientes, provisional, layer = "pendientes", quiet = TRUE)
  comprobacion <- st_read(provisional, layer = "codigos_postales", quiet = TRUE)
  if (nrow(comprobacion) != nrow(finalcp) || !all(st_is_valid(comprobacion))) {
    stop("No se ha podido verificar el GeoPackage escrito.")
  }
  if (
    !file.copy(
      provisional,
      file.path(salida, paste0("CP_", cpro, ".gpkg")),
      overwrite = TRUE
    )
  ) {
    stop("No se ha podido sustituir el resultado provincial.")
  }
  unlink(provisional)
  readr::write_csv(
    fuente,
    file.path(analisis, paste0("codigos_fuente_", cpro, ".csv"))
  )
  readr::write_csv(
    informe_ausentes,
    file.path(analisis, paste0("codigos_ausentes_", cpro, ".csv"))
  )
  readr::write_csv(
    validacion,
    file.path(analisis, paste0("validacion_", cpro, ".csv"))
  )
  readr::write_csv(
    st_drop_geometry(pendientes),
    file.path(analisis, paste0("pendientes_", cpro, ".csv"))
  )
  readr::write_csv(
    diagnosticos,
    file.path(analisis, paste0("diagnostico_", cpro, ".csv"))
  )
  message("Códigos postales: ", n_distinct(finalcp$COD_POSTAL, na.rm = TRUE))
  message("Municipios sin código postal: ", sum(diagnosticos$codigos == 0))
  message(
    "Municipios con códigos excluidos por el margen: ",
    sum(nzchar(diagnosticos$codigos_descartados))
  )
  if (identical(Sys.getenv("CP_CONSOLIDAR", "true"), "true")) {
    source("scripts/ggplot.R", local = TRUE)
  }
})
