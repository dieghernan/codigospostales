---
layout: default
title: Códigos postales de España
seo_title: "Códigos postales de España: mapa y descarga GeoPackage"
description: >-
  Explora las áreas postales estimadas de España y descarga los consolidados
  GeoPackage completo y simplificado para R, Python y QGIS.
og_image_alt: Mapa de las áreas postales estimadas de España con prefijo 28.
subtitle: Mapa y descarga de áreas postales estimadas
header_type: base
dataset: true
excerpt: >-
  Explora el mapa y descarga polígonos postales estimados de España en GeoPackage.
  Dos consolidados para análisis y visualización con R, Python o QGIS.
---

Explora y descarga **áreas estimadas de los códigos postales de España**.
Los productos son dos archivos GeoPackage consolidados: uno completo para
análisis y otro simplificado para visualización, compatibles con **R**, **Python** y **QGIS**.

<p class="product-note"><strong>No son límites postales oficiales.</strong>
Se estiman a partir de CartoCiudad y límites administrativos. No se garantiza
la inclusión de todos los códigos postales de las fuentes.</p>

## Archivos disponibles

{% assign full = site.data.products.full %}
{% assign simple = site.data.products.simplified %}
<div class="product-downloads">
  <section class="product-download" aria-labelledby="download-full">
    <h3 id="download-full">Consolidado completo</h3>
    <p>Geometría completa para análisis y mediciones sobre la estimación.</p>
    <a class="btn btn-primary" href="{{ full.url }}">Descargar completo · {{ full.size_mb | replace: '.', ',' }} MB</a>
    <p class="mt-2 mb-0">Generado: <time datetime="{{ full.generated }}">{{ full.generated }}</time><br>Versión (SHA-256): <code title="{{ full.revision }}">{{ full.revision | slice: 0, 12 }}</code></p>
  </section>
  <section class="product-download" aria-labelledby="download-simple">
    <h3 id="download-simple">Consolidado simplificado</h3>
    <p>Archivo más ligero para mapas y visualización. Evita mediciones precisas.</p>
    <a class="btn btn-primary" href="{{ simple.url }}">Descargar simplificado · {{ simple.size_mb | replace: '.', ',' }} MB</a>
    <p class="mt-2 mb-0">Generado: <time datetime="{{ simple.generated }}">{{ simple.generated }}</time><br>Versión (SHA-256): <code title="{{ simple.revision }}">{{ simple.revision | slice: 0, 12 }}</code></p>
  </section>
</div>


<div class="row align-items-center text-center my-4">
  <div class="col-12 col-sm-6 mb-3">
    <a class="btn btn-outline-primary"
       href="{{ '/visor/' | relative_url }}">
      Explorar el mapa
    </a>
  </div>

  <div class="col-12 col-sm-6 mb-3">
    <a class="btn btn-outline-primary"
       href="{{ '/ejemplos/' | relative_url }}">
      Inicio rápido con <strong>R</strong>, <strong>Python</strong> y <strong>QGIS</strong>
    </a>
  </div>
</div>

## Una vista de los datos

El mapa muestra los códigos postales que empiezan por `28`, seleccionados de la
versión simplificada. El filtro utiliza el prefijo postal y conserva la
geometría completa de cada código, sin recortarla a una provincia.

![Delimitaciones estimadas de los códigos postales con prefijo 28, en azul claro con contornos oscuros.]({{ '/assets/img/codigos-postales-28.png' | relative_url }})

La página de [ejemplos de uso]({{ '/ejemplos/' | relative_url }}) explica cómo
leer solo ese dominio postal y generar el mapa con **R** o **Python**.

## Características y cobertura

<div class="product-facts" markdown="1">

