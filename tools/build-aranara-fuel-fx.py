"""Small status overlay for the hut's hanging lantern; leaves hut art untouched."""

from pathlib import Path
import xml.etree.ElementTree as ET

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
NAME = "lumine_aranara_hut_fuel_fx"
OUT = ROOT / "art/working/aranara_hut" / NAME
OUT.mkdir(parents=True, exist_ok=True)
SIZE = (384, 384)


def make_frame(lit, strength, sway):
    frame = Image.new("RGBA", SIZE)
    haze = Image.new("RGBA", SIZE)
    draw = ImageDraw.Draw(haze)
    if lit:
        draw.ellipse((310, 204, 369, 267), fill=(255, 177, 69, int(45 * strength)))
        haze = haze.filter(ImageFilter.GaussianBlur(10))
        frame.alpha_composite(haze)
        core = Image.new("RGBA", SIZE)
        pen = ImageDraw.Draw(core)
        pen.ellipse((329 + sway, 225, 351 + sway, 249), fill=(255, 224, 127, int(25 * strength)))
        frame.alpha_composite(core.filter(ImageFilter.GaussianBlur(5)))
        # Two little firefly dots near the existing lantern, not a new flame.
        pen = ImageDraw.Draw(frame)
        pen.ellipse((316 + sway, 219, 319 + sway, 222), fill=(255, 234, 165, int(150 * strength)))
        pen.ellipse((356 - sway, 239, 358 - sway, 241), fill=(255, 222, 142, int(110 * strength)))
    else:
        # A restrained cool wisp signals an empty fuel box.
        draw.ellipse((322, 215, 362, 258), fill=(36, 39, 36, int(100 * strength)))
        frame.alpha_composite(haze.filter(ImageFilter.GaussianBlur(7)))
        pen = ImageDraw.Draw(frame)
        pen.arc((337 + sway, 202, 352 + sway, 224), 65, 250,
                fill=(169, 173, 158, int(160 * strength)), width=2)
        pen.arc((332 - sway, 192, 344 - sway, 213), 245, 430,
                fill=(158, 163, 149, int(115 * strength)), width=2)
    return frame


frames = (
    make_frame(True, .68, -1),
    make_frame(True, 1, 0),
    make_frame(True, .78, 1),
    make_frame(False, .8, 0),
    make_frame(False, 1, 1),
    make_frame(False, .7, -1),
)
for index, frame in enumerate(frames):
    frame.save(OUT / f"{NAME}-{index}.png")

data = ET.Element("spriter_data", scml_version="1.0", generator="BrashMonkey Spriter", generator_version="b5")
folder = ET.SubElement(data, "folder", id="0", name=NAME)
for index in range(len(frames)):
    ET.SubElement(folder, "file", id=str(index), name=f"{NAME}/{NAME}-{index}.png",
                  width="384", height="384", pivot_x="0.5", pivot_y="0.04")
entity = ET.SubElement(data, "entity", id="0", name=NAME)
for anim_id, (name, first) in enumerate((("lit", 0), ("empty", 3))):
    anim = ET.SubElement(entity, "animation", id=str(anim_id), name=name, length="1800", looping="true")
    mainline = ET.SubElement(anim, "mainline")
    timeline = ET.SubElement(anim, "timeline", id="0", name=NAME, object_type="sprite")
    for key_id in range(3):
        time = key_id * 600
        ref = ET.SubElement(mainline, "key", id=str(key_id), time=str(time))
        ET.SubElement(ref, "object_ref", id="0", timeline="0", key=str(key_id), z_index="0")
        key = ET.SubElement(timeline, "key", id=str(key_id), time=str(time))
        ET.SubElement(key, "object", folder="0", file=str(first + key_id), x="0", y="0")
ET.indent(data)
scml_path = OUT.parent / f"{NAME}.scml"
ET.ElementTree(data).write(scml_path, encoding="utf-8", xml_declaration=True)
print(scml_path)
