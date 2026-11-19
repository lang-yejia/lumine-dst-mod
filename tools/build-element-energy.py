"""Build elemental energy item sprites and a small looping DST animation."""
from pathlib import Path
import math
import xml.etree.ElementTree as ET
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "art/working/element_energy"
SPRITES = OUT / "lumine_element_energy"
SPRITES.mkdir(parents=True, exist_ok=True)
ICON_OUT = OUT / "icons"
ICON_OUT.mkdir(exist_ok=True)
SOURCES = ROOT / "art/source/element"
KINDS = [("particle", (244, 248, 250), None),
         ("orb", (235, 246, 255), None)]

def frame(kind, color, emblem, phase):
    size = 128
    cx, cy = 64, 64 + int(math.sin(phase * math.pi / 2) * 2)
    radius = 20 if kind == "particle" else 31
    canvas = Image.new("RGBA", (size, size))
    glow = Image.new("RGBA", (size, size))
    d = ImageDraw.Draw(glow)
    for r, alpha in ((radius+15, 20), (radius+9, 35), (radius+3, 48)):
        d.ellipse((cx-r, cy-r, cx+r, cy+r), fill=(*color, alpha))
    canvas.alpha_composite(glow.filter(ImageFilter.GaussianBlur(8)))
    orb = Image.new("RGBA", (size, size))
    px = orb.load()
    for y in range(cy-radius-2, cy+radius+3):
        for x in range(cx-radius-2, cx+radius+3):
            dist = math.hypot(x-cx, y-cy)
            if dist > radius+1 or not 0 <= x < size or not 0 <= y < size: continue
            edge = max(0, min(1, radius + 1 - dist))
            shine = max(0, 1 - math.hypot(x-(cx-radius*.33), y-(cy-radius*.4))/radius)
            light = .52 + .42*shine + .06*math.sin(phase*math.pi/2)
            rgb = tuple(min(255, int(v*light+255*(1-light)*.52)) for v in color)
            px[x,y] = (*rgb, int(230*edge))
    canvas.alpha_composite(orb)
    line = ImageDraw.Draw(canvas)
    line.ellipse((cx-radius,cy-radius,cx+radius,cy+radius), outline=(*color, 225), width=2)
    line.arc((cx-radius+3,cy-radius+3,cx+radius-3,cy+radius-3), 205+phase*12, 310+phase*12,
             fill=(255,255,244,170), width=2)
    if emblem:
        mark = Image.open(SOURCES/emblem).convert("RGBA")
        bounds = mark.getchannel("A").getbbox()
        mark = mark.crop(bounds)
        mark.thumbnail((31,31), Image.Resampling.LANCZOS)
        # Clear silhouette keeps the elemental mark readable at game scale.
        a = mark.getchannel("A")
        mark = Image.new("RGBA", mark.size, (255,255,244,0))
        mark.putalpha(a.point(lambda v: min(235, int(v*.9))))
        canvas.alpha_composite(mark, (cx-mark.width//2, cy-mark.height//2))
    else:
        line.ellipse((cx-7,cy-9,cx+5,cy+3), fill=(255,255,255,215))
        line.ellipse((cx-2,cy-3,cx+3,cy+2), fill=(255,255,255,255))
    for i in range(3):
        angle = phase*.35 + i*2*math.pi/3
        r = radius+6
        x, y = cx+math.cos(angle)*r, cy+math.sin(angle)*r
        line.ellipse((x-1,y-1,x+1,y+1), fill=(*color, 140))
    return canvas

data = ET.Element("spriter_data", scml_version="1.0", generator="BrashMonkey Spriter", generator_version="b5")
folder = ET.SubElement(data, "folder", id="0", name="lumine_element_energy")
entity = ET.SubElement(data, "entity", id="0", name="lumine_element_energy")
for index, (kind, color, emblem) in enumerate(KINDS):
    for phase in range(4):
        image = frame(kind, color, emblem, phase)
        file_id = index*4+phase
        image.save(SPRITES/f"lumine_element_energy-{file_id}.png")
        ET.SubElement(folder, "file", id=str(file_id),
                      name=f"lumine_element_energy/lumine_element_energy-{file_id}.png",
                      width="128", height="128", pivot_x="0.5", pivot_y="0.35")
        if phase == 0:
            name = "lumine_element_particle" if kind == "particle" else "lumine_element_orb"
            image.save(ICON_OUT/f"{name}.png")
    anim = ET.SubElement(entity, "animation", id=str(index), name=kind, length="1000", looping="true")
    mainline = ET.SubElement(anim, "mainline")
    timeline = ET.SubElement(anim, "timeline", id="0", name=kind, object_type="sprite")
    for phase in range(4):
        key = ET.SubElement(mainline, "key", id=str(phase), time=str(phase*250))
        ET.SubElement(key, "object_ref", id="0", timeline="0", key=str(phase), z_index="0")
        key = ET.SubElement(timeline, "key", id=str(phase), time=str(phase*250))
        ET.SubElement(key, "object", folder="0", file=str(index*4+phase), x="0", y="0", angle="0")
ET.indent(data)
ET.ElementTree(data).write(OUT/"lumine_element_energy.scml", encoding="utf-8", xml_declaration=True)
