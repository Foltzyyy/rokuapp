"""Generates the home-screen tile and splash screen for the Roku app.

Run: python3 tools/make_images.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent.parent / "app" / "images"
NAVY = (20, 33, 61)
GOLD = (242, 193, 78)
WHITE = (255, 255, 255)
SOFT = (214, 220, 229)
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
REGULAR = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"


def font(path, size):
    return ImageFont.truetype(path, size)


def centered(draw, y, text, fnt, fill, width):
    w = draw.textlength(text, font=fnt)
    draw.text(((width - w) / 2, y), text, font=fnt, fill=fill)


def cross(draw, cx, top, height, fill):
    bar = max(4, height // 7)
    draw.rectangle([cx - bar / 2, top, cx + bar / 2, top + height], fill=fill)
    arm_y = top + height * 0.28
    draw.rectangle([cx - height * 0.32, arm_y, cx + height * 0.32, arm_y + bar], fill=fill)


def live_pill(draw, cx, y, fnt, height):
    label = "LIVE"
    tw = draw.textlength(label, font=fnt)
    pad = height * 0.55
    dot = height * 0.32
    w = dot + pad * 0.6 + tw + pad * 2
    x0 = cx - w / 2
    draw.rounded_rectangle([x0, y, x0 + w, y + height], radius=height / 2, fill=GOLD)
    dy = y + (height - dot) / 2
    draw.ellipse([x0 + pad, dy, x0 + pad + dot, dy + dot], fill=(200, 40, 40))
    bbox = draw.textbbox((0, 0), label, font=fnt)
    ty = y + (height - (bbox[3] - bbox[1])) / 2 - bbox[1]
    draw.text((x0 + pad + dot + pad * 0.6, ty), label, font=fnt, fill=NAVY)


def icon(width, height, name):
    img = Image.new("RGB", (width, height), NAVY)
    d = ImageDraw.Draw(img)
    s = width / 540
    cross(d, width / 2, 40 * s, 110 * s, GOLD)
    centered(d, 165 * s, "The Chapel", font(BOLD, int(64 * s)), WHITE, width)
    live_pill(d, width / 2, 265 * s, font(BOLD, int(40 * s)), 70 * s)
    img.save(OUT / name)


def splash(width, height, name):
    img = Image.new("RGB", (width, height), NAVY)
    d = ImageDraw.Draw(img)
    s = width / 1920
    cross(d, width / 2, 250 * s, 190 * s, GOLD)
    centered(d, 480 * s, "The Chapel", font(BOLD, int(110 * s)), WHITE, width)
    centered(d, 630 * s, "Littlestown Livestream", font(REGULAR, int(56 * s)), SOFT, width)
    img.save(OUT / name)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    icon(540, 405, "icon_fhd.png")
    icon(290, 218, "icon_hd.png")
    splash(1920, 1080, "splash_fhd.png")
    splash(1280, 720, "splash_hd.png")
    print("Wrote images to", OUT)
