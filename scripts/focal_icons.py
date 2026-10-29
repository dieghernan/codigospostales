"""Render Focal site icons from the same polygons as favicon.svg (Pillow)."""
from pathlib import Path
from PIL import Image, ImageDraw

ASSETS = Path(__file__).resolve().parents[1] / 'docs/assets/img'


def main():
    scale = 16
    image = Image.new('RGBA', (64 * scale, 64 * scale))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((0, 0, 64 * scale, 64 * scale), radius=12 * scale,
                           fill='#262626')
    shapes = [([(8, 8), (31, 8), (25, 25), (8, 32)], '#f8f9fa'),
              ([(31, 8), (56, 8), (56, 30), (42, 25), (25, 25)], '#aaaaaa'),
              ([(8, 32), (25, 25), (42, 25), (45, 43), (28, 56), (8, 56)], '#f8f9fa'),
              ([(42, 25), (56, 30), (56, 56), (28, 56), (45, 43)], '#ff9285')]
    for points, color in shapes:
        points = [(x * scale, y * scale) for x, y in points]
        draw.polygon(points, fill=color)
        draw.line(points + [points[0]], fill='#262626', width=3 * scale, joint='curve')
    for size in (16, 32, 192, 512):
        image.resize((size, size), Image.Resampling.LANCZOS).save(ASSETS / f'favicon-{size}.png')
    image.resize((180, 180), Image.Resampling.LANCZOS).save(ASSETS / 'apple-touch-icon.png')
    image.save(ASSETS / 'favicon.ico', sizes=[(16, 16), (32, 32), (48, 48)])


if __name__ == '__main__':
    main()
