# Superficies pendientes de asignación postal

Estado revisado el 26 de octubre de 2026. La generación nacional está publicada
y representa todos los códigos presentes en las fuentes utilizadas. Este
registro recoge las superficies que aún no tienen una asignación postal.

## Alcance

La capa `pendientes` de `data/codigos_postales.gpkg` contiene 304 registros,
5.310 polígonos separados y 155,887315 km². Un registro puede contener varios
polígonos y no equivale a un municipio ni a un código postal perdido.

La corrección publicada el 26 de octubre excluyó 6,203289 km² de Gibraltar
del alcance territorial e incorporó 159,035989 km² respaldados a 30 CP en
34 recintos. Todos conservan una superficie residual pendiente. Los ocho
recintos con varios CP observados y los cuatro sin coincidencia de
identificador administrativo no recibieron una corrección localizada.
La regeneración por componentes conserva esa evidencia y deja sin asignar
cualquier parte desconectada sin direcciones propias. Esto aumenta la
superficie pendiente hasta 1.011,539168 km² respecto a los 28,004800 km² de la
publicación anterior. La corrección posterior aprobada incorpora 191
asignaciones de 189 recintos, conserva los residuos y reduce el pendiente
a los 155,887315 km² actuales. No se recalculó el Voronoi.

| Motivo | Registros | Polígonos | Área (km²) |
|---|---:|---:|---:|
| Sin direcciones seleccionadas con código postal | 253 | 1.630 | 155,809785 |
| Superficie provincial fuera de los recintos seleccionados | 51 | 3.680 | 0,077530 |
| Total | 304 | 5.310 | 155,887315 |

Las áreas se calculan en la proyección del consolidado, ETRS89 / UTM 30N.
El [detalle por registro](data/full_analisis/pendientes_detalle.csv) conserva
`cpro`, `LAU_CODE`, motivo, provincia, área y número de polígonos. El
[resumen provincial](data/full_analisis/resumen_pendientes_provincia.csv)
incluye las 52 provincias y ciudades autónomas.

## Casos prioritarios

Estos son los registros de mayor superficie después de la regeneración.
Los identificadores pertenecen a la base administrativa congelada del lote.

| Provincia | LAU_CODE | Área pendiente (km²) |
|---|---|---:|
| Badajoz | 06160 | 15,365283 |
| Las Palmas | 35024 | 11,845446 |
| Badajoz | 06034 | 10,953698 |
| Badajoz | 06134 | 10,709397 |
| Teruel | 44266 | 6,531379 |
| Zaragoza | 50026 | 5,381690 |
| Pontevedra | 36057 | 4,478947 |
| Teruel | 44063 | 3,897024 |
| Teruel | 44009 | 3,444076 |
| Toledo | 45145 | 3,308063 |

En la investigación anterior se comprobaron los 46 recintos sin direcciones
mediante sus 13 ZIP provinciales originales. La investigación siguiente
distingue los resultados de
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

Esta consulta inicial aportó candidatos para el contraste multipunto
posterior. Seis de estos siete recintos recibieron después una asignación
parcial respaldada; el recinto 53049 de Huesca sigue sin corregirse porque
se observaron varios CP. La cobertura incompleta muestra diferencias entre
el contorno postal devuelto y el administrativo. La dirección postal de la
sede de una mancomunidad no equivale necesariamente al CP de sus terrenos.

Las consultas y propiedades devueltas se guardan en
`data/full_analisis/investigacion_pendientes_wms.json`; las mediciones, en
`data/full_analisis/investigacion_pendientes_cobertura_wms.csv`. Los recuentos
de puntos y el contraste con provincias vecinas están en los CSV
`investigacion_pendientes_casos.csv` e
`investigacion_pendientes_fuentes_vecinas.csv` del mismo directorio.

### Cádiz: incidencia de alcance territorial

Antes de la corrección, `PROV_GAP_11` contenía 60 polígonos y 6,204121 km².
Uno sumaba 6,203289 km², el 99,9866 % del área, y tenía un punto interior
en 36,131722 N, 5,348342 O,
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

La revisión previa cubrió los 46 registros y sus 47 polígonos originales,
con 186,963514 km². Se releyeron los puntos de los 13 ZIP correspondientes,
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
mediante su intersección respaldada, conservando los residuos. La etiqueta
de provincia sigue siendo diagnóstica: el CP 42140 no se descarta por aparecer
en un recinto procesado con Burgos.

