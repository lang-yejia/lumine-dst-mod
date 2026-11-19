"""Prepare the Seven statue sprite, element glow loops and crafting icon."""
from pathlib import Path
import math
import xml.etree.ElementTree as ET
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "art/source/seven_statue/base-generated.png"
OUT = ROOT / "art/working/seven_statue"
FRAMES = OUT / "lumine_seven_statue"
FRAMES.mkdir(parents=True, exist_ok=True)

source = Image.open(SRC).convert("RGBA")
bounds = source.getchannel("A").point(lambda a: 255 if a > 12 else 0).getbbox()
body = source.crop(bounds)
body.thumbnail((348, 476), Image.Resampling.LANCZOS)
idle = Image.new("RGBA", (384, 512))
idle.alpha_composite(body, ((384-body.width)//2, 504-body.height))

icon = idle.crop((42, 18, 342, 285))
icon.thumbnail((112, 112), Image.Resampling.LANCZOS)
icon_canvas = Image.new("RGBA", (128, 128))
icon_canvas.alpha_composite(icon, ((128-icon.width)//2, (128-icon.height)//2))
icon_canvas.save(OUT / "lumine_seven_statue-icon.png")

crystal = (192, 153)


def glow(colour, strength, phase):
    image = idle.copy()
    halo = Image.new("RGBA", image.size)
    d = ImageDraw.Draw(halo)
    x, y = crystal
    for radius, alpha in ((34, 22), (24, 37), (13, 55)):
        d.ellipse((x-radius, y-radius, x+radius, y+radius), fill=(*colour, int(alpha*strength)))
    halo = halo.filter(ImageFilter.GaussianBlur(10))
    image.alpha_composite(halo)
    details = Image.new("RGBA", image.size)
    d = ImageDraw.Draw(details)
    d.line([(x, y-19), (x+12, y), (x, y+23), (x-12, y)], fill=(*colour, int(125*strength)), width=3, joint="curve")
    for i in range(4):
        a = phase + i*math.pi/2
        sx, sy = x+int(34*math.cos(a)), y+int(26*math.sin(a))
        d.line((sx-3, sy, sx+3, sy), fill=(*colour, int(170*strength)), width=2)
        d.line((sx, sy-3, sx, sy+3), fill=(*colour, int(170*strength)), width=2)
    image.alpha_composite(details)
    return image


images = [idle, glow((239, 221, 156), .55, 0)]
for colour in ((112, 222, 197), (232, 177, 79)):
    images += [glow(colour, s, a) for s, a in ((.75, 0), (1, .7), (.82, 1.4), (.96, 2.1))]
for i, image in enumerate(images):
    image.save(FRAMES / f"lumine_seven_statue-{i}.png")

anims = (
    ("idle", (0,), 1000),
    ("proximity_loop", (0,1,0,1), 1400),
    ("wind_loop", (2,3,4,5), 1200),
    ("geo_loop", (6,7,8,9), 1200),
    ("use_wind", (1,2,3), 600),
    ("use_geo", (1,6,7), 600),
)
data = ET.Element("spriter_data", scml_version="1.0", generator="BrashMonkey Spriter", generator_version="b5")
folder = ET.SubElement(data, "folder", id="0", name="lumine_seven_statue")
for i in range(len(images)):
    ET.SubElement(folder, "file", id=str(i), name=f"lumine_seven_statue/lumine_seven_statue-{i}.png",
                  width="384", height="512", pivot_x="0.5", pivot_y="0.02")
entity = ET.SubElement(data, "entity", id="0", name="lumine_seven_statue")
for anim_id, (name, sequence, length) in enumerate(anims):
    animation = ET.SubElement(entity, "animation", id=str(anim_id), name=name, length=str(length),
                              looping="false" if name.startswith("use_") else "true")
    mainline = ET.SubElement(animation, "mainline")
    timeline = ET.SubElement(animation, "timeline", id="0", name="lumine_seven_statue", object_type="sprite")
    for i, file_id in enumerate(sequence):
        time = i*length//len(sequence)
        key = ET.SubElement(mainline, "key", id=str(i), time=str(time))
        ET.SubElement(key, "object_ref", id="0", timeline="0", key=str(i), z_index="0")
        key = ET.SubElement(timeline, "key", id=str(i), time=str(time))
        ET.SubElement(key, "object", folder="0", file=str(file_id), x="0", y="0", angle="0",
                      scale_x="1", scale_y="1")
ET.indent(data)
ET.ElementTree(data).write(OUT / "lumine_seven_statue.scml", encoding="utf-8", xml_declaration=True)
