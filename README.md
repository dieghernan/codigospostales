# Códigos postales de España

Este proyecto genera una cartografía aproximada de los códigos postales de
España con R, a partir de las direcciones de CartoCiudad y los límites
municipales obtenidos con **mapSpain**. Los resultados se guardan por provincia en
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

1.  Obtiene los límites municipales con `rawcols = TRUE` y los provinciales.
    Identifica los condominios por `t_ua = 4` y utiliza su `id_prov`, contrastado
    con un punto interior calculado con `st_point_on_surface()`. Si ambos
    criterios discrepan, detiene el cálculo. Lee los portales y puntos
    kilométricos de CartoCiudad con código postal.
2.  Divide cada recinto en sus componentes poligonales desconectados, tras
    resolver los solapamientos. Selecciona las direcciones dentro de cada
    componente y aplica un margen interior de 200 metros. Si no quedan
    direcciones, reduce el margen a 50 metros en ese componente. Recupera los
    códigos que solo aparecen en su franja exterior cuando las direcciones
    caen dentro del componente y su código municipal en CartoCiudad coincide
    con el recinto.
3.  Si queda un único CP, lo asigna a todo el componente. Si hay varios,
    genera un Voronoi con sus puntos y lo recorta al componente, conservando
    los huecos interiores. Si no quedan direcciones válidas, deja esa parte
    pendiente; no hereda el CP de otro componente del municipio.
4.  Agrupa los resultados por código postal dentro de cada provincia, conserva
    los huecos interiores para evitar solapamientos y exporta un GeoPackage con
    una capa `codigos_postales` con `COD_POSTAL` y geometría y otra capa
    `pendientes` con las superficies sin asignación. El municipio se utiliza
    únicamente para el cálculo y el diagnóstico.
5.  Une los resultados provinciales y vuelve a agrupar exclusivamente por código
    postal, incluso cuando aparece en varias provincias. Guarda el resultado
    conjunto en `data/codigos_postales.gpkg`.

La publicación incluye además una corrección posterior respaldada por
geometrías del WMS de CartoCiudad: incorpora intersecciones de 34 recintos
sin direcciones y excluye Gibraltar del alcance territorial español. Esta
corrección se documenta en [su informe](CORRECCION_PENDIENTES.md) y no forma
parte del cálculo de Voronoi.

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
raíz del proyecto. La provincia predeterminada es Cádiz. Para utilizar el
alcance territorial publicado, configura `CP_BASE_ADMIN_RDS` con
`data/full_analisis/base_admin_publicada.rds` antes de ejecutar el script.
Este cálculo sustituye el resultado de la provincia y no reaplica las
correcciones posteriores respaldadas por el WMS.

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
El diagnóstico detallado `diagnostico_componentes_<código provincial>.csv`
conserva una fila por componente. El resumen municipal mantiene una fila por
`LAU_CODE`, indica cuántos componentes quedan sin CP y recoge los márgenes
utilizados, separados por punto y coma si difieren entre componentes.
El prefijo provincial del código postal no se utiliza como filtro. Los casos con
coordenadas compartidas por distintos códigos postales detienen el proceso para
evitar una asignación ambigua.

Los diagnósticos nuevos conservan también `id_prov` y `t_ua` de la fuente.
Las bases congeladas anteriores que no contienen esos campos siguen siendo
compatibles: se identifican los condominios por la ausencia de nombre y se
asignan mediante el punto interior. En ese caso, los campos originales quedan
vacíos; no se completan con datos de otra versión. Los diagnósticos de la
regeneración nacional actual incluyen ambos campos de la fuente.

El cálculo utiliza ETRS89 / UTM 29N en A Coruña, Badajoz, Cáceres, Huelva,
Lugo, Ourense, Pontevedra y Salamanca. Utiliza ETRS89 / UTM 31N en Baleares,
Barcelona, Girona, Lleida y Tarragona y ETRS89 / UTM 30N en el resto de la
península, Ceuta y Melilla. En Canarias utiliza REGCAN95 / UTM 28N.
Los resultados provinciales conservan esa proyección; el archivo conjunto se
transforma a ETRS89 / UTM 30N.

Para Baleares y Álava, los nombres de los ZIP del CNIG son
`CARTOCIUDAD_CALLEJERO_BALEARES.zip` y `CARTOCIUDAD_CALLEJERO_ALAVA.zip`.

