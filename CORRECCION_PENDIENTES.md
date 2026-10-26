# Corrección localizada publicada

Corrección publicada el 26 de octubre de 2026. Se han sustituido los resultados
provinciales afectados, el consolidado, el mapa y los informes de pendientes.
El directorio local indicado en
`data/cartociudad/correccion_pendientes_actual.txt` conserva la validación y el
respaldo de la versión anterior. Esa referencia y los respaldos están
excluidos de Git; la evidencia mínima se incluye en el repositorio.

## Corrección ampliada publicada

Se incorporan 27 recintos adicionales a los siete del ensayo inicial: 34
recintos en total, que amplían la superficie de 30 CP existentes. Se utiliza
solo la intersección respaldada del único CP observado en las muestras,
siempre con identificador administrativo coincidente. Se dejan pendientes
las zonas sin esa intersección y cualquier zona con respaldo contradictorio
de otro código conocido. No se aplica el CP al recinto administrativo entero.

| Indicador | Antes | Publicado ahora |
|---|---:|---:|
| Códigos postales | 10.851 | 10.851 |
| Registros pendientes | 97 | 97 |
| Polígonos pendientes | 3.625 | 3.881 |
| Área pendiente (km²) | 193,244079 | 28,004800 |

Se asignan 159,035989 km² respaldados, además de excluir 6,203289 km² de
Gibraltar. La ampliación superó 1.021 comprobaciones: conservación de códigos,
geometrías no seleccionadas intactas, respaldo espacial de cada ampliación,
residuos conservados, cobertura y solapamientos de las 52 provincias. No se
reejecutó la generación de las provincias.

Los ocho recintos con varios CP y los cuatro sin correspondencia de
identificador administrativo no se corrigen. Permanecen también las franjas
residuales de los 34 recintos tratados y los fragmentos entre límites que
siguen dentro del alcance territorial español.

Se modifican únicamente las provincias 01, 09, 11, 19, 20, 23, 24, 25, 26,
31 y 37. El [detalle de operaciones](data/full_analisis/correcciones_pendientes.csv)
y el [registro de publicación](data/full_analisis/publicacion_correcciones.json)
permiten revisar los cambios. Las huellas de los archivos copiados se
comprobaron contra la propuesta validada. Se conserva el respaldo anterior,
incluida su huella nacional, sin reejecutar la generación provincial.

La [evidencia mínima versionable](data/evidencia_correcciones/README.md)
conserva las entidades WMS, las intersecciones, la exclusión territorial y
los registros de validación. `Rscript tests/ejecutar.R` verifica los resultados
publicados sin acceder al directorio local `data/cartociudad/`. Los respaldos
históricos permanecen fuera de Git.

Para preparar esta modalidad se utiliza `CP_CORRECCION_ALCANCE=monocodigo`.
Sin esa variable, el script conserva la modalidad inicial `piloto`, de siete
recintos. Cada ejecución escribe en un directorio nuevo y conserva respaldo.

## Comparación del ensayo inicial

Este ensayo de siete recintos es un antecedente de la corrección ampliada,
no el estado publicado actual.

| Indicador | Antes del ensayo | Propuesta inicial |
|---|---:|---:|
| Códigos postales | 10.851 | 10.851 |
| Registros pendientes | 97 | 97 |
| Polígonos pendientes | 3.625 | 3.741 |
| Área pendiente (km²) | 193,244079 | 183,760810 |

Se excluyen 6,203289 km² de Gibraltar del alcance territorial español y se
asignan aproximadamente 3,279980 km² a códigos existentes. El recorte genera
más fragmentos residuales, aunque reduce la superficie pendiente. Los siete
recintos conservan un resto sin asignación; no se extiende el CP a todo el
recinto ni se eliminan los fragmentos pequeños por un umbral de superficie.

## Asignaciones del ensayo inicial

