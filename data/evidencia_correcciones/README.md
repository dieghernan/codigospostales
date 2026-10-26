# Evidencia de las correcciones publicadas

Este directorio conserva la evidencia mínima de las 34 correcciones
publicadas el 26 de octubre de 2026. No contiene resultados anteriores ni
respaldos completos.

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
  comprobaciones posteriores a la publicación.
- `manifest.json` registra los tamaños y las huellas SHA-256 de esos archivos.

Las pruebas portables comprueban las huellas, el respaldo espacial de las
asignaciones, su presencia en los CP publicados y la existencia de residuos
pendientes en los 34 recintos. La comparación histórica completa con las
geometrías anteriores
se ejecutó antes de publicar; sus respaldos permanecen fuera de Git.

Para ejecutar las pruebas desde la raíz del repositorio:

```sh
Rscript tests/ejecutar.R
```

Se necesitan los paquetes **testthat**, **sf**, **readr**, **dplyr**,
**digest** y **jsonlite**. Los resultados publicados y la base administrativa
corregida permiten verificar la cobertura sin descargar las fuentes.

Fuente de los GeoJSON: CartoCiudad, consultado el 26 de octubre de 2026.
Obra derivada de CartoCiudad CC-BY 4.0, [SCNE](https://www.scne.es/).
