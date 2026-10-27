---
layout: default
title: Visor de códigos postales
permalink: /visor/
show_author: false
map_embed: true
---

Explora las delimitaciones estimadas por prefijo postal. Abre el control de
capas para elegir entre IGNBase Gris, IGNBase y la ortofotografía PNOA, y activar o desactivar
los polígonos del proyecto y el WMS de códigos postales de CartoCiudad.
El fondo inicial es IGNBase Gris y ambas capas están activadas.
El overlay **Límites administrativos · IGN** está disponible sin activar;
permite comparar los códigos postales con los límites administrativos.
La vista inicial muestra los códigos con prefijo `08`.
**CartoCiudad se muestra a partir del zoom 11**; acerca el mapa con los botones
o la rueda del ratón para compararlo con las estimaciones.

**Prefijo postal y provincia son criterios
distintos.** El selector filtra por los dos primeros dígitos del código
postal, sin recortar las geometrías a límites provinciales. Un mismo código
postal puede abarcar varias provincias.

<p><a class="btn btn-primary" href="{{ '/visor/mapa/' | relative_url }}" target="_blank" rel="noopener">Abrir el visor a toda ventana ↗</a></p>
<iframe class="postal-map-frame" src="{{ '/visor/mapa/' | relative_url }}"
  title="Visor interactivo de códigos postales por prefijo" loading="lazy" allowfullscreen></iframe>

Puedes abrir el visor a toda ventana o incrustarlo en otra página con un
`iframe`:

```html
<iframe src="https://dieghernan.github.io/codigospostales/visor/mapa/"
  title="Códigos postales de España por prefijo"
  width="100%" height="650" allowfullscreen></iframe>
```

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
