"""Generate both Focal banners from real postal geometries.

Run: py scripts/focal_banners.py (requires matplotlib and Pillow).
Fonts are bundled under assets/fira-sans with their OFL license.
"""
import io
import json
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.collections import PatchCollection
from matplotlib.path import Path as PlotPath
from matplotlib.patches import PathPatch
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'docs/assets/img'
FONTS = ROOT / 'scripts/assets/fira-sans'
SCALE = 2


def render(width, height, filename):
    features = json.loads((ROOT / 'docs/assets/data/cp-28.geojson').read_text())['features']
    fig = plt.figure(figsize=(width / 100, height / 100), dpi=100 * SCALE,
                     facecolor='#f2f1f1')
    ax = fig.add_axes([.35, 0, .65, 1])
    patches, colors = [], []
    for feature in features:
        geometry = feature['geometry']
        polygons = ([geometry['coordinates']] if geometry['type'] == 'Polygon'
                    else geometry['coordinates'])
        for polygon in polygons:
            vertices, commands = [], []
            for ring in polygon:
                vertices.extend(ring)
                commands.extend([PlotPath.MOVETO] + [PlotPath.LINETO] * (len(ring) - 2)
                                + [PlotPath.CLOSEPOLY])
            patches.append(PathPatch(PlotPath(vertices, commands)))
            colors.append('#ff9285' if int(feature['properties']['COD_POSTAL']) % 7 == 0
                          else '#dedddd')
    ax.add_collection(PatchCollection(patches, facecolors=colors,
                                     edgecolors='#777575', linewidths=.38))
    ax.set_xlim(-4.02, -3.12)
    ax.set_ylim(40.16, 40.69)
    ax.set_aspect('auto')
    ax.axis('off')
    buffer = io.BytesIO()
    fig.savefig(buffer, format='png', dpi=100 * SCALE, facecolor=fig.get_facecolor())
    plt.close(fig)
    canvas = Image.open(buffer).convert('RGB')
    mask = Image.new('L', canvas.size)
    ramp = [round(255 * (1 - max(0, min(1, (x / canvas.width - .34) / .36))))
            for x in range(canvas.width)]
    mask.putdata(ramp * canvas.height)
    canvas = Image.composite(Image.new('RGB', canvas.size, '#262626'), canvas, mask)
    draw = ImageDraw.Draw(canvas)
    ratio = width / 1280

    def text(x, y, value, size, color='white', bold=False):
        font = ImageFont.truetype(str(FONTS / ('FiraSans-Bold.ttf' if bold
                                              else 'FiraSans-Regular.ttf')),
                                 round(size * ratio * SCALE))
        draw.text((round(x * ratio * SCALE), round(y * height / 640 * SCALE)),
                  value, font=font, fill=color, anchor='lt')

    text(64, 66, 'DATOS ABIERTOS · GEOPACKAGE', 20, '#ff9285', True)
    for y, line in zip((130, 222, 314), ('Códigos', 'postales', 'de España')):
        text(60, y, line, 84, bold=True)
    text(64, 432, 'Áreas postales estimadas', 27)
    text(64, 470, 'a partir de datos abiertos', 27)
    text(64, 565, 'Explora el mapa. Descarga los datos.', 20)
    # A quiet opaque strip keeps the source credit readable over every polygon.
    draw.rectangle((round(width * .62 * SCALE), round(height * .94 * SCALE),
                    width * SCALE, height * SCALE), fill='#262626')
    text(810, 607, 'CartoCiudad · Goerlich y Pérez Vázquez', 12, '#eeeeee')
    canvas = canvas.resize((width, height), Image.Resampling.LANCZOS)
    canvas.save(ASSETS / filename, quality=95, subsampling=0, optimize=True)
    print(f'{filename}: {canvas.size}')


if __name__ == '__main__':
    render(1280, 640, 'github-preview.jpg')
    render(1200, 630, 'social-preview.jpg')

