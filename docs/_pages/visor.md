---
layout: default
title: Mapa de códigos postales de España
subtitle: Busca un código postal o una dirección y explora las áreas estimadas
excerpt: Busca por código postal o dirección en el mapa de España. Consulta áreas estimadas del consolidado simplificado y compáralas con CartoCiudad.
permalink: /visor/
show_author: false
map_embed: true
---

**Áreas estimadas, no oficiales.** El mapa utiliza el consolidado simplificado
y no muestra los recintos pendientes de asignación.

<p><a class="btn btn-primary" href="{{ '/visor/mapa/' | relative_url }}">Abrir el mapa a toda ventana</a></p>
<iframe class="postal-map-frame" src="{{ '/visor/mapa/' | relative_url }}"
  title="Mapa interactivo de códigos postales de España" allowfullscreen></iframe>

<details class="viewer-help" markdown="1">
<summary>Cómo utilizar el mapa y sus capas</summary>

- Introduce un **CP de cinco dígitos** para destacar su área o busca una dirección.
- El marcador de una dirección se retira al iniciar otra búsqueda de dirección, buscar un CP o cambiar el prefijo.
- El selector de prefijo carga códigos completos por sus dos primeros dígitos: **no recorta por provincia**.
- Pulsa un área para consultar su CP. Los colores y líneas se explican en la leyenda.
- **Explorar CP** permite filtrar los códigos del prefijo y seleccionar un área con el teclado, sin pulsar polígonos.
- Abre **Capas** para cambiar entre IGNBase Gris, IGNBase y PNOA, o activar los límites administrativos del IGN.
- En móvil, abre **Buscar o cambiar prefijo** para desplegar los controles. La ayuda del botón **?** aparece dentro del panel, sin tapar el mapa con un tooltip flotante.
- **Leyenda** abre un panel lateral. Puedes cerrar la leyenda y las capas con su botón de cierre, con Escape o al pulsar fuera.
- El WMS de **CartoCiudad aparece desde el zoom 11**. Las áreas estimadas y CartoCiudad están activados inicialmente.
- **Compartir vista** copia un enlace con prefijo, posición, zoom y CP seleccionado. No incluye la dirección buscada.
- En el mapa incrustado, la rueda desplaza la página. Usa los botones de zoom o abre el mapa a toda ventana para acercar con la rueda.

La vista inicial muestra el prefijo `08`. Prefijo postal y provincia son
criterios distintos: un código puede abarcar más de una provincia.
Los GeoJSON se derivan del consolidado simplificado en WGS84 (EPSG:4326),
con seis decimales. No están destinados a mediciones precisas.

</details>

[Descargar los consolidados]({{ '/' | relative_url }}#archivos-disponibles) ·
[Inicio rápido y ejemplos]({{ '/ejemplos/' | relative_url }}) ·
[Fuentes y metodología]({{ '/' | relative_url }}#metodología-y-fuentes)

<details class="viewer-help" markdown="1">
<summary>Incrustar el visor en otra página</summary>

```html
<iframe src="https://dieghernan.github.io/codigospostales/visor/mapa/"
  title="Áreas postales estimadas de España"
  width="100%" height="650" allowfullscreen></iframe>
```

Cartografía de fondo y WMS mediante
[Leaflet-providersESP](https://dieghernan.github.io/leaflet-providersESP/).

</details>
