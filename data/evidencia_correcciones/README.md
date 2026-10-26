# Evidencia de las correcciones publicadas

Este directorio conserva la evidencia mínima de las correcciones aprobadas.
`catalogo.json` enumera los paquetes activos, sus capas y sus huellas SHA-256.
Cada lote congela el catálogo y los archivos de asignaciones, sin consultar
el WMS. No contiene resultados anteriores ni respaldos completos.

Los archivos de este nivel documentan las 34 correcciones originales:

- Los 43 GeoJSON son las entidades consultadas en la capa `codigo-postal`
  del [WMS de CartoCiudad](https://www.cartociudad.es/wms-inspire/direcciones-ccpp?service=WMS&request=GetCapabilities).
  Se conservan sus propiedades e identificadores originales. Una entidad
  consultada no necesariamente representa todo el territorio de un CP.
- `asignaciones_respaldadas.gpkg` contiene las 34 intersecciones incorporadas,
  con el CP y el identificador del recinto usados para la auditoría.
- `exclusiones_territoriales.gpkg` contiene el polígono de Gibraltar excluido
  del alcance español.
- `seleccion_recintos.csv` registra los criterios de selección.
- Los dos logs documentan las 1.021 comprobaciones previas y las 790
  comprobaciones posteriores a la publicación original. Son registros
  históricos; no corresponden a la regeneración posterior por componentes.
- `manifest.json` registra los tamaños y las huellas SHA-256 de esos archivos.

Las pruebas portables comprueban las huellas, el respaldo espacial de las
asignaciones, su presencia en los CP publicados y la existencia de residuos
pendientes en los 34 recintos. La comparación histórica completa con las
geometrías anteriores se ejecutó antes de publicar; sus respaldos permanecen
fuera de Git. La regeneración por componentes reutiliza esta evidencia local
y conserva sus bytes y sus huellas, incluidos los finales de línea de los logs.

Para ejecutar las pruebas desde la raíz del repositorio:

```sh
Rscript tests/ejecutar.R
```

Se necesitan los paquetes **testthat**, **sf**, **readr**, **dplyr**,
**digest** y **jsonlite**. Los resultados publicados y la base administrativa
corregida permiten verificar la cobertura sin descargar las fuentes.

El paquete [componentes_20261026](componentes_20261026/README.md) añade 191
asignaciones de 189 recintos e incorpora los CP 04071 y 43548. Conserva las
intersecciones aprobadas en las proyecciones provinciales, el respaldo
recortado y las superficies disputadas. Las respuestas WMS completas y
los respaldos de resultados siguen fuera de Git.

Fuente de los GeoJSON: CartoCiudad, consultado el 26 de octubre de 2026.
Obra derivada de CartoCiudad CC-BY 4.0, [SCNE](https://www.scne.es/).
