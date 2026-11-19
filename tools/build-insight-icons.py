"""Draw nine compact, code-native DST inventory emblems for travel insights."""
from pathlib import Path
import xml.etree.ElementTree as ET
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "art/working/insight"
OUT.mkdir(parents=True, exist_ok=True)
COLORS = {2: (110, 145, 170), 3: (168, 132, 74), 4: (148, 110, 172)}


def draw_icon(kind, stage):
    scale = 4
    img = Image.new("RGBA", (128 * scale, 128 * scale))
    d = ImageDraw.Draw(img)
    def box(coords):
        return tuple(v * scale for v in coords)
    ink = (37, 31, 36, 255)
    paper = (225, 209, 169, 255)
    edge = (247, 232, 185, 255)
    color = COLORS[stage] + (255,)

    # A small parchment tablet with an asymmetrical inked silhouette.
    d.rounded_rectangle(box((18, 13, 110, 115)), radius=10 * scale, fill=ink)
    d.rounded_rectangle(box((23, 18, 105, 109)), radius=7 * scale, fill=paper)
    d.polygon([box((23, 18))[0:2], box((103, 18))[0:2], box((97, 25))[0:2], box((27, 24))[0:2]], fill=edge)
    d.line([box((29, 31))[0:2], box((99, 31))[0:2]], fill=(123, 96, 71), width=2 * scale)
    d.ellipse(box((36, 35, 92, 91)), fill=ink)
    d.ellipse(box((40, 39, 88, 87)), fill=color)
    d.ellipse(box((44, 43, 84, 83)), outline=edge, width=2 * scale)

    if kind == "weapon":
        d.line([box((51, 74))[0:2], box((76, 49))[0:2]], fill=ink, width=7 * scale)
        d.line([box((51, 74))[0:2], box((76, 49))[0:2]], fill=edge, width=4 * scale)
        d.polygon([box((73, 49))[0:2], box((81, 43))[0:2], box((77, 52))[0:2]], fill=edge)
        d.line([box((47, 66))[0:2], box((59, 78))[0:2]], fill=ink, width=5 * scale)
    elif kind == "head":
        d.arc(box((48, 53, 80, 80)), 0, 180, fill=ink, width=5 * scale)
        d.line([box((47, 67))[0:2], box((47, 77))[0:2], box((81, 77))[0:2], box((81, 67))[0:2]], fill=edge, width=4 * scale)
        d.polygon([box((64, 48))[0:2], box((69, 60))[0:2], box((64, 66))[0:2], box((59, 60))[0:2]], fill=edge)
    else:
        d.polygon([box((53, 50))[0:2], box((61, 55))[0:2], box((67, 55))[0:2], box((75, 50))[0:2], box((84, 61))[0:2], box((77, 68))[0:2], box((75, 80))[0:2], box((53, 80))[0:2], box((51, 68))[0:2], box((44, 61))[0:2]], fill=ink)
        d.polygon([box((54, 54))[0:2], box((61, 59))[0:2], box((67, 59))[0:2], box((74, 54))[0:2], box((79, 61))[0:2], box((73, 66))[0:2], box((71, 77))[0:2], box((57, 77))[0:2], box((55, 66))[0:2], box((49, 61))[0:2]], fill=edge)
        d.line([box((64, 59))[0:2], box((64, 76))[0:2]], fill=color, width=3 * scale)

    roman = {2: "II", 3: "III", 4: "IV"}[stage]
    try:
        font = ImageFont.truetype("C:/Windows/Fonts/georgiab.ttf", 13 * scale)
    except OSError:
        font = ImageFont.load_default()
    bounds = d.textbbox((0, 0), roman, font=font)
    d.text(((128 * scale - (bounds[2] - bounds[0])) // 2, 94 * scale), roman, fill=ink, font=font)

    reduced = img.resize((92, 92), Image.Resampling.LANCZOS)
    image = Image.new("RGBA", (128, 128))
    image.alpha_composite(reduced, (18, 18))
    name = f"lumine_insight_{kind}_{stage}"
    image.save(OUT / f"{name}.png")
    folder = OUT / name
    folder.mkdir(parents=True, exist_ok=True)
    image.save(folder / f"{name}-0.png")

    scml = ET.Element("spriter_data", scml_version="1.0", generator="BrashMonkey Spriter", generator_version="b5")
    f = ET.SubElement(scml, "folder", id="0", name=name)
    ET.SubElement(f, "file", id="0", name=f"{name}/{name}-0.png", width="128", height="128", pivot_x="0.5", pivot_y="0.5")
    entity = ET.SubElement(scml, "entity", id="0", name=name)
    anim = ET.SubElement(entity, "animation", id="0", name="idle", length="1000", looping="true")
    key = ET.SubElement(ET.SubElement(anim, "mainline"), "key", id="0", time="0")
    ET.SubElement(key, "object_ref", id="0", timeline="0", key="0", z_index="0")
    timeline = ET.SubElement(anim, "timeline", id="0", name=name, object_type="sprite")
    tkey = ET.SubElement(timeline, "key", id="0", time="0")
    ET.SubElement(tkey, "object", folder="0", file="0", x="0", y="0", angle="0", scale_x="1", scale_y="1")
    ET.indent(scml)
    ET.ElementTree(scml).write(OUT / f"{name}.scml", encoding="utf-8", xml_declaration=True)


for kind in ("weapon", "head", "body"):
    for stage in (2, 3, 4):
        draw_icon(kind, stage)
print(f"Created nine insight icons in {OUT}")
