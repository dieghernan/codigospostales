---
layout: default
title: Ejemplos de uso
permalink: /ejemplos/
---

Los datos se distribuyen como archivos GeoPackage y se pueden utilizar desde R
o Python. No es necesario instalar un paquete propio del proyecto.

Estos ejemplos utilizan la versión simplificada y seleccionan los códigos
postales que empiezan por `28` (`28xxx`). El filtro se ejecuta al leer el
archivo, sin cargar toda la capa en memoria. Selecciona códigos completos por
su prefijo; no recorta sus geometrías al límite de una provincia. Prefijo
postal y provincia son criterios distintos: un mismo código postal puede
abarcar varias provincias. Una selección por provincia requiere un criterio
espacial sobre sus límites administrativos.

Los códigos postales tienen cinco dígitos y se conservan como texto para
mantener los ceros iniciales. Para otro dominio, cambia `'28%'` por el prefijo
deseado seguido de `%`, por ejemplo `'080%'` para `080xx`.

## Preparación

Ejecuta los ejemplos desde la raíz de una copia del repositorio con los datos
descargados mediante Git LFS (consulta el
[README](https://github.com/dieghernan/codigospostales#descarga-del-repositorio)).
También puedes descargar el GeoPackage desde la
[portada]({{ '/' | relative_url }}#archivos-disponibles) y ajustar la ruta del
archivo en el ejemplo.

La copia simplificada está destinada a visualización. Para un análisis con la
geometría completa, usa `data/codigos_postales.gpkg` con la misma consulta.
Las delimitaciones son estimadas y no constituyen límites postales oficiales.

## R

Instala **sf** y **ggplot2** con `install.packages(c("sf", "ggplot2"))`.

```r
library(sf)
library(ggplot2)

cp <- st_read(
  "data/codigos_postales_simplificado.gpkg",
  query = "SELECT * FROM codigos_postales WHERE COD_POSTAL LIKE '28%'",
  quiet = TRUE
)

mapa <- ggplot(cp) +
  geom_sf(fill = "#dbe8ef", color = "#34495e", linewidth = 0.15) +
  theme_void() +
  labs(
    title = "C\u00f3digos postales con prefijo 28",
    subtitle = "Delimitaciones estimadas \u00b7 versi\u00f3n simplificada",
    caption = paste(
      "Fuentes: CartoCiudad (IGN/CNIG)",
      "L\u00edmites administrativos: Goerlich y P\u00e9rez V\u00e1zquez (2025)",
      "Elaboraci\u00f3n: dieghernan (dieghernan.github.io)",
      sep = "\n"
    )
  ) +
  theme(
    plot.background = element_rect(fill = "white", color = NA),
    plot.title = element_text(face = "bold"),
    plot.caption = element_text(hjust = 0, size = 9),
    plot.margin = margin(15, 15, 15, 15)
  )

dir.create("docs/assets/img", recursive = TRUE, showWarnings = FALSE)
ggsave(
  "docs/assets/img/codigos-postales-28.png",
  mapa,
  width = 7,
  height = 7,
  dpi = 160
)
```

## Python

Instala **GeoPandas**, **Pyogrio**, **Matplotlib** y sus dependencias con
`pip install -r scripts/requirements-ejemplos.txt`. Este archivo fija las
versiones del entorno utilizado para comprobar el ejemplo.

```python
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import geopandas as gpd
import matplotlib.pyplot as plt

cp = gpd.read_file(
    "data/codigos_postales_simplificado.gpkg",
    engine="pyogrio",
    sql="SELECT * FROM codigos_postales WHERE COD_POSTAL LIKE '28%'",
)

ax = cp.plot(
    figsize=(7, 7), facecolor="#dbe8ef", edgecolor="#34495e", linewidth=0.3
)
ax.set_title("Códigos postales con prefijo 28")
ax.set_axis_off()
ax.figure.subplots_adjust(bottom=0.2)
ax.figure.text(
    0.05, 0.02,
    "Fuentes: CartoCiudad (IGN/CNIG)\n"
    "Límites administrativos: Goerlich y Pérez Vázquez (2025)\n"
    "Elaboración: dieghernan (dieghernan.github.io)",
    fontsize=8,
)
Path("docs/assets/img").mkdir(parents=True, exist_ok=True)
ax.figure.savefig(
    "docs/assets/img/codigos-postales-28-python.png", dpi=160, facecolor="white"
)
plt.close(ax.figure)
```

## Previsualización

![Mapa de las delimitaciones estimadas de los códigos postales con prefijo 28, con relleno azul claro y contornos oscuros.]({{ '/assets/img/codigos-postales-28.png' | relative_url }})

La imagen mostrada se genera con `source("scripts/ejemplo_prefijo.R")` desde
la raíz del repositorio y se guarda en
`docs/assets/img/codigos-postales-28.png`. El ejemplo de Python guarda su
resultado en `docs/assets/img/codigos-postales-28-python.png`.

Los bloques anteriores reproducen los scripts `scripts/ejemplo_prefijo.R` y
`scripts/ejemplo_prefijo.py`, incluidos los pies de fuentes y autoría.
Para ejecutar el segundo, utiliza `python scripts/ejemplo_prefijo.py` o
`py scripts/ejemplo_prefijo.py` en Windows. Ambos generan archivos de imagen
sin necesitar una ventana gráfica ni retoques manuales.

Se han comprobado con R 4.6.1, **sf** 1.1.3 y **ggplot2** 4.0.3, y con Python
3.15.0 y las dependencias fijadas en `scripts/requirements-ejemplos.txt`.
Para reproducir el mismo resultado, conserva el GeoPackage y los scripts de
la misma revisión del repositorio. Los ejemplos muestran los mismos códigos;
el aspecto puede variar entre R y Python o con otras fuentes y versiones.