| Provincia | LAU_CODE | CP |
|---|---|---|
| Burgos | 53032 | 42140 |
| Burgos | 53039 | 09131 |
| Burgos | 53034 | 09690 |
| Burgos | 53017 | 09692 |
| Burgos | 53015 | 09259 |
| León | 53054 | 24397 |
| Lleida | 53055 | 25723 |

Solo se asigna la intersección del pendiente original con las entidades
consultadas del mismo CP en el WMS oficial. En todos los casos existe una
entidad con identificador administrativo coincidente y la intersección del
CP cubre al menos el 99 % del recinto. Puede haber varias entidades del mismo
CP respaldando distintas partes; se conservan sus referencias y huellas.

La incorporación del CP 42140 a Burgos es intencionada: el resultado final
se agrupa por código postal y no se filtra por su prefijo provincial.
Ese código ya estaba presente en el consolidado nacional.

## Exclusión territorial

Se identifica el componente de `PROV_GAP_11` que contiene el punto interior
36,131722 N, 5,348342 O, en Gibraltar. Solo se excluye ese componente de
6,203289 km². Los restantes fragmentos de Cádiz se mantienen pendientes.

La base administrativa de validación y el mapa publicados utilizan el
contorno de Cádiz ajustado. La base administrativa congelada de la generación
original se conserva sin cambios.

## Validación del ensayo inicial

La propuesta superó 835 comprobaciones, incluidas las 803 de la revisión
general y 32 específicas de esta corrección. Se comprobó que:

- Los 10.851 códigos nacionales se conservan.
- Los códigos no seleccionados mantienen su geometría.
- Cada una de las siete ampliaciones coincide con la intersección respaldada
  y queda dentro del pendiente original.
- El resto de pendientes solo cambia por las siete asignaciones y Gibraltar.
- Las 52 provincias mantienen cobertura, geometrías válidas y ausencia de
  solapamientos relevantes respecto a la base de validación ajustada.
- Los siete recintos mantienen sus residuos sin asignación.

La revisión detectó además geometrías pendientes que quedaban inválidas al
reproyectarse al CRS nacional. La consolidación publicada aplica
`st_make_valid()` también a esa capa. No se recalculó ninguna provincia y
la comparación geométrica no detectó cambios de superficie relevantes fuera
de las correcciones descritas.

## Archivos y reproducibilidad

`scripts/corregir_pendientes.R` preparó la propuesta a partir de los resultados
anteriores a la corrección y la evidencia de la investigación. No sobrescribe
los archivos de entrada: escribe en un directorio nuevo. Requiere la base
congelada, la referencia del lote y las entidades WMS de la investigación
local, que no se incluyen íntegramente en Git. No debe ejecutarse sobre los
resultados ya corregidos para intentar reproducir la publicación original.

`tests/correcciones_pendientes.R` verifica las asignaciones en los resultados
actuales con la evidencia mínima versionada. La comparación completa contra
la versión anterior se conserva en los logs históricos y necesita los
respaldos locales para repetirse.

El directorio local de la corrección conserva:

- `respaldo/`: las 52 provincias y el consolidado anteriores.
- `provs/` y `consolidado/`: los resultados propuestos y el mapa actualizado.
- `base_admin_corregida.rds`: la base de validación territorial ajustada.
- `evidencia/`: las entidades consultadas, sus intersecciones respaldadas y
  la exclusión territorial.
- `analisis/correcciones_pendientes.csv`: áreas transferidas y residuos en la
  proyección provincial, fuentes y huellas de la evidencia.
- `analisis/comparacion_antes_despues.csv`: cifras nacionales comparables en
  ETRS89 / UTM 30N. Las áreas provinciales pueden diferir ligeramente por CRS.
- `verificacion.log` y `PROPUESTA_VALIDADA.json`: resultados de las pruebas
  y huellas del consolidado publicado y del propuesto.

Los ocho casos con varios CP y los cuatro sin correspondencia de
identificador administrativo siguen pendientes. En los 34 recintos tratados,
incluidos los 27 con menor coincidencia de contornos, se incorporaron las
intersecciones respaldadas y se conservaron sus residuos sin asignación.
