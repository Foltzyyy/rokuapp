"""Builds the app's images from The Chapel's official logo files in brand/.

Logos are only ever scaled down (never up, never recolored), per the branding guide.
Run: python3 tools/make_images.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
BRAND = ROOT / "brand"
OUT = ROOT / "app" / "images"
CHARCOAL = (43, 43, 42)
WHITE = (255, 255, 255)

# In the stacked logo, the mark (the cross of chevrons) ends at this pixel row;
# below it is the "THE CHAPEL / LITTLESTOWN" wordmark.
MARK_BOTTOM = 492


def load(name):
    return Image.open(BRAND / name).convert("RGBA")


def scale_to_height(img, height):
    """Downscale with premultiplied alpha so edges don't pick up dark fringes."""
    assert height <= img.height, "logos must not be scaled up"
    width = round(img.width * height / img.height)
    return img.convert("RGBa").resize((width, height), Image.LANCZOS).convert("RGBA")


def save_transparent(img, name):
    img.save(OUT / name)
    print(f"{name}: {img.width}x{img.height}")


def on_background(size, color, logo, logo_height):
    canvas = Image.new("RGB", size, color)
    mark = scale_to_height(logo, logo_height)
    x = (size[0] - mark.width) // 2
    y = (size[1] - mark.height) // 2
    canvas.paste(mark, (x, y), mark)
    return canvas


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    stacked_white = load("thechapel2022_S_LT_w.png")
    stacked_blue = load("thechapel2022_S_LT_bl.png")
    horizontal_white = load("thechapel2022_H_LT_w.png")

    # Header logo on the home screen.
    save_transparent(scale_to_height(horizontal_white, 72), "logo_header.png")

    # The mark on its own (allowed by the guide), cropped from the stacked logo.
    mark = stacked_white.crop((0, 0, stacked_white.width, MARK_BOTTOM))
    mark = mark.crop(mark.getbbox())
    save_transparent(scale_to_height(mark, 260), "logo_mark.png")
    save_transparent(scale_to_height(mark, 91), "logo_mark_small.png")

    # Home-screen tile: full-color logo on white, with breathing room.
    for size, height, name in (((540, 405), 315, "icon_fhd.png"), ((290, 218), 170, "icon_hd.png")):
        on_background(size, WHITE, stacked_blue, height).save(OUT / name)
        print(f"{name}: {size[0]}x{size[1]}")

    # Splash screen: white logo on Charcoal, matching the app.
    for size, height, name in (((1920, 1080), 440, "splash_fhd.png"), ((1280, 720), 293, "splash_hd.png")):
        on_background(size, CHARCOAL, stacked_white, height).save(OUT / name)
        print(f"{name}: {size[0]}x{size[1]}")


if __name__ == "__main__":
    main()