En Aldovera, los cinco puntos consultados devuelven 19119 y la geometría
consultada cubre el 98,25 % del recinto, unos 44,79 km². Esto mejora la
evidencia inicial basada en un único portal exterior con CP 19118, pero aún
deja unos 0,80 km² que requieren contraste de contornos.

### Fragmentos entre límites

En el análisis previo, al descontar el polígono de Gibraltar se identificaron
3.577 fragmentos de diferencia entre límites que sumaban 77.275,85 m²,
unos 0,077276 km². De ellos, 1.258
tienen menos de 1 m²; 2.173 tienen entre 1 y 100 m²; 139 tienen entre 100 y
1.000 m² y 7 superan los 1.000 m². El mayor de estos últimos está en Granada
y suma unos 3.439 m²; el siguiente está en Zaragoza y suma unos 3.234 m².

Esta distribución apoya revisar los pequeños fragmentos como incidencias de
ajuste de límites antes de tratarlos como zonas postales independientes. No
se asignó ningún CP ni se eliminó superficie durante ese análisis. La
consolidación posterior también reparó las geometrías pendientes al
reproyectarlas. Tras aquella corrección quedaron 3.685 componentes y
0,077560 km². La regeneración por componentes actual deja 3.680 polígonos y
0,077530 km² para este motivo, como recoge la tabla de alcance.

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
La publicación incorporó la intersección respaldada del CP 19119 y dejó
0,795935 km² pendientes en Aldovera. El otro registro pendiente provincial
contiene 82 fragmentos que suman unos 1.669 m².

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

## Incidencia de asignación en Alegría-Dulantzi

La revisión posterior detectó que el cálculo conjunto de las partes
desconectadas de 01001 extendía el CP 01193 de Egileta a 1,829509 km² de la
parte principal de Alegría-Dulantzi. Todos los puntos seleccionados de esa
parte principal llevan 01240. La consulta WMS respalda 01240 en 1,696689 km²
del sector; la diferencia restante refleja desacuerdos de contorno.

El método actualizado procesa los componentes por separado y deja pendiente
cualquier componente sin direcciones válidas. Tras probarse en Álava, Segovia,
Navarra y Burgos, se ha aplicado a las 52 provincias y ciudades autónomas de
la cartografía publicada. La incidencia afecta a una asignación existente y
no añade un registro a la capa `pendientes`. La diferencia entre el límite
administrativo simplificado y el límite detallado del IGN requiere una
revisión independiente.

## Revisión manual de los pendientes anterior a la corrección

Tras la publicación por componentes se revisaron los 304 registros y sus
4.108 componentes mediante 5.186 consultas WMS, sin errores. Se consultó un
punto interior por componente y una malla adicional de 1 km en componentes
mayores de 0,1 km². Se reutilizaron también las entidades de las revisiones
anteriores del mismo día. Esta investigación preparó los candidatos de la
corrección posterior aprobada. No incorpora consultas al flujo de generación
ni a las pruebas.

| Clasificación | Componentes | Área pendiente (km²) | Intersección con INE coincidente (km²) |
|---|---:|---:|---:|
| Un CP con INE coincidente; candidato a revisión | 204 | 805,228169 | 754,344664 |
| Respaldo con solape entre CP | 15 | 109,349376 | 102,301369 |
| Solo respaldo de otro INE | 178 | 76,140942 | 0,000000 |
| Sin respaldo WMS recuperado | 19 | 20,743150 | 0,000000 |
| Diferencias de límites de al menos 1 m² | 2.353 | 0,077242 | 0,000000 |
| Residuos menores de 1 m² | 1.339 | 0,000289 | 0,000000 |

El conjunto presenta 856,645706 km² de intersección con el mismo INE y sin
solape detectado entre los CP recuperados. Esa superficie es candidata a
estudiar correcciones parciales; no respalda rellenar los recintos completos.
La clasificación de solapes incluye pequeñas diferencias: los 15 componentes
de esa categoría suman unos 375 m² de solape entre CP. Los límites y los
residuos requieren un tratamiento separado.

Se detectaron además dos códigos ausentes del consolidado y de los inventarios
de direcciones provinciales utilizados:

- **43548**, en un componente de La Ràpita (43136): 24,443337 km² de
  intersección con INE coincidente. Lo devolvieron 22 consultas.
- **04071**, en un componente de Almería (04013): 0,057011 km² de intersección
  con INE coincidente. Lo devolvió una consulta.

La conservación de todos los CP de las fuentes de direcciones sigue siendo
cierta, pero no equivale a incluir todos los códigos del WMS o de Correos.
Los dos códigos adicionales se registraron para revisión y se incorporaron
después mediante la corrección aprobada, junto con las intersecciones
compatibles del resto de los candidatos. El resultado contiene 10.853 CP.

