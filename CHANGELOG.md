# Changelog

## En desarrollo

- La web da acceso directo a los dos consolidados, muestra sus características y añade un inicio rápido con R, Python y QGIS.
- El visor permite buscar un código postal y compartir la vista sin incluir direcciones buscadas, con controles y leyenda en español.

## 1.0.0

Primera versión pública del conjunto de datos de códigos postales de España.

- Añade delimitaciones estimadas de los códigos postales de España en formato
  GeoPackage.
- Incluye una versión simplificada de las delimitaciones para visualización y
  uso web.
- Incorpora un proceso reproducible basado en direcciones de CartoCiudad y
  límites administrativos.
- Las áreas de códigos postales se estiman mediante teselaciones de Voronoi,
  recortadas a los límites administrativos y disueltas por código postal.
- Incluye una capa `pendientes` con los recintos administrativos que no han
  podido asignarse a un código postal.
- Documenta la metodología, las fuentes de datos y las principales
  limitaciones.
- Añade ejemplos de uso en R y Python.
- Añade metadatos de citación mediante `CITATION.cff`.

### Notas

Las delimitaciones de códigos postales son estimaciones obtenidas a partir de
datos abiertos y no representan los límites postales oficiales de Correos.
