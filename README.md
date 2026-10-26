# Códigos Postales de España

El producto final es `data/codigos_postales.gpkg`, con la capa
`codigos_postales`: una fila por código postal y sus superficies disueltas,
incluidas las que pertenecen a distintas provincias. Un código puede tener
varias superficies separadas. El municipio no forma parte del producto final.

Son delimitaciones estimadas a partir de direcciones de CartoCiudad y recintos
administrativos, no límites postales oficiales. El consolidado cubre únicamente
las provincias generadas que estén presentes en `data/provs/`.

## Metodología

El proyecto se basa en
[«Elaboración de un mapa de Códigos Postales de España con recursos libres»,
de Francisco Goerlich](https://www.uv.es/goerlich/Ivie/CodPost.html), y en
[«Así hice el mapa de los códigos postales de España con SIG y datos abiertos»,
de José Ignacio Sánchez, en NoSoloSIG](https://www.nosolosig.com/articulos/asi-hice-el-mapa-de-los-codigos-postales-de-espana-con-sig-y-datos-abiertos).

La idea común es construir áreas de influencia de las direcciones de
CartoCiudad mediante una teselación de Voronoi, ajustarlas a los recintos
administrativos y disolverlas por código postal. De Goerlich se toma el
tratamiento independiente de cada componente del municipio y la asignación
directa del recinto cuando sus direcciones seleccionadas tienen un solo CP.

Esta implementación tiene decisiones propias: usa márgenes interiores de
200 y 50 m, frente a los 20 m descritos por Goerlich, y conserva sin asignar los
recintos sin direcciones seleccionadas, salvo que el municipio tenga un único
CP recuperado en sus otros componentes. No se completan por proximidad.
La salida se consolida por CP entre provincias. El procedimiento no garantiza
la coincidencia con los límites postales oficiales ni la inclusión de todos
los CP presentes en las direcciones originales, pues el filtrado por márgenes
puede excluirlos.

## Generación

Desde la raíz del proyecto, con los paquetes `sf`, `dplyr`, `ggplot2`,
`mapSpain` y `readr` instalados:

```r
Sys.setenv(CP_PROVINCIA = "SEGOVIA")
source("scripts/cp_prov.R")
```

Las entradas se guardan en `data/cartociudad/`, ignorada por Git:
`LAU2boundaries4Spain.gpkg`, de
[Goerlich](https://zenodo.org/records/15345101), y el ZIP provincial de
CartoCiudad, por ejemplo `CARTOCIUDAD_CALLEJERO_SEGOVIA.zip`.

El script procesa cada componente del recinto administrativo. Selecciona
direcciones dentro de un margen interior de 200 m, con un segundo intento de
50 m si no encuentra ninguna. Con un solo CP asigna el recinto completo; con
varios utiliza polígonos de Voronoi recortados al recinto. Si no encuentra
direcciones, deja el recinto sin CP.

Al terminar todos los componentes del municipio, si solo se ha recuperado un
CP distinto, ese código se asigna también a sus componentes pendientes. Si se
han recuperado varios CP o ninguno, los pendientes se conservan sin asignar.

Los cálculos usan el huso UTM del punto interior representativo de la provincia:
ETRS89 / UTM 29, 30 o 31 en la península y Baleares, y REGCAN95 / UTM 28 en
Canarias. Se utiliza `st_point_on_surface()` para que ese punto quede dentro
del recinto. Los recintos administrativos y el fondo provincial proceden del
mismo archivo de Goerlich.
La lectura SQL selecciona únicamente la provincia solicitada y los campos
necesarios, sin cargar todos los municipios de España en memoria.

Tras separar los componentes, los solapes administrativos se asignan al
recinto original de menor superficie. En un empate se conserva el primero en
el archivo de entrada. No se aplican tolerancias para cerrar huecos.

Cada ejecución guarda el resultado intermedio en `data/provs/CP_XX.gpkg` y
ejecuta `scripts/consolidado.R`. Este reúne todos los resultados provinciales,
los transforma a EPSG:25830 y disuelve las superficies por `COD_POSTAL`, sin
restringir los códigos por su prefijo provincial. Así actualiza el producto
final `data/codigos_postales.gpkg`. Los registros sin CP quedan excluidos del
consolidado postal y se conservan con geometría en la capa `pendientes` del
mismo GeoPackage, con provincia de origen y área en metros cuadrados, medida
en la proyección del resultado provincial. Sus
atributos se exportan a `data/full_analisis/missing.csv`. Las nuevas ejecuciones
provinciales también guardan una capa `pendientes` antes de disolver por CP;
para resultados antiguos se recupera la geometría sin CP disponible.

Ambas capas del producto final contienen únicamente geometrías
`MULTIPOLYGON`. Los CP se conservan como texto de cinco dígitos, incluidos los
ceros iniciales. La ejecución provincial fija una configuración UTF-8 en
Windows. Estas mejoras se aplican al regenerar cada provincia; consolidar
resultados antiguos no repite su asignación postal ni resuelve sus solapes
administrativos de origen.

La consolidación elimina anillos interiores de hasta 1 mm² que no contienen
superficie de otro CP ni de un pendiente. Conserva los enclaves, los agujeros
mayores y todos los contornos exteriores; no simplifica ni desplaza vértices.
La detección usa el área del anillo con coordenadas trasladadas al origen para
evitar cancelaciones numéricas. Esta limpieza no asigna los recintos pendientes.

Para reconstruir únicamente el consolidado y el mapa, sin regenerar provincias:

```r
source("scripts/consolidado.R")
```

## Grado de avance

![](data/avance.png)
