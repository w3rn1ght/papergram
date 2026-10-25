#!/usr/bin/env python3
"""Generate the app icons and launch images.

The artwork is a paper plane on a soft blue gradient. Everything is drawn
procedurally so the repository does not need binary design sources.

Usage: python3 tools/make_icons.py [output_directory]
"""

import os
import sys

from PIL import Image, ImageDraw

BASE_SIZE = 1024
SS = 4  # supersampling factor

ICON_SIZES = {
    "Icon-20.png": 20,
    "Icon-20@2x.png": 40,
    "Icon-20@3x.png": 60,
    "Icon-29.png": 29,
    "Icon-29@2x.png": 58,
    "Icon-29@3x.png": 87,
    "Icon-40.png": 40,
    "Icon-40@2x.png": 80,
    "Icon-40@3x.png": 120,
    "Icon-60@2x.png": 120,
    "Icon-60@3x.png": 180,
    "Icon-76.png": 76,
    "Icon-76@2x.png": 152,
    "Icon-83.5@2x.png": 167,
}

LAUNCH_SIZES = {
    "LaunchImage-Portrait.png": (768, 1024),
    "LaunchImage-Portrait@2x.png": (1536, 2048),
    "LaunchImage-Landscape.png": (1024, 768),
    "LaunchImage-Landscape@2x.png": (2048, 1536),
}

TOP_COLOR = (47, 111, 237)
BOTTOM_COLOR = (23, 48, 120)
PAPER_COLOR = (255, 255, 255)
FOLD_COLOR = (206, 224, 255)
BACKGROUND = (244, 244, 242)


def gradient(size):
    image = Image.new("RGB", (size, size), TOP_COLOR)
    draw = ImageDraw.Draw(image)
    for y in range(size):
        ratio = y / max(1, size - 1)
        color = tuple(
            int(TOP_COLOR[i] + (BOTTOM_COLOR[i] - TOP_COLOR[i]) * ratio)
            for i in range(3)
        )
        draw.line([(0, y), (size, y)], fill=color)
    return image


def draw_plane(draw, left, top, size):
    def point(x, y):
        return (left + x * size, top + y * size)

    draw.polygon(
        [point(0.18, 0.52), point(0.82, 0.22), point(0.60, 0.80), point(0.48, 0.58)],
        fill=PAPER_COLOR,
    )
    draw.polygon(
        [point(0.48, 0.58), point(0.82, 0.22), point(0.60, 0.80)],
        fill=FOLD_COLOR,
    )


def icon():
    size = BASE_SIZE * SS
    image = gradient(size)
    draw = ImageDraw.Draw(image)
    draw_plane(draw, size * 0.08, size * 0.10, size * 0.84)
    return image.resize((BASE_SIZE, BASE_SIZE), Image.LANCZOS)


def launch_image(width, height):
    image = Image.new("RGB", (width, height), BACKGROUND)
    draw = ImageDraw.Draw(image)
    logo = min(width, height) * 0.22
    left = (width - logo) / 2.0
    top = (height - logo) / 2.0

    draw.ellipse([left, top, left + logo, top + logo], fill=TOP_COLOR)
    draw_plane(draw, left, top, logo)
    return image


def main():
    output = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Resources"
    )
    os.makedirs(output, exist_ok=True)

    base = icon()
    base.save(os.path.join(output, "AppIcon1024.png"))

    for name, size in ICON_SIZES.items():
        resized = base.resize((size, size), Image.LANCZOS)
        resized.save(os.path.join(output, name), optimize=True)

    for name, (width, height) in LAUNCH_SIZES.items():
        launch_image(width, height).save(os.path.join(output, name), optimize=True)

    print("Icons written to", output)


if __name__ == "__main__":
    main()