Para actualizar el resultado conjunto, el mapa y el CSV a partir de los
GeoPackage existentes, utiliza también la base administrativa corregida
mediante `CP_BASE_ADMIN_RDS`. Sin esa variable, el fondo del mapa se obtiene
de los límites de **mapSpain** y puede volver a mostrar Gibraltar como parte
del contorno de Cádiz. La consolidación no actualiza automáticamente las
tablas de detalle y resumen provincial de pendientes.

``` r
source("scripts/ggplot.R")
```

## Estructura

### Reejecución por lotes

`scripts/reejecutar.R` utiliza el directorio indicado en
`data/cartociudad/reejecucion_actual.txt`. Allí conserva el respaldo, el
manifiesto de fuentes con huellas SHA-256, las copias del método y de las capas
administrativas, los registros y los resultados provisionales.

Ese directorio y el archivo que lo señala son locales y están excluidos de
Git. El script necesita que exista esa referencia; un clon del repositorio
no incluye un lote preparado ni los ZIP originales. Los comandos siguientes
describen las fases de un lote local ya configurado.

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
| `scripts/recintos.R` | Identificación de condominios y contraste de su provincia original con el punto interior. |
| `scripts/ggplot.R` | Unión de resultados, mapa de avance y exportación de superficies pendientes. |
| `scripts/reejecutar.R` | Reejecución por lotes con respaldo, validación y publicación. |
| `scripts/reaplicar_correcciones.R` | Reaplicación de la evidencia WMS local sobre los pendientes de un lote provisional. |
| `tests/regeneracion.R` | Comprobaciones de geometría, cobertura y consolidación. |
| `scripts/revisar_margenes.R` | Revisión de los códigos próximos a los límites municipales de Cádiz. |
| `data/cartociudad/` | Fuentes, lotes y respaldos locales, excluidos de Git. |
| `data/provs/` | Resultados provinciales en formato GeoPackage. |
| `data/evidencia_correcciones/` | Evidencia mínima y registros de validación de las correcciones publicadas. |
| `data/full_analisis/base_admin_publicada.rds` | Base administrativa de validación con el alcance territorial corregido. |
| `tests/ejecutar.R` | Verificación de los resultados publicados sin las fuentes locales. |
| `data/codigos_postales.gpkg` | Capas `codigos_postales`, con un registro por CP, y `pendientes`. |
| `data/full_analisis/revision_margenes_11.csv` | Revisión por municipio y código postal de Cádiz. |
| `data/full_analisis/missing.csv` | Superficies pendientes de asignación postal. |
| `data/full_analisis/diagnostico_<código provincial>.csv` | Diagnóstico del filtrado de direcciones por municipio. |
| `data/full_analisis/diagnostico_componentes_<código provincial>.csv` | Diagnóstico por componente generado por el método actualizado. |
| `data/avance.png` | Mapa de avance del procesamiento. |

## Grado de avance

La generación nacional, actualizada el 26 de octubre de 2026, incluye las 50
provincias y las ciudades autónomas de Ceuta y Melilla. El consolidado contiene
10.851 registros, uno por código postal. Están representados los 10.851 códigos
distintos presentes en las 52 fuentes de CartoCiudad utilizadas: no se ha
perdido ninguno en el resultado nacional. Esta comprobación no sustituye una
comparación con el catálogo oficial completo de Correos.

La publicación inicial del 25 de octubre superó 797 comprobaciones de
geometría, cobertura, unicidad de códigos, conservación del CP 41760 y reglas
de asignación de recintos. La
cobertura se comprueba sumando las capas asignadas y pendientes; no significa
que toda la superficie tenga un código postal.

La revisión de cierre anterior a la corrección localizada superó 803
comprobaciones, incluidas las del inventario completo y los EPSG. Estas
cifras corresponden a validaciones históricas; la corrección posterior y sus
pruebas se describen a continuación.

Quedan 304 registros pendientes, con 4.108 polígonos separados y
1.011,539168 km². De ellos, 253 registros corresponden a recintos con algún
componente sin direcciones seleccionadas con CP y 51 a diferencias entre los
límites provinciales y los recintos. Antes del cálculo por componentes quedaban
28,004800 km²: el aumento identifica superficies que antes heredaban el CP de
otra parte desconectada del municipio, sin direcciones propias que lo apoyaran.
El [registro de pendientes](PENDIENTES.md) documenta los casos principales y
las comprobaciones necesarias para resolverlos. También están disponibles el
[resumen provincial](data/full_analisis/resumen_pendientes_provincia.csv) y el
[detalle de superficies](data/full_analisis/pendientes_detalle.csv).