Se conservan el [resumen](data/full_analisis/revision_pendientes_wms_resumen.json),
la [clasificación](data/full_analisis/revision_pendientes_wms_clasificacion.csv),
el [detalle de registros](data/full_analisis/revision_pendientes_wms_registros.csv),
el [resumen provincial](data/full_analisis/revision_pendientes_wms_provincias.csv)
y los [CP adicionales](data/full_analisis/revision_pendientes_wms_cp_adicionales.csv).
Las respuestas y geometrías completas quedan fuera de Git, en el directorio
local indicado por `data/cartociudad/revision_pendientes_wms_actual.txt`.

El muestreo puede no descubrir todas las entidades. Se comprueba la geometría
devuelta por el WMS, no solo el código del punto consultado. Para clasificar
los CP se exige una intersección mayor que el menor de 1 m² y el 1 % del
componente. Se verificó que los 55 archivos principales publicados conservan
sus huellas SHA-256.

## Corrección posterior aprobada

Se aplicaron las intersecciones respaldadas de los 219 componentes candidatos,
agrupadas en 191 asignaciones de 189 recintos. Se excluyó de cada transferencia
toda geometría recuperada de un CP diferente. La aprobación final se recortó
en la proyección nativa de la provincia y se conserva como evidencia local
versionada. La reducción del pendiente en el consolidado es de 855,651854 km²;
el área potencial del análisis previo en EPSG:25830 era 856,645706 km².

El [catálogo](data/evidencia_correcciones/catalogo.json) incluye tanto las 34
asignaciones originales como el nuevo paquete. La nueva evidencia evita
repetir consultas WMS para reaplicar estas correcciones. La revisión manual
continúa fuera del flujo automático. El
[registro vigente](data/full_analisis/publicacion_actual.json) recoge el cierre.

## Revisión manual de Navarra

La validación solicitada para Navarra contrastó 10.678 puntos con el WMS de
CartoCiudad, sin errores de consulta. Se conserva como análisis manual fuera
del flujo de generación y de las pruebas habituales. El contraste provincial
no introdujo excepciones al método; Petilla recibió después una corrección
parcial respaldada durante la revisión de todos los pendientes.

- **Petilla de Aragón (31203):** el componente menor ocupa 7,291850 km² y no
  contiene direcciones, incluso sin margen. El WMS respalda principalmente
  el CP 50686; las diferencias de contorno incluyen otros códigos. Un hito
  a 44,95 metros fuera del componente lleva 50680. La corrección posterior
  incorpora únicamente la intersección respaldada con 50686 y conserva
  el residuo, sin ampliar el recinto ni heredar el CP de su otra parte.
- **Piedramillera (31204):** el componente menor ocupa 1,771419 km² y contiene
  dos hitos de la A-12 con CP 31210 e INE 31029, de Los Arcos. El margen de
  50 metros selecciona uno y el método extiende su CP al componente entero.
  El WMS confirma 31210 en ambos puntos, pero respalda aproximadamente
  1,60 km² del componente con 31219. Se registra la discrepancia y se conserva
  el resultado del método, sin introducir una excepción localizada.

Queda para una revisión futura evaluar una salvaguarda para componentes cuyo
único CP seleccionado procede exclusivamente de puntos con INE municipal
ajeno. El contraste muestra diferencias de los límites administrativos de
partida; no justifica descartar todos los puntos de otro municipio ni asignar
un único CP a todo el recinto a partir de una consulta puntual.

La comparación geométrica sobre el ámbito común evaluado de Navarra mide
619,582642 km² de discrepancia antes y 620,465962 km² después. La validación
descubre entidades mediante una malla de puntos y controles dirigidos; no
demuestra concordancia completa con la cartografía postal. Se conservan el
[resumen del contraste](data/full_analisis/validacion_wms_navarra_resumen.json)
y los [desacuerdos agrupados](data/full_analisis/validacion_wms_navarra_desacuerdos.csv).

## Trazabilidad

El directorio indicado en `data/cartociudad/reejecucion_actual.txt` conserva
el manifiesto, las capas administrativas, el método congelado, los estados,
los logs, el origen de los resultados reutilizados y las auditorías. Las
fuentes, los respaldos y los diagnósticos históricos se mantienen fuera del
resultado postal publicado.

La falta de códigos respecto a las fuentes es cero. Sigue pendiente una
comparación independiente con el catálogo oficial completo de Correos y la
resolución de las superficies que siguen pendientes con evidencia adicional.
