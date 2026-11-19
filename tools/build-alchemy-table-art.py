"""Build Spriter frames and icon from the alchemy table source images."""

from pathlib import Path
from PIL import Image
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
src = root / "art/source/alchemy_table"
out = root / "art/working/alchemy_table"
frames = out / "alchemy_table"
frames.mkdir(parents=True, exist_ok=True)
rendered = []

for index, state in enumerate(("idle", "lit")):
    image = Image.open(src / f"{state}.png").convert("RGBA")
    alpha = image.getchannel("A")
    bounds = alpha.point(lambda value: 255 if value > 16 else 0).getbbox()
    if bounds is None:
        raise ValueError(f"Empty table frame: {state}")
    image = image.crop(bounds)
    image.thumbnail((348, 340), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (384, 384), (0, 0, 0, 0))
    canvas.alpha_composite(image, ((384 - image.width) // 2, 364 - image.height))
    canvas.save(frames / f"alchemy_table-{index}.png")
    rendered.append(canvas)
    if index == 0:
        image.thumbnail((116, 116), Image.Resampling.LANCZOS)
        icon = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
        icon.alpha_composite(image, ((128 - image.width) // 2, (128 - image.height) // 2))
        icon.save(out / "alchemy_table-icon.png")

# A midpoint keeps the nearby glow alive without returning to the unlit frame.
Image.blend(rendered[0], rendered[1], 0.6).save(frames / "alchemy_table-2.png")

data = ET.Element("spriter_data", scml_version="1.0", generator="BrashMonkey Spriter", generator_version="b5")
folder = ET.SubElement(data, "folder", id="0", name="alchemy_table")
for index in range(3):
    ET.SubElement(folder, "file", id=str(index), name=f"alchemy_table/alchemy_table-{index}.png",
                  width="384", height="384", pivot_x="0.5", pivot_y="0.06")
entity = ET.SubElement(data, "entity", id="0", name="alchemy_table")
for anim_id, (name, sequence, length) in enumerate((
    ("idle", ((0, 0),), 1000),
    ("proximity_loop", ((0, 1), (700, 2), (1400, 1)), 2100),
    ("use", ((0, 1), (350, 0)), 500),
)):
    anim = ET.SubElement(entity, "animation", id=str(anim_id), name=name, length=str(length), looping="false" if name == "use" else "true")
    mainline = ET.SubElement(anim, "mainline")
    timeline = ET.SubElement(anim, "timeline", id="0", name="alchemy_table", object_type="sprite")
    for key_id, (time, file_id) in enumerate(sequence):
        mainkey = ET.SubElement(mainline, "key", id=str(key_id), time=str(time))
        ET.SubElement(mainkey, "object_ref", id="0", timeline="0", key=str(key_id), z_index="0")
        key = ET.SubElement(timeline, "key", id=str(key_id), time=str(time))
        ET.SubElement(key, "object", folder="0", file=str(file_id), x="0", y="0", angle="0", scale_x="1", scale_y="1")

ET.indent(data)
ET.ElementTree(data).write(out / "alchemy_table.scml", encoding="utf-8", xml_declaration=True)
print(out)
