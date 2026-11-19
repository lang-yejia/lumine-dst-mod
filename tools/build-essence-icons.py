"""Keep elemental essence artwork inside DST's 128-pixel inventory frame."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/source/element"
OUT = ROOT / "art/working/essence_icons"
OUT.mkdir(parents=True, exist_ok=True)

for element in ("wind", "geo"):
    image = Image.open(SOURCE / f"{element}-emblem.png").convert("RGBA")
    bounds = image.getchannel("A").point(lambda a: 255 if a > 12 else 0).getbbox()
    if bounds is None:
        raise ValueError(f"Empty {element} emblem")
    image = image.crop(bounds)
    image.thumbnail((82, 82), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (128, 128))
    canvas.alpha_composite(image, ((128-image.width)//2, (128-image.height)//2))
    canvas.save(OUT / f"lumine_{element}_essence.png")
