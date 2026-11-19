"""Draw the Geo skill marks and a restrained, seamless ground sigil."""
from pathlib import Path
import math
import xml.etree.ElementTree as ET
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ICON_DIR = ROOT / "art/source/element"
OUT = ROOT / "art/working/geo_field"
FRAMES = OUT / "lumine_geo_field"
ICON_DIR.mkdir(parents=True, exist_ok=True)
FRAMES.mkdir(parents=True, exist_ok=True)

INK = (56, 43, 31, 255)
GOLD = (230, 183, 77, 255)
PALE = (255, 230, 157, 255)
DARK = (134, 89, 43, 255)


def polygon(draw, points, fill, width=4):
    draw.polygon(points, fill=fill)
    draw.line(points + [points[0]], fill=INK, width=width, joint="curve")


def icon(kind):
    canvas = Image.new("RGBA", (512, 512))
    d = ImageDraw.Draw(canvas)
    # An uneven, inked medallion keeps the symbols legible at inventory size.
    rim = [(256 + int(222 * math.cos(i * math.pi / 6)),
            256 + int(222 * math.sin(i * math.pi / 6))) for i in range(12)]
    polygon(d, rim, (78, 62, 43, 235), 15)
    d.ellipse((62, 62, 450, 450), outline=GOLD, width=13)
    d.ellipse((82, 82, 430, 430), outline=DARK, width=5)
    if kind == "geo-emblem":
        polygon(d, [(256, 90), (382, 192), (350, 360), (256, 425), (162, 360), (130, 192)], GOLD, 14)
        polygon(d, [(256, 124), (338, 201), (319, 335), (256, 380), (193, 335), (174, 201)], (99, 73, 43, 255), 8)
        polygon(d, [(256, 151), (304, 218), (281, 313), (256, 342), (231, 313), (208, 218)], PALE, 7)
        d.line([(130, 192), (256, 251), (382, 192)], fill=INK, width=8)
    elif kind == "geo-passive":
        polygon(d, [(256, 101), (365, 153), (373, 293), (256, 411), (139, 293), (147, 153)], GOLD, 13)
        polygon(d, [(256, 145), (328, 185), (331, 277), (256, 361), (181, 277), (184, 185)], (90, 70, 47, 255), 7)
        d.line([(193, 258), (239, 307), (325, 206)], fill=PALE, width=28, joint="curve")
    elif kind == "geo-shield":
        polygon(d, [(256, 99), (371, 165), (350, 315), (256, 408), (162, 315), (141, 165)], GOLD, 13)
        polygon(d, [(256, 140), (327, 184), (314, 296), (256, 354), (198, 296), (185, 184)], (91, 71, 51, 255), 7)
        polygon(d, [(256, 169), (301, 222), (288, 288), (256, 327), (224, 288), (211, 222)], PALE, 6)
        d.line([(144, 171), (256, 217), (368, 171)], fill=INK, width=7)
    else:
        for radius, width, colour in [(167, 12, GOLD), (123, 9, PALE), (72, 8, GOLD)]:
            d.ellipse((256-radius, 256-radius, 256+radius, 256+radius), outline=colour, width=width)
        for i in range(6):
            a = i * math.pi/3
            x, y = 256 + 157*math.cos(a), 256 + 157*math.sin(a)
            polygon(d, [(int(x), int(y-22)), (int(x+18), int(y)),
                        (int(x), int(y+22)), (int(x-18), int(y))], PALE, 5)
        polygon(d, [(256, 190), (314, 256), (256, 322), (198, 256)], GOLD, 10)
    return canvas.resize((128, 128), Image.Resampling.LANCZOS)


for name in ("geo-emblem", "geo-passive", "geo-shield", "geo-field"):
    icon(name).save(ICON_DIR / f"{name}.png")


def field_frame(index):
    size = 384
    layer = Image.new("RGBA", (size, size))
    d = ImageDraw.Draw(layer)
    cx = cy = 192
    # The boundary stays centered and almost still. Only short highlights drift.
    for radius, width, colour in [(168, 8, (190, 130, 48, 140)),
                                  (155, 3, (255, 222, 131, 180)),
                                  (111, 3, (174, 124, 53, 110))]:
        d.ellipse((cx-radius, cy-radius, cx+radius, cy+radius), outline=colour, width=width)
    for i in range(8):
        angle = i * math.pi / 4
        x = cx + 165*math.cos(angle)
        y = cy + 165*math.sin(angle)
        dx, dy = 11*math.cos(angle), 11*math.sin(angle)
        d.line((x-dx, y-dy, x+dx, y+dy), fill=(255, 224, 146, 205), width=5)
    for i in range(4):
        angle = i * math.pi/2 + math.pi/4
        x, y = cx + 104*math.cos(angle), cy + 104*math.sin(angle)
        d.polygon([(x, y-10), (x+8, y), (x, y+10), (x-8, y)], fill=(225, 171, 77, 125))
    for i in range(3):
        angle = (index/24*2*math.pi + i*2*math.pi/3)
        x, y = cx+156*math.cos(angle), cy+156*math.sin(angle)
        d.ellipse((x-5, y-5, x+5, y+5), fill=(255, 237, 166, 200))
    d.polygon([(192, 148), (235, 192), (192, 236), (149, 192)], outline=(235, 184, 88, 125), width=5)
    return layer


files = []
for i in range(24):
    name = f"lumine_geo_field-{i:02d}.png"
    field_frame(i).save(FRAMES / name)
    files.append(name)

data = ET.Element("spriter_data", scml_version="1.0", generator="BrashMonkey Spriter", generator_version="b5")
folder = ET.SubElement(data, "folder", id="0", name="lumine_geo_field")
for i, filename in enumerate(files):
    ET.SubElement(folder, "file", id=str(i), name=f"lumine_geo_field/{filename}",
                  width="384", height="384", pivot_x="0.5", pivot_y="0.5")
entity = ET.SubElement(data, "entity", id="0", name="lumine_geo_field")
animation = ET.SubElement(entity, "animation", id="0", name="loop", length="2400", looping="true")
mainline = ET.SubElement(animation, "mainline")
timeline = ET.SubElement(animation, "timeline", id="0", name="lumine_geo_field", object_type="sprite")
for i in range(24):
    key = ET.SubElement(mainline, "key", id=str(i), time=str(i*100))
    ET.SubElement(key, "object_ref", id="0", timeline="0", key=str(i), z_index="0")
    key = ET.SubElement(timeline, "key", id=str(i), time=str(i*100))
    ET.SubElement(key, "object", folder="0", file=str(i), x="0", y="0", angle="0", scale_x="1", scale_y="1")
ET.indent(data)
ET.ElementTree(data).write(OUT / "lumine_geo_field.scml", encoding="utf-8", xml_declaration=True)