La corrección localizada original del 26 de octubre excluyó los 6,203289 km²
de Gibraltar que incluía el contorno provincial de Cádiz. Incorporó
159,035989 km² mediante intersecciones respaldadas de 34 recintos con un solo
CP observado e identificador administrativo coincidente. Conservó los 10.851
códigos y dejó pendientes las franjas residuales y los casos ambiguos. La
regeneración actual conserva la exclusión y reaplica las 34 intersecciones
validadas sobre los nuevos pendientes, sin realizar consultas WMS nuevas.

Aquella propuesta superó 1.021 comprobaciones antes de publicarse. Después de
copiar los archivos se superaron otras 790 comprobaciones de las 52 provincias
y el consolidado. El [informe de corrección](CORRECCION_PENDIENTES.md) documenta
los cambios y el respaldo. La investigación de los 46 recintos, con 246
consultas puntuales al WMS, se conserva como antecedente en
`data/full_analisis/pendientes_priorizacion.csv`.

La [evidencia mínima](data/evidencia_correcciones/README.md) permite comprobar
las asignaciones publicadas sin los ZIP ni los respaldos locales. Las pruebas
se ejecutan desde la raíz con `Rscript tests/ejecutar.R`. Esta verificación
usa los resultados actuales; los logs conservan la validación histórica
completa contra la versión anterior.

Las pruebas de los resultados publicados utilizan por defecto la base
territorial corregida, que excluye Gibraltar. `CP_TEST_BASE` permite elegir
explícitamente esa base u otra para una ejecución distinta:

```r
Sys.setenv(CP_TEST_BASE = "data/full_analisis/base_admin_publicada.rds")
Sys.setlocale("LC_CTYPE", "Spanish_Spain.utf8") # En Windows
source("tests/regeneracion.R", encoding = "UTF-8")
```

Una nueva generación mediante Voronoi no incorpora automáticamente estas
correcciones posteriores. `scripts/reaplicar_correcciones.R` permite recuperar
la evidencia validada sobre los pendientes de un lote provisional mediante
`CP_REAPLICACION_DIR`. Requiere `GENERACION_VALIDADA.txt`, conserva los resultados
brutos y detiene la operación ante conflictos de superficie de al menos 1 m².
No admite modificar un lote marcado como publicado. Esta fase debe preceder
a la consolidación y a la validación final del lote que se vaya a publicar.

La regeneración nacional publicada procesa por separado los componentes
desconectados de las 52 provincias y ciudades autónomas. Corrige la influencia
de puntos de una parte del municipio sobre otra, detectada en Alegría-Dulantzi.
No modifica la resolución de los límites administrativos de partida. El
[registro de publicación](data/full_analisis/regeneracion_componentes_publicada.json)
y la [comparación provincial](data/full_analisis/comparacion_componentes_provincia.csv)
documentan el resultado y los cambios.
La propuesta superó 1.096 comprobaciones completas antes de publicarse y
otras 1.096 sobre los archivos publicados. Se comprobaron también las
huellas SHA-256 de los 52 GeoPackage provinciales, el consolidado, el mapa y
la base administrativa.

El contraste provincial con geometrías del WMS se realiza solo a petición,
fuera del flujo automático y de las pruebas habituales. La revisión de Navarra
detectó limitaciones en Petilla de Aragón y Piedramillera que se conservan en
el [registro de pendientes](PENDIENTES.md), sin excepciones nuevas al método.

Los textos de los resultados y los logs se corrigieron mediante reemplazos
mecánicos, sin recalcular las geometrías. Se verificó que los códigos, las
geometrías y los recuentos permanecieran intactos. El respaldo y la auditoría
de esa corrección se conservan en `correccion_textos/` dentro del lote anterior.

El mapa muestra los resultados publicados en `data/provs/`: las superficies
con código postal en azul y las pendientes de asignación en naranja. Durante
una reejecución, sigue mostrando los resultados anteriores hasta la publicación.

![Cobertura provincial de la cartografía generada.](data/avance.png)

Obra derivada de CartoCiudad CC-BY 4.0 [scne.es](https://www.scne.es/).
