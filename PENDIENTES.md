# Superficies pendientes de asignación postal

Estado revisado el 26 de octubre de 2026. La generación nacional está publicada
y representa todos los códigos presentes en las fuentes utilizadas. Este
registro recoge las superficies que aún no tienen una asignación postal.

## Alcance

La capa `pendientes` de `data/codigos_postales.gpkg` contiene 97 registros,
3.881 polígonos separados y 28,0048 km². Un registro puede contener varios
polígonos y no equivale a un municipio ni a un código postal perdido.

La corrección publicada el 26 de octubre excluyó 6,203289 km² de Gibraltar
del alcance territorial e incorporó 159,035989 km² respaldados a 30 CP en
34 recintos. Todos conservan una superficie residual pendiente. Los ocho
recintos con varios CP observados y los cuatro sin coincidencia de
identificador administrativo mantienen su geometría anterior.

| Motivo | Registros | Polígonos | Área (km²) |
|---|---:|---:|---:|
| Sin direcciones seleccionadas con código postal | 46 | 196 | 27,927240 |
| Superficie provincial fuera de los recintos seleccionados | 51 | 3685 | 0,077560 |
| Total | 97 | 3.881 | 28,004800 |

Las áreas se calculan en la proyección del consolidado, ETRS89 / UTM 30N.
El [detalle por registro](data/full_analisis/pendientes_detalle.csv) conserva
`cpro`, `LAU_CODE`, motivo, provincia, área y número de polígonos. El
[resumen provincial](data/full_analisis/resumen_pendientes_provincia.csv)
incluye las 52 provincias y ciudades autónomas.

## Casos prioritarios

Estos son los registros de mayor superficie después de la corrección.
Los identificadores pertenecen a la base administrativa congelada del lote.

| Provincia | LAU_CODE | Área pendiente (km²) |
|---|---|---:|
| Huesca | 53049 | 10,116849 |
| Navarra | 53060 | 2,419543 |
| Burgos | 53007 | 2,327531 |
| Gipuzkoa | 53048 | 2,289663 |
| Navarra | 53066 | 1,379581 |
| Navarra | 53067 | 1,054872 |
| Guadalajara | 53047 | 0,795935 |
| Burgos | 53012 | 0,649861 |
| Burgos | 53035 | 0,640126 |
| Burgos | 53043 | 0,608028 |

Se comprobaron los 46 recintos sin direcciones mediante sus 13 ZIP provinciales
originales. La investigación ampliada siguiente distingue los resultados de
las consultas puntuales iniciales y los del contraste multipunto posterior.

## Investigación adicional del 26 de octubre

Los apartados de investigación siguientes documentan las mediciones previas
a la corrección. El alcance y la tabla anteriores reflejan el estado actual.

Se seleccionaron siete condominios grandes y la diferencia de límites de
Cádiz. En los siete condominios no hay ningún portal ni punto kilométrico
interior en el ZIP provincial original, sin aplicar filtros ni márgenes.
También se revisaron Navarra para el recinto 53048 y Albacete y Ciudad Real
para el 53050: tampoco aportan puntos interiores.

