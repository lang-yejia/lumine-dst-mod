"""Build the star reliquary sprite from its original concept art."""
from pathlib import Path
import xml.etree.ElementTree as ET
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "art/working/relic_codex"
SPRITE = OUT / "lumine_relic_codex"
SPRITE.mkdir(parents=True, exist_ok=True)

source = Image.open(ROOT / "art/source/relic_codex/lumine_relic_codex.png").convert("RGBA")
bounds = source.getchannel("A").point(lambda v: 255 if v > 12 else 0).getbbox()
book = source.crop(bounds)
book.thumbnail((104, 104), Image.Resampling.LANCZOS)
canvas = Image.new("RGBA", (128, 128))
canvas.alpha_composite(book, ((128 - book.width) // 2, (128 - book.height) // 2))
canvas.save(OUT / "lumine_relic_codex.png")
canvas.save(SPRITE / "lumine_relic_codex-0.png")

data = ET.Element("spriter_data", scml_version="1.0", generator="BrashMonkey Spriter", generator_version="b5")
folder = ET.SubElement(data, "folder", id="0", name="lumine_relic_codex")
ET.SubElement(folder, "file", id="0", name="lumine_relic_codex/lumine_relic_codex-0.png",
              width="128", height="128", pivot_x="0.5", pivot_y="0.5")
entity = ET.SubElement(data, "entity", id="0", name="lumine_relic_codex")
anim = ET.SubElement(entity, "animation", id="0", name="idle", length="1000", looping="true")
key = ET.SubElement(ET.SubElement(anim, "mainline"), "key", id="0", time="0")
ET.SubElement(key, "object_ref", id="0", timeline="0", key="0", z_index="0")
timeline = ET.SubElement(anim, "timeline", id="0", name="item", object_type="sprite")
frame = ET.SubElement(timeline, "key", id="0", time="0")
ET.SubElement(frame, "object", folder="0", file="0", x="0", y="0")
ET.indent(data)
ET.ElementTree(data).write(OUT / "lumine_relic_codex.scml", encoding="utf-8", xml_declaration=True)
