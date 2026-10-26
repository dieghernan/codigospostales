# Códigos postales de España

Este proyecto genera una cartografía aproximada de los códigos postales de
España con R, a partir de las direcciones de CartoCiudad y los límites
municipales obtenidos con `mapSpain`. Los resultados se guardan por provincia en
formato GeoPackage. El resultado final tiene un registro por código postal, que
puede abarcar varios municipios o provincias.

## Metodología

El procedimiento se basa en los siguientes trabajos:

- [Así hice el mapa de los códigos postales de España con SIG y datos
  abiertos](https://www.nosolosig.com/articulos/asi-hice-el-mapa-de-los-codigos-postales-de-espana-con-sig-y-datos-abiertos),
  de José Ignacio Sánchez (Nosolosig), que propone generar polígonos de Voronoi
  a partir de las direcciones de CartoCiudad y agruparlos por código postal.
- [Elaboración de un mapa de Códigos Postales de España con recursos
  libres](https://www.uv.es/goerlich/Ivie/CodPost.html), de Francisco Goerlich
  (Universitat de València e Ivie), que refina el método mediante el
  procesamiento por municipio y el ajuste a sus límites.

La implementación de este repositorio adapta esos métodos a un flujo por
provincias:

1.  Obtiene los límites municipales y provinciales e incorpora los condominios
    mediante un punto interior calculado con `st_point_on_surface()`. Lee los
    portales y puntos kilométricos de CartoCiudad con código postal.
2.  Selecciona las direcciones dentro de cada municipio, aplicando un margen
    interior de 200 metros para reducir problemas cerca de los límites. Si no
    quedan direcciones, reduce el margen a 50 metros. Recupera los códigos que
    solo aparecen en la franja exterior cuando las direcciones caen dentro del
    municipio y su código municipal en CartoCiudad coincide con ese recinto.
3.  Si queda un único código postal, lo asigna a todo el municipio. Si hay
    varios, genera una teselación de Voronoi, la recorta al límite municipal y
    agrupa los polígonos por código postal. Si no quedan direcciones, conserva
    el recinto en la capa `pendientes`, sin asignarle un código postal.
4.  Agrupa los resultados por código postal dentro de cada provincia, conserva
    los huecos interiores para evitar solapamientos y exporta un GeoPackage con
    una capa `codigos_postales` con `COD_POSTAL` y geometría y otra capa
    `pendientes` con las superficies sin asignación. El municipio se utiliza
    únicamente para el cálculo y el diagnóstico.
5.  Une los resultados provinciales y vuelve a agrupar exclusivamente por código
    postal, incluso cuando aparece en varias provincias. Guarda el resultado
    conjunto en `data/codigos_postales.gpkg`.

Los límites resultantes son estimaciones y pueden diferir de la delimitación
oficial de Correos. Su precisión depende de los datos de partida y del
procesamiento; el margen interior puede excluir direcciones y códigos postales
próximos a los límites municipales.

## Uso

Abre `codigospostales.Rproj` en RStudio e instala las dependencias:

``` r
install.packages(c("sf", "dplyr", "ggplot2", "mapSpain", "readr"))
```

Descarga el callejero de la provincia desde el [Centro de Descargas del
CNIG](https://centrodedescargas.cnig.es/CentroDescargas/buscadorCatalogo.do?codFamilia=02122)
y guarda el ZIP en `data/cartociudad/`. El script espera un nombre como
`CARTOCIUDAD_CALLEJERO_GRANADA.zip`, con el nombre provincial en mayúsculas y
los espacios sustituidos por guiones bajos.

Selecciona la provincia mediante `CP_PROVINCIA` y ejecuta el script desde la
raíz del proyecto. La provincia predeterminada es Cádiz:

``` r
Sys.setenv(CP_PROVINCIA = "CADIZ")
Sys.setlocale("LC_CTYPE", "Spanish_Spain.utf8") # En Windows
source("scripts/cp_prov.R", encoding = "UTF-8")
```

El script guarda el resultado en `data/provs/CP_<código provincial>.gpkg` y
ejecuta `scripts/ggplot.R` para actualizar el mapa de avance y el CSV de
superficies pendientes de asignación. El procesamiento se ejecuta en un entorno
local y conserva los objetos de la sesión.

También guarda un diagnóstico por municipio con el número de direcciones, el
margen utilizado y los códigos postales recuperados o excluidos por ese margen.
El prefijo provincial del código postal no se utiliza como filtro. Los casos con
coordenadas compartidas por distintos códigos postales detienen el proceso para
evitar una asignación ambigua.

El cálculo utiliza ETRS89 / UTM 29N en A Coruña, Badajoz, Cáceres, Huelva,
Lugo, Ourense, Pontevedra y Salamanca. Utiliza ETRS89 / UTM 31N en Baleares,
Barcelona, Girona, Lleida y Tarragona y ETRS89 / UTM 30N en el resto de la
península, Ceuta y Melilla. En Canarias utiliza REGCAN95 / UTM 28N.
Los resultados provinciales conservan esa proyección; el archivo conjunto se
transforma a ETRS89 / UTM 30N.

Para Baleares y Álava, los nombres de los ZIP del CNIG son
`CARTOCIUDAD_CALLEJERO_BALEARES.zip` y `CARTOCIUDAD_CALLEJERO_ALAVA.zip`.

Para actualizar el resultado conjunto, el mapa y el CSV a partir de los
GeoPackage existentes:

``` r
source("scripts/ggplot.R")
```

## Estructura

### Reejecución por lotes

`scripts/reejecutar.R` utiliza el directorio indicado en
`data/cartociudad/reejecucion_actual.txt`. Allí conserva el respaldo, el
manifiesto de fuentes con huellas SHA-256, las copias del método y de las capas
administrativas, los registros y los resultados provisionales.

El inventario del script reconoce las 52 fuentes provinciales, incluidas Ceuta
y Melilla. Una ejecución existente conserva su manifiesto y su copia congelada
del método: descargar más provincias o actualizar los scripts del repositorio
no las incorpora al lote en curso. Las nuevas fuentes requieren preparar otro
lote; la fase `resto` únicamente procesa las entradas de su manifiesto.

Si dos recintos se solapan, la superficie compartida se asigna al recinto de
menor área original, antes de seleccionar direcciones y calcular Voronoi. En
caso de igualdad, se prioriza el menor `LAU_CODE` en orden alfabético. Esta
regla se aplica también a solapes entre más de dos recintos. Las correcciones
se registran en `solapes_recintos_<código provincial>.csv`, con los recintos
afectados, sus áreas originales y la superficie transferida. Si un recinto
queda completamente vacío, el proceso se detiene para revisar el caso.

El piloto procesa Ceuta, Burgos, Navarra, Madrid y Tenerife, en ese orden.
La fase `resto` procesa las provincias del manifiesto por número creciente de
municipios y omite las que ya están validadas. Los condominios se incluyen en
el cálculo, pero no en ese recuento de municipios. Para el flujo por lotes se
necesita también el paquete **digest**.

```r
# Desde una terminal en la raíz del proyecto:
# Rscript scripts/reejecutar.R piloto
# Rscript scripts/reejecutar.R resto
# Rscript scripts/reejecutar.R publicar
```

Cada fase puede reanudarse. Una provincia solo se omite si su resultado ya está
validado y conserva su huella. La publicación requiere todas las provincias del
manifiesto validadas y ejecuta las pruebas antes de sustituir los resultados
actuales. El consolidado se genera una vez al finalizar el lote.

Antes de publicar se comprueban las geometrías, la unicidad de los códigos,
la cobertura provincial y los solapamientos. Los informes distinguen los
códigos de la fuente que no aparecen en el resultado e indican si sus puntos
quedan dentro o fuera de la provincia. El progreso se puede consultar en
`data/full_analisis/reejecucion_estado.csv` y las fuentes utilizadas en
`data/full_analisis/reejecucion_manifest.csv`.

Los GeoPackage contienen dos capas: `codigos_postales`, con un registro por CP,
y `pendientes`, con los recintos sin asignación y las diferencias entre el
contorno provincial y los recintos seleccionados. La validación de cobertura
incluye ambas capas; los pendientes no se cuentan como superficie postal
asignada. Los condominios se identifican con `LAU_CODE` y se incorporan mediante
un punto interior calculado con `st_point_on_surface()`.

### Archivos

| Ruta | Contenido |
|----|----|
| `scripts/cp_prov.R` | Generación de la cartografía de una provincia. |
| `scripts/ggplot.R` | Unión de resultados, mapa de avance y exportación de superficies pendientes. |
| `scripts/reejecutar.R` | Reejecución por lotes con respaldo, validación y publicación. |
| `tests/regeneracion.R` | Comprobaciones de geometría, cobertura y consolidación. |
| `scripts/revisar_margenes.R` | Revisión de los códigos próximos a los límites municipales de Cádiz. |
| `data/cartociudad/` | Archivos ZIP de CartoCiudad. |
| `data/provs/` | Resultados provinciales en formato GeoPackage. |
| `data/provs/old/` | Resultados anteriores, excluidos del mapa de avance. |
| `data/codigos_postales.gpkg` | Capas `codigos_postales`, con un registro por CP, y `pendientes`. |
| `data/full_analisis/revision_margenes_11.csv` | Revisión por municipio y código postal de Cádiz. |
| `data/full_analisis/missing.csv` | Superficies pendientes de asignación postal. |
| `data/full_analisis/diagnostico_<código provincial>.csv` | Diagnóstico del filtrado de direcciones por municipio. |
| `data/avance.png` | Mapa de avance del procesamiento. |

## Grado de avance

La generación nacional, actualizada el 26 de octubre de 2026, incluye las 50
provincias y las ciudades autónomas de Ceuta y Melilla. El consolidado contiene
10.851 registros, uno por código postal. Están representados los 10.851 códigos
distintos presentes en las 52 fuentes de CartoCiudad utilizadas: no se ha
perdido ninguno en el resultado nacional. Esta comprobación no sustituye una
comparación con el catálogo oficial completo de Correos.

La publicación superó 797 comprobaciones de geometría, cobertura, unicidad de
códigos, conservación del CP 41760 y reglas de asignación de recintos. La
cobertura se comprueba sumando las capas asignadas y pendientes; no significa
que toda la superficie tenga un código postal.

La revisión de cierre del 26 de octubre superó 803 comprobaciones sobre los
resultados publicados, incluidas las del inventario completo y los EPSG.

Quedan 97 registros pendientes, con 3.881 polígonos separados y 28,0048 km².
De ellos, 46 registros corresponden a recintos sin direcciones seleccionadas
con CP y 51 a diferencias entre los límites provinciales y los recintos.
El [registro de pendientes](PENDIENTES.md) documenta los casos principales y
las comprobaciones necesarias para resolverlos. También están disponibles el
[resumen provincial](data/full_analisis/resumen_pendientes_provincia.csv) y el
[detalle de superficies](data/full_analisis/pendientes_detalle.csv).

La corrección localizada publicada el 26 de octubre excluye los 6,203289 km²
de Gibraltar que incluía el contorno provincial de Cádiz. Incorpora
159,035989 km² mediante intersecciones respaldadas de 34 recintos con un solo
CP observado e identificador administrativo coincidente. Conserva los 10.851
códigos y deja pendientes las franjas residuales y los casos ambiguos.

La propuesta superó 1.021 comprobaciones antes de publicarse. Después de
copiar los archivos se volvió a validar la cobertura de las 52 provincias y
el consolidado. El [informe de corrección](CORRECCION_PENDIENTES.md) documenta
los cambios y el respaldo. La investigación de los 46 recintos, con 246
consultas puntuales al WMS, se conserva como antecedente en
`data/full_analisis/pendientes_priorizacion.csv`.

La [evidencia mínima](data/evidencia_correcciones/README.md) permite comprobar
las asignaciones publicadas sin los ZIP ni los respaldos locales. Las pruebas
se ejecutan desde la raíz con `Rscript tests/ejecutar.R`. Esta verificación
usa los resultados actuales; los logs conservan la validación histórica
completa contra la versión anterior.

Las pruebas de los resultados publicados deben utilizar la base territorial
corregida, que excluye Gibraltar:

```r
Sys.setenv(CP_TEST_BASE = "data/full_analisis/base_admin_publicada.rds")
Sys.setlocale("LC_CTYPE", "Spanish_Spain.utf8") # En Windows
source("tests/regeneracion.R", encoding = "UTF-8")
```

Una nueva generación mediante Voronoi no incorpora automáticamente estas
correcciones posteriores. El lote congelado anterior conserva su trazabilidad;
su fase `publicar` sustituiría los resultados corregidos por los de ese lote.

Los textos de los resultados y los logs se corrigieron mediante reemplazos
mecánicos, sin recalcular las geometrías. Se verificó que los códigos, las
geometrías y los recuentos permanecieran intactos. El respaldo y la auditoría
de esa corrección se conservan en `correccion_textos/` dentro del último lote.

El mapa muestra los resultados publicados en `data/provs/`: las superficies
con código postal en azul y las pendientes de asignación en naranja. Durante
una reejecución, sigue mostrando los resultados anteriores hasta la publicación.

![Cobertura provincial de la cartografía generada.](data/avance.png)

Obra derivada de CartoCiudad CC-BY 4.0 [scne.es](https://www.scne.es/).
