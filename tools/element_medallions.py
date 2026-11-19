"""Compile four hand-painted medallions and a padded inventory emblem."""

from pathlib import Path
from runpy import run_path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/source/element"
IMAGES = ROOT / "mod/lumine/images"
write_atlas = run_path(str(ROOT / "tools/build-electro-icons.py"))["write_atlas"]


def centered(sprite, size):
    content = sprite.crop(sprite.getchannel("A").getbbox())
    content.thumbnail((size, size), Image.Resampling.LANCZOS)
    frame = Image.new("RGBA", (128, 128))
    frame.alpha_composite(content, ((128 - content.width) // 2, (128 - content.height) // 2))
    return frame


def pack_medallions(element, skills, columns=2):
    with Image.open(SOURCE / f"{element}-medallions.png") as source:
        atlas = source.convert("RGBA")
    width, height = atlas.size
    names = ("emblem", *skills)
    rows = (len(names) + columns - 1) // columns
    for index, name in enumerate(names):
        column, row = index % columns, index // columns
        sprite = atlas.crop((column * width // columns, row * height // rows,
                             (column + 1) * width // columns, (row + 1) * height // rows))
        sprite.putalpha(sprite.getchannel("A").point(lambda value: value if value > 8 else 0))
        alpha_bbox = sprite.getchannel("A").getbbox()
        if not alpha_bbox or any(value == edge for value, edge in zip(alpha_bbox, (0, 0, *sprite.size))):
            raise ValueError(f"{element} {name} needs a transparent gutter on all sides")
        write_atlas(centered(sprite, 120), IMAGES / "element", f"{element}-{name}")
        if name == "emblem":
            write_atlas(centered(sprite, 82), IMAGES / "inventoryimages", f"lumine_{element}_essence")
