# Evidencia aprobada por componentes

Corrección aprobada el 26 de octubre de 2026 tras revisar manualmente los
pendientes mediante 5.186 consultas WMS, sin errores de consulta.

- `asignaciones.gpkg` contiene 191 asignaciones de 189 recintos. Cada capa
  `asignaciones_<cpro>` conserva la proyección nativa de su provincia. Son
  intersecciones con INE coincidente, recortadas al pendiente y sin las
  superficies respaldadas por un CP diferente. No representan CP completos.
- `respaldo.gpkg` contiene las capas `respaldo` y `disputas`, recortadas a
  los componentes estudiados y conservadas en EPSG:25830. Permite verificar
  el respaldo y las exclusiones de las asignaciones aprobadas.
- `fuentes.csv` conserva los identificadores de las entidades WMS y las
  huellas SHA-256 de las respuestas originales guardadas localmente.
- `seleccion.csv` y `revision.json` describen la selección y las áreas del
  análisis previo en EPSG:25830. Las áreas finales se obtienen después del
  recorte nativo y de la consolidación y figuran en el cierre publicado.
- `manifest.json` permite comprobar los bytes de los archivos de evidencia.

Los CP 04071 y 43548 no aparecían en las fuentes de direcciones utilizadas.
El respaldo WMS justifica su incorporación por intersecciones; no se rellenan
los componentes administrativos completos.

La revisión manual no forma parte del flujo automático. Los lotes reaplican
estas geometrías locales, conservan los residuos y se detienen si la evidencia
invade otro CP o deja de encajar en la base por al menos 1 m². Las consultas
completas, las fuentes ZIP y los respaldos de resultados están excluidos de Git.

Fuente: [WMS de CartoCiudad](https://www.cartociudad.es/wms-inspire/direcciones-ccpp),
consultado el 26 de octubre de 2026. Obra derivada de CartoCiudad CC-BY 4.0.