Se consultó el punto interior de cada recinto mediante `GetFeatureInfo` en
la capa `codigo-postal` del
[WMS oficial de CartoCiudad](https://www.cartociudad.es/wms-inspire/direcciones-ccpp?service=WMS&request=GetCapabilities).
En los siete casos devolvió un CP y un `ine_mun` coincidente con el
`LAU_CODE`. Se midió la intersección de la geometría devuelta con el recinto
pendiente en la misma proyección del consolidado. Los nombres se contrastaron
con la [relación de Goerlich](https://www.uv.es/goerlich/Ivie/LAU2boundaries4Spain.html).

| Recinto | Provincia | LAU_CODE | CP consultado | Cobertura del recinto por la geometría devuelta |
|---|---|---|---|---:|
| Mancomunidad de Amezketa y Ordizia | Gipuzkoa | 53048 | 20268 | 93,61 % |
| Comunidad de la Sierra Brava de Badaya | Álava | 53001 | 01439 | 97,62 % |
| Mancomunidad de Nalda, Sorzano y Viguera | La Rioja | 53056 | 26121 | 97,11 % |
| Comunidad de Barbadillo del Pez y Jaramillo de la Fuente | Burgos | 53013 | 09614 | 95,69 % |
| Comunero de Ansó y Hecho | Huesca | 53049 | 22728 | 90,65 % |
| Comunidad del Valle de Salazar | Navarra | 53067 | 31691 | 87,11 % |
| Cuarto del Madroño | Jaén | 53050 | 23393 | 92,01 % |

Son candidatos respaldados por la consulta oficial, no asignaciones ya
incorporadas. La cobertura incompleta muestra diferencias entre el contorno
postal devuelto y el administrativo. Debe revisarse el resto de cada recinto
y comprobar si existen otros sectores antes de atribuir un único CP a toda
su superficie. La dirección postal de la sede de una mancomunidad no equivale
necesariamente al código postal de sus terrenos.

Las consultas y propiedades devueltas se guardan en
`data/full_analisis/investigacion_pendientes_wms.json`; las mediciones, en
`data/full_analisis/investigacion_pendientes_cobertura_wms.csv`. Los recuentos
de puntos y el contraste con provincias vecinas están en los CSV
`investigacion_pendientes_casos.csv` e
`investigacion_pendientes_fuentes_vecinas.csv` del mismo directorio.

### Cádiz: incidencia de alcance territorial

Antes de la corrección, `PROV_GAP_11` contenía 60 polígonos y 6,204121 km². Uno suma 6,203289 km²,
el 99,9866 % del área, y tiene un punto interior en 36,131722 N, 5,348342 O,
en Gibraltar. Los otros 59 fragmentos suman unos 832 m². Ningún punto del
ZIP provincial cae dentro del conjunto pendiente.

Las coordenadas se contrastaron con el
[geoportal oficial de Gibraltar](https://www.geoportal.gov.gi/index.php).
Goerlich también documenta la aparición de Gibraltar, territorio 54006, en
la BDLL separado de las provincias españolas. Nuestra base municipal no
contiene recintos 54, mientras que el contorno provincial de Cádiz utilizado
sí abarca la zona identificada.

La publicación excluyó esa superficie del alcance postal español y ajustó
la validación territorial de Cádiz. Los otros 59 fragmentos siguen pendientes.

## Ampliación a todos los recintos sin direcciones

La revisión cubre los 46 registros y sus 47 polígonos, con 186,963514 km².
Se releen los puntos originales de los 13 ZIP provinciales correspondientes,
sin filtrar CP ni aplicar márgenes: ninguno contiene puntos interiores a los
recintos pendientes que le corresponden. Esto confirma la ausencia de datos
en esas fuentes provinciales, no necesariamente en cualquier otra fuente.

Se generaron 234 puntos interiores deterministas: un punto por componente y
puntos en sus intersecciones con una cuadrícula de cuatro celdas. Se añadieron
12 puntos dirigidos a sectores donde las geometrías consultadas indicaban
posibles CP adicionales. Las 246 consultas al WMS terminaron sin errores y
todos los puntos quedan cubiertos por alguna geometría postal consultada.
Este muestreo no demuestra por sí solo que un recinto completo tenga un CP.

| Clasificación de revisión | Recintos |
|---|---:|
| Un CP observado, identificador coincidente y cobertura geométrica ≥99 % | 7 |
| Varios CP confirmados en puntos del recinto utilizado | 8 |
| Sin correspondencia de identificador administrativo en las geometrías consultadas | 4 |
| Un CP observado; revisar las diferencias de contorno | 27 |

Las geometrías devueltas intersectan 178,661566 km² de los recintos. Quedan
8,301948 km² sin esa intersección. Esta diferencia puede reflejar cambios o
diferencias de contorno y sectores aún no consultados: no debe rellenarse
automáticamente ni darse por completamente investigada por el muestreo.
Todos los códigos observados ya existen en el consolidado nacional.

### Recintos con varios códigos observados

| Provincia | LAU_CODE | CP observados |
|---|---|---|
| Huesca | 53049 | 22728; 22790 |
| Navarra | 53060 | 31241; 31263 |
| Navarra | 53066 | 31241; 31263 |
| Burgos | 53035 | 09194; 09646 |
| Burgos | 53043 | 09194; 09646 |
| Madrid | 53058 | 28411; 28412 |
| Teruel | 53077 | 44742; 44793 |
| León | 53053 | 24763; 24768 |

Los sectores secundarios consultados llevan identificadores de otros recintos
en el WMS. Por tanto, también debe comprobarse la correspondencia de límites
entre ambas fuentes antes de interpretar estos resultados como una división
postal interna del mismo recinto administrativo.

Los cuatro casos sin coincidencia de identificador son 53007, 53012 y 53028,
en Burgos, asociados al CP 09613 y al identificador 53036 del WMS, y 53070,
en Navarra, asociado al CP 31243 y al identificador 53083 del WMS. Se requiere
una revisión de esa correspondencia; no se deduce una equivalencia de códigos.

### Candidatos con mayor coincidencia geométrica

| Provincia | LAU_CODE | CP observado | Cobertura geométrica |
|---|---|---|---:|
| Burgos | 53032 | 42140 | 99,41 % |
| Burgos | 53039 | 09131 | 99,98 % |
| León | 53054 | 24397 | 99,84 % |
| Burgos | 53034 | 09690 | 99,54 % |
| Burgos | 53017 | 09692 | 99,55 % |
| Burgos | 53015 | 09259 | 99,98 % |
| Lleida | 53055 | 25723 | 99,99985 % |

Estos siete candidatos se incorporaron a la corrección localizada publicada
mediante su intersección respaldada, conservando los residuos. La etiqueta de provincia sigue siendo diagnóstica: el CP 42140
no se descarta por aparecer en un recinto procesado con Burgos.

En Aldovera, los cinco puntos consultados devuelven 19119 y la geometría
consultada cubre el 98,25 % del recinto, unos 44,79 km². Esto mejora la
evidencia inicial basada en un único portal exterior con CP 19118, pero aún
deja unos 0,80 km² que requieren contraste de contornos.

### Fragmentos entre límites

Descontando el polígono de Gibraltar, quedan 3.577 fragmentos de diferencia
entre límites que suman 77.275,85 m², unos 0,077276 km². De ellos, 1.258
tienen menos de 1 m²; 2.173 tienen entre 1 y 100 m²; 139 tienen entre 100 y
1.000 m² y 7 superan los 1.000 m². El mayor de estos últimos está en Granada
y suma unos 3.439 m²; el siguiente está en Zaragoza y suma unos 3.234 m².

Esta distribución apoya revisar los pequeños fragmentos como incidencias de
ajuste de límites antes de tratarlos como zonas postales independientes. No
se ha asignado ningún CP ni se ha eliminado superficie durante el análisis.

### Archivos de la ampliación

- [Resumen por recinto](data/full_analisis/pendientes_analisis_ampliado.csv).
- [Prioridades de revisión](data/full_analisis/pendientes_priorizacion.csv).
- [Intersecciones con las geometrías consultadas](data/full_analisis/pendientes_intersecciones_wms.csv).
- [Códigos observados en cada punto](data/full_analisis/pendientes_consultas_multipunto.csv).
- [Resumen de comprobaciones](data/full_analisis/pendientes_analisis_ampliado_resumen.json).

Las consultas, respuestas originales y scripts de investigación quedan en
`data/cartociudad/analisis_pendientes_ampliado/`. La publicación posterior
incorpora únicamente las intersecciones justificadas de los 34 recintos
seleccionados. La nueva huella del consolidado queda registrada en
`data/full_analisis/publicacion_correcciones.json`.

## Aldovera, Guadalajara

El recinto `53047` se identifica como Aldovera en la
[documentación de Goerlich sobre contornos municipales](https://www.uv.es/goerlich/Ivie/LAU2boundaries4Spain.html).
Se sitúa entre Albalate de Zorita, Almoguera, Almonacid de Zorita e Illana.

Se comprobó el ZIP de Guadalajara directamente: ninguno de sus 225.663
portales y puntos kilométricos cae dentro del recinto, incluso sin filtrar
códigos postales ni aplicar márgenes interiores. Este caso no lo provocan
los márgenes de 200 y 50 metros ni la teselación de Voronoi.

En una franja exterior de 500 metros aparece un punto con CP 19118. Esa
proximidad no demuestra que el código corresponda a todo el condominio.
El resto del pendiente provincial son 82 fragmentos que suman unos 1.669 m².

## Criterios para resolver los pendientes

1. Identificar cada recinto por su geometría y `LAU_CODE` de la base congelada.
2. Comprobar las direcciones originales sin filtros para distinguir ausencia
   de datos, datos sin CP y posibles efectos de los márgenes.
3. Contrastar la asignación con otra fuente postal o una delimitación externa.
   Registrar la fuente, la fecha y la justificación de cualquier corrección.
4. Revisar las diferencias entre límites antes de atribuirles un CP; un hueco
   geométrico no demuestra por sí solo una asignación postal.
5. Aplicar únicamente las correcciones justificadas y validar de nuevo la
   cobertura, los solapamientos y la conservación de los códigos afectados.

Los recintos administrativos y los municipios son unidades de cálculo y
diagnóstico. El resultado postal sigue agrupándose exclusivamente por
`COD_POSTAL`, incluso cuando un código abarca varios municipios o provincias.

## Incidencias resueltas

- El solapamiento de 8.488,16 m² entre Forcarei y Cerdedo-Cotobade se asignó a
  Forcarei, el recinto de menor área original. La regla está incorporada al
  método y deja una auditoría por provincia.
- Se corrigieron los textos dañados de CSV, logs y GeoPackage mediante
  reemplazos mecánicos. La comprobación fila a fila conservó las geometrías,
  los códigos y los recuentos; no se reejecutó el lote por esta corrección.
- Los 48 casos de códigos ausentes de un resultado provincial tienen sus
  puntos fuera del límite de esa provincia. Todos están representados en el
  consolidado nacional a través de otra provincia.

## Trazabilidad

El directorio indicado en `data/cartociudad/reejecucion_actual.txt` conserva
el manifiesto, las capas administrativas, el método congelado, los estados,
los logs, el origen de los resultados reutilizados y las auditorías. Las
fuentes, los respaldos y los diagnósticos históricos se mantienen fuera del
resultado postal publicado.

La falta de códigos respecto a las fuentes es cero. Sigue pendiente una
comparación independiente con el catálogo oficial completo de Correos y la
resolución de las superficies anteriores con evidencia postal adicional.
