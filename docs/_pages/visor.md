---
layout: project
title: Visor de códigos postales
permalink: /visor/
show_author: false
leaflet: true
---

Explora las delimitaciones estimadas por prefijo postal. Abre el control de
capas para elegir entre IGNBase y la ortofotografía PNOA, y activar o desactivar
los polígonos del proyecto y el WMS de códigos postales de CartoCiudad.
El fondo inicial es IGNBase y ambas capas están activadas.
La vista inicial muestra los códigos con prefijo `08`, asociados a Barcelona.
**CartoCiudad se muestra a partir del zoom 14**; acerca el mapa con los botones
o la rueda del ratón para compararlo con las estimaciones.

<label for="postal-prefix">Prefijo postal (dos primeros dígitos)</label>
<select id="postal-prefix" class="form-control mb-3" disabled aria-describedby="map-status">
  <option value="08">08xxx</option>
</select>
<p id="map-status" role="status" aria-live="polite">Cargando el visor…</p>
<div id="postal-map" role="region" aria-label="Mapa de códigos postales" tabindex="0"
  data-source="{{ '/assets/data/' | relative_url }}"></div>
<noscript><p>Activa JavaScript para utilizar el visor.</p></noscript>

Haz clic en un polígono para consultar su código postal. Puedes cambiar el
prefijo sin descargar el conjunto nacional completo. Los dominios disponibles
corresponden a los códigos presentes en los datos publicados. El filtro
selecciona códigos completos, sin recortarlos a una provincia.

El visor utiliza la versión simplificada, transformada a WGS84 (EPSG:4326),
con seis decimales en las coordenadas. No incluye los recintos pendientes y
no está destinado a mediciones precisas. Las delimitaciones son estimadas,
no límites postales oficiales. Consulta las
[fuentes y la metodología]({{ '/' | relative_url }}#metodología-y-fuentes)
y los [ejemplos de uso]({{ '/ejemplos/' | relative_url }}).

Cartografía de fondo y WMS mediante
[Leaflet-providersESP](https://dieghernan.github.io/leaflet-providersESP/).
