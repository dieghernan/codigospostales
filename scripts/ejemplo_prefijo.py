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
