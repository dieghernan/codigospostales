"""Render the social preview from the site's postal GeoJSON, without AI artwork.

Run from any directory: python scripts/social_banner.py
Requires matplotlib. Uses the bundled News Cycle font and leaves the original
banner untouched. Shows the complete geometries of postal prefix 28 in CRS84 with an
equirectangular display, without clipping to administrative boundaries.
"""
import json
import math
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.collections import PatchCollection
from matplotlib.font_manager import FontProperties
from matplotlib.path import Path as PlotPath
from matplotlib.patches import PathPatch

ROOT = Path(__file__).resolve().parents[1]
FONT = FontProperties(fname=ROOT / 'scripts/assets/news-cycle/NewsCycle-Bold.ttf')
CORAL = '#eb6864'


def polygons(geometry):
    if geometry['type'] == 'Polygon':
        return [geometry['coordinates']]
    if geometry['type'] == 'MultiPolygon':
        return geometry['coordinates']
    raise ValueError(f"Unexpected geometry: {geometry['type']}")


def draw_map(ax, features, bounds):
    patches, colors = [], []
    for feature in features:
        code = feature['properties']['COD_POSTAL']
        for polygon in polygons(feature['geometry']):
            vertices, commands = [], []
            for ring in polygon:
                vertices.extend(ring)
                commands.extend([PlotPath.MOVETO] + [PlotPath.LINETO] * (len(ring)-2) + [PlotPath.CLOSEPOLY])
            patches.append(PathPatch(PlotPath(vertices, commands)))
            colors.append(CORAL if int(code) % 11 == 0 else '#eeeeee')
    ax.add_collection(PatchCollection(patches, facecolors=colors,
                                      edgecolors='#555555', linewidths=0.16))
    ax.set_xlim(*bounds[:2])
    ax.set_ylim(*bounds[2:])
    ax.set_aspect(1 / math.cos(math.radians(40)))
    ax.axis('off')


def main():
    data = json.loads((ROOT / 'docs/assets/data/cp-28.geojson').read_text())
    assert data['crs']['properties']['name'].endswith('CRS84')
    features = data['features']
    coordinates = [point for f in features for poly in polygons(f['geometry'])
                   for ring in poly for point in ring]
    xs, ys = zip(*coordinates)
    bounds = (min(xs)-.05, max(xs)+.05, min(ys)-.05, max(ys)+.05)
    fig = plt.figure(figsize=(12, 6.3), dpi=100, facecolor='white')
    draw_map(fig.add_axes([.45, .12, .52, .80]), features, bounds)
    for y, text in zip((.68, .51, .34), ('Códigos', 'postales', 'de España')):
        fig.text(.047, y, text, fontproperties=FONT, fontsize=67, color='#222222')
    fig.add_artist(plt.Line2D([.047, .115], [.28, .28], color=CORAL, linewidth=4))
    fig.text(.047, .205, 'Datos abiertos · GeoPackage', fontproperties=FONT,
             fontsize=19, color='#222222')
    fig.text(.047, .145, 'R y Python', fontproperties=FONT, fontsize=19, color='#222222')
    output = ROOT / 'docs/assets/img/social-preview.jpg'
    fig.savefig(output, dpi=100, pil_kwargs={'quality': 90, 'optimize': True})
    plt.close(fig)
    print(f'{output}: {len(features)} postal features; 1200 × 630 px')


if __name__ == '__main__':
    main()