- **{{ full.postal_codes }} códigos postales** en el consolidado completo, con prefijos del {{ full.prefixes | first }} al {{ full.prefixes | last }} ({{ full.prefixes | size }} prefijos).
- **{{ full.pending }} recintos pendientes**, con {{ full.pending_km2 | replace: '.', ',' }} km² sin asignar en la versión completa.
- **Dos capas:** `codigos_postales` y `pendientes`, en GeoPackage y EPSG:25830.
- **Licencia:** [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), con atribución.

</div>

El ámbito es España, con cobertura estimada y recintos sin asignar. La presencia
de los 52 prefijos no implica que estén todos los códigos postales ni que toda
la superficie tenga un CP. Los archivos provinciales del repositorio son
**resultados intermedios**, no productos de descarga independientes.

Las fechas anteriores corresponden a la generación de cada consolidado, no a
la actualización de las direcciones originales. Los límites administrativos
proceden de Municipios2024, publicados por Goerlich y Pérez Vázquez (2025);
la antigüedad de las direcciones de CartoCiudad depende de la descarga de origen.

Ambos archivos incluyen las capas `codigos_postales` y `pendientes`, en
ETRS89 / UTM zona 30N (EPSG:25830). Los códigos postales se almacenan como texto
de cinco dígitos, conservando los ceros iniciales. La capa `pendientes` recoge
los recintos que no han recibido un código postal. Ambas capas contienen
geometrías `MULTIPOLYGON`; la capa postal no incluye el municipio.

La versión simplificada conserva los códigos y los atributos, pero no está
destinada a mediciones precisas. En `pendientes`, el campo `AREA_M2` conserva
la superficie medida en la versión completa.

