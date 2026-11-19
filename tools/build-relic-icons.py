"""Extract the original five-part survivor relic art into DST sprite assets."""
from pathlib import Path
import xml.etree.ElementTree as ET
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SHEET = ROOT / "art/source/relics/survivor-relic-sheet.png"
SPRITES = ROOT / "art/working/relic_icons"
INVENTORY = ROOT / "art/working/relic_inventory"
SPRITES.mkdir(parents=True, exist_ok=True)
INVENTORY.mkdir(parents=True, exist_ok=True)
roles = ("wilson", "wickerbottom", "warly")
sheet = Image.open(SHEET).convert("RGBA")
width, height = sheet.size

scml = ET.Element("spriter_data", scml_version="1.0", generator="BrashMonkey Spriter", generator_version="b5")
folder = ET.SubElement(scml, "folder", id="0", name="lumine_relic_icons")
entity = ET.SubElement(scml, "entity", id="0", name="lumine_relic_icons")

for row, role in enumerate(roles):
    for column in range(5):
        name = f"{role}_{column + 1}"
        index = row * 5 + column
        cell = sheet.crop((round(column * width / 5), round(row * height / 3),
                           round((column + 1) * width / 5), round((row + 1) * height / 3)))
        alpha = cell.getchannel("A")
        bounds = alpha.point(lambda value: 255 if value > 8 else 0).getbbox()
        if bounds is None:
            raise ValueError(f"Empty relic: {name}")
        icon = cell.crop(bounds)
        icon.thumbnail((116, 116), Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (128, 128))
        canvas.alpha_composite(icon, ((128 - icon.width) // 2, (128 - icon.height) // 2))
        canvas.save(SPRITES / f"{name}.png")
        canvas.save(INVENTORY / f"lumine_relic_{name}.png")

        ET.SubElement(folder, "file", id=str(index), name=f"{name}.png",
                      width="128", height="128", pivot_x=".5", pivot_y=".5")
        anim = ET.SubElement(entity, "animation", id=str(index), name=name, length="1000", looping="true")
        key = ET.SubElement(ET.SubElement(anim, "mainline"), "key", id="0", time="0")
        ET.SubElement(key, "object_ref", id="0", timeline="0", key="0", z_index="0")
        timeline = ET.SubElement(anim, "timeline", id="0", name="icon", object_type="sprite")
        frame = ET.SubElement(timeline, "key", id="0", time="0")
        ET.SubElement(frame, "object", folder="0", file=str(index), x="0", y="0", angle="0", scale_x="1", scale_y="1")

ET.indent(scml)
ET.ElementTree(scml).write(SPRITES / "lumine_relic_icons.scml", encoding="utf-8", xml_declaration=True)
print("Prepared fifteen relic icons")
