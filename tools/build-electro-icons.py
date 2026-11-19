"""Build the electro medallion, skill icons, and padded inventory icon."""
from io import BytesIO
from math import cos, pi, sin
from pathlib import Path
from random import Random
from struct import unpack_from

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/source/element"
IMAGES = ROOT / "mod/lumine/images"
SIZE = 128
SCALE = 4
INK = "#22182c"
GOLD = "#c0a46e"
PALE = "#f3deff"
LILAC = "#c596f0"
VIOLET = "#8558bd"


def medal(kind):
    image = Image.new("RGBA", (SIZE * SCALE, SIZE * SCALE))
    draw = ImageDraw.Draw(image)

    def path(points):
        return [(round(x * SCALE), round(y * SCALE)) for x, y in points]

    def polygon(points, fill):
        draw.polygon(path(points), fill=fill)

    def line(points, fill, width):
        draw.line(path(points), fill=fill, width=round(width * SCALE), joint="curve")

    def ring(radius, fill):
        points = []
        for i in range(48):
            angle = i * pi / 24
            r = radius + .48 * sin(i * 1.7) + .69 * cos(8 * angle)
            points.append((64 + r * cos(angle), 64 + r * sin(angle)))
        polygon(points, fill)

    ring(59, INK)
    ring(56, "#493245")
    ring(53, "#805b65")
    ring(51.5, GOLD)
    ring(48.5, "#3b294c")
    ring(45.5, "#54386e")
    ring(42, "#3d2855")

    rng = Random(28)
    for i in range(38):
        angle = rng.uniform(0, 2 * pi)
        r = rng.uniform(37, 53)
        x, y = 64 + r * cos(angle), 64 + r * sin(angle)
        length = rng.uniform(.5, 2.7)
        line([(x, y), (x - length * sin(angle), y + length * cos(angle))],
             "#9a78a3" if i % 3 == 0 else "#261b36", .55)

    for x, y in ((64, 17), (111, 64), (64, 111), (17, 64)):
        polygon([(x, y - 3), (x + 2.6, y), (x, y + 3), (x - 2.6, y)], GOLD)

    def gem(points):
        polygon(points, LILAC)
        line(points + [points[0]], INK, 3)

    def spark(x, y, r):
        polygon([(x, y - r), (x + r * .22, y - r * .18), (x + r, y),
                 (x + r * .23, y + r * .21), (x, y + r), (x - r * .2, y + r * .2),
                 (x - r, y), (x - r * .2, y - r * .18)], PALE)

    bolt = [(69, 29), (43, 62), (61, 66), (53, 101), (85, 58), (66, 57)]
    if kind == "emblem":
        gem(bolt)
        polygon([(69, 32), (48, 60), (63, 61)], PALE)
        polygon([(65, 66), (57, 95), (81, 60)], VIOLET)
        line([(68, 33), (62, 62), (57, 91)], "#e0bbff", 1.4)
        spark(86, 40, 7)
        spark(39, 83, 6)
    elif kind == "infusion":
        line([(44, 84), (79, 44)], INK, 13)
        gem([(50, 83), (44, 77), (75, 39), (92, 32), (85, 49)])
        line([(51, 75), (81, 41)], PALE, 2)
        line([(40, 70), (57, 86)], INK, 9)
        line([(40, 70), (57, 86)], GOLD, 4)
        line([(47, 78), (36, 93)], GOLD, 4)
        line([(39, 50), (49, 44), (48, 56), (59, 51)], PALE, 2.5)
        line([(72, 81), (79, 68), (85, 72), (94, 59)], LILAC, 2.8)
        spark(91, 74, 5)
    elif kind == "burst":
        for radius, fill in ((23, INK), (19, VIOLET), (14, LILAC), (7, PALE)):
            draw.ellipse(path([(66 - radius, 62 - radius), (66 + radius, 62 + radius)]), fill=fill)
        for points in (
            [(33, 65), (38, 53), (51, 47), (67, 44), (84, 47), (96, 56)],
            [(96, 66), (91, 76), (76, 83), (59, 84), (43, 80), (35, 74)],
        ):
            line(points, PALE, 2.4)
        spark(46, 37, 8)
        spark(89, 38, 5)
        spark(86, 88, 7)
    else:
        gem([(70, 37), (51, 61), (63, 63), (57, 86), (78, 58), (66, 57)])
        for points in (
            [(35, 72), (34, 59), (39, 47), (49, 39), (61, 36)],
            [(93, 58), (93, 71), (87, 83), (77, 91), (64, 94)],
        ):
            line(points, LILAC, 3)
        polygon([(57, 31), (67, 35), (58, 41)], PALE)
        polygon([(69, 88), (58, 94), (70, 99)], PALE)
        spark(88, 46, 6)
        spark(40, 85, 5)

    return image.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def write_atlas(image, directory, name):
    # The existing 128 px geo atlas supplies the KTEX header and DXT5 mip layout.
    template = (SOURCE / "geo-emblem.tex").read_bytes()
    layout = [unpack_from("<HHHI", template, 8 + index * 10) for index in range(8)]
    pixels = bytearray()
    for width, height, _, expected in layout:
        level = image.resize((width, height), Image.Resampling.LANCZOS)
        level = level.convert("RGBa").transpose(Image.Transpose.FLIP_TOP_BOTTOM)
        level = Image.frombytes("RGBA", level.size, level.tobytes())
        # Pillow encodes DXT5 from 4 x 4 blocks. Pad the two smallest mip levels.
        if width < 4 or height < 4:
            level = level.resize((4, 4), Image.Resampling.NEAREST)
        dds = BytesIO()
        level.save(dds, format="DDS", pixel_format="DXT5")
        payload = dds.getvalue()[128:]
        if len(payload) != expected:
            raise ValueError(f"Unexpected DXT5 size for {name} at {width}x{height}")
        pixels.extend(payload)
    (directory / f"{name}.tex").write_bytes(template[:88] + pixels)
    (directory / f"{name}.xml").write_text(
        f'<Atlas><Texture filename="{name}.tex" /><Elements>'
        f'<Element name="{name}.tex" u1="0.00390625" u2="0.99609375" '
        'v1="0.00390625" v2="0.99609375" /></Elements></Atlas>\n',
        encoding="utf-8",
    )


def main():
    for kind in ("emblem", "passive", "infusion", "burst"):
        icon = medal(kind)
        name = f"electro-{kind}"
        icon.save(SOURCE / f"{name}.png")
        write_atlas(icon, IMAGES / "element", name)
        if kind == "emblem":
            essence = Image.new("RGBA", (SIZE, SIZE))
            reduced = icon.crop(icon.getbbox())
            reduced.thumbnail((82, 82), Image.Resampling.LANCZOS)
            essence.alpha_composite(reduced, ((SIZE - reduced.width) // 2, (SIZE - reduced.height) // 2))
            write_atlas(essence, IMAGES / "inventoryimages", "lumine_electro_essence")


if __name__ == "__main__":
    main()