Los GeoPackage se almacenan con **Git LFS**. Para obtenerlos al clonar el
repositorio, instala **Git LFS** y ejecuta `git lfs install`. Después ejecuta
`git lfs pull` para descargar los datos.
También puedes acceder a los archivos desde la
[carpeta de datos en GitHub](https://github.com/dieghernan/codigospostales/tree/main/data).

## Antecedentes

Los polígonos de códigos postales permiten relacionar direcciones y
estadísticas con áreas geográficas. Su disponibilidad ha cambiado: según
[Goerlich (2022)](#ref-goerlich-cp), hacia 2016 se podían descargar los
polígonos de Correos desde CartoCiudad a través del CNIG. Esa capa dejó de
ofrecerse para descarga a principios de 2017, tras un cambio en la política
de datos de Correos.

Actualmente, [Correos comercializa la capa cartográfica](#ref-correos) mediante
una licencia de pago. El [WMS de CartoCiudad](#ref-cartociudad-wms) permite
visualizar los códigos postales, pero sus polígonos no están disponibles para
descarga desde ese servicio.

El objetivo del proyecto es ofrecer una estimación reproducible con datos
abiertos. Las direcciones de CartoCiudad aportan posiciones y códigos
postales. Una teselación de Voronoi permite construir áreas de proximidad a
esas posiciones; al ajustarlas a los límites administrativos y unir las áreas
con el mismo código, se obtienen polígonos postales estimados. La proximidad
es una aproximación geométrica y no reproduce necesariamente las decisiones
de reparto de Correos.

## Metodología y fuentes

El procedimiento selecciona las direcciones de cada componente del recinto
administrativo con un margen interior de 200 m y un segundo intento de 50 m
si no encuentra ninguna. Con un único código postal (CP) asigna el recinto
completo; con varios, genera áreas de Voronoi y las recorta al recinto.
Los componentes sin direcciones seleccionadas quedan pendientes, salvo que
el municipio tenga un único código recuperado en sus otros componentes.

Después disuelve las superficies por código postal entre provincias. Un
mismo código puede contener varias superficies separadas y abarcar más de
una provincia. El filtrado de direcciones puede excluir códigos presentes en
los datos de origen, por lo que el resultado no garantiza su inclusión total.

Una revisión opcional consulta muestras de puntos interiores de los recintos
pendientes en el WMS de CartoCiudad. Solo asigna un código si todos los puntos
consultados tienen respuesta y devuelven el mismo CP. El muestreo no garantiza
que no existan otros códigos en partes del recinto que no se hayan consultado.

Los recintos administrativos proceden de `LAU2boundaries4Spain.gpkg`, de
[Goerlich y Pérez Vázquez (2025)](#ref-lau2). Se utilizan las capas
`Municipios2024`, `Condominios` y `Provincias` para delimitar los recintos de
trabajo y proporcionar el fondo provincial de los mapas.

El proyecto toma como referencias metodológicas el trabajo de
[Goerlich (2022)](#ref-goerlich-cp) y el artículo de
[Sánchez (2020)](#ref-sanchez).
Las decisiones de esta implementación, sus limitaciones y las instrucciones
de generación se describen en el
[README del repositorio](https://github.com/dieghernan/codigospostales#readme).

## Autoría y licencia

Proyecto de [dieghernan](https://dieghernan.github.io/).
El repositorio se distribuye bajo la licencia
[Creative Commons Attribution 4.0 International](https://github.com/dieghernan/codigospostales/blob/main/LICENSE).

## Uso de inteligencia artificial

Se ha utilizado **OpenAI Codex** como apoyo en el desarrollo del código,
la redacción y revisión de la documentación y la preparación de este sitio web.
Los banners del proyecto se generan con geometrías reales mediante
`scripts/focal_banners.py`, con Fira Sans y la paleta de **Focal**. Estas
herramientas no son la fuente de los datos geográficos: las fuentes y los
trabajos metodológicos utilizados se citan a continuación.

## Referencias

<div id="ref-cartociudad" class="csl-entry" markdown="1">

Instituto Geográfico Nacional / Centro Nacional de Información Geográfica
(IGN/CNIG). (s. f.). *CartoCiudad* [Conjunto de datos].
[Portal de CartoCiudad](https://www.cartociudad.es/web/portal/).

</div>

<div id="ref-cartociudad-wms" class="csl-entry" markdown="1">

Instituto Geográfico Nacional / Centro Nacional de Información Geográfica
(IGN/CNIG). (s. f.). *Servicios de visualización de CartoCiudad: direcciones
y códigos postales*.
[Descripción del WMS](https://www.cartociudad.es/web/portal/directorio-de-servicios/visualizacion).

</div>

<div id="ref-correos" class="csl-entry" markdown="1">

Correos. (s. f.). *Base de datos de códigos postales y capa cartográfica*.
[Información del producto](https://www.correos.es/es/es/empresas/marketing/identifica-a-tus-clientes-potenciales/base-de-datos-de-codigos-postales).

</div>

<div id="ref-goerlich-cp" class="csl-entry" markdown="1">

Goerlich, F. J. (2022). *Elaboración de un mapa de códigos postales de España 
con recursos libres. Cómo evitar pagar por disponer de información de referencia*. Working Papers Ivie, n.º 2022-3. València: Ivie.
[doi:10.12842/WPIVIE_0322](https://doi.org/10.12842/WPIVIE_0322).
[Versión online actualizada](https://www.uv.es/goerlich/Ivie/CodPost.html).

</div>

<div id="ref-lau2" class="csl-entry" markdown="1">

Goerlich, F. J., y Pérez Vázquez, P. (2025). *Base de datos histórica de
contornos municipales de España –LAU2boundaries4Spain–* (versión v2)
[Conjunto de datos]. Zenodo.
[doi:10.5281/zenodo.15345101](https://doi.org/10.5281/zenodo.15345101).

</div>

<div id="ref-sanchez" class="csl-entry" markdown="1">

Sánchez, J. I. (2020, 13 de noviembre). *Así hice el mapa de los códigos
postales de España con SIG y datos abiertos*. NoSoloSIG.
[Artículo](https://www.nosolosig.com/articulos/asi-hice-el-mapa-de-los-codigos-postales-de-espana-con-sig-y-datos-abiertos).

</div>
