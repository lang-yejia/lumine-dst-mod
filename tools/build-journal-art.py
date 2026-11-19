"""Format the travel journal art for the DST item and inventory icon."""

from pathlib import Path
from PIL import Image
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
source = Image.open(root / "art/source/journal/lumine_journal.png").convert("RGBA")
bounds = source.getchannel("A").point(lambda a: 255 if a > 16 else 0).getbbox()
if bounds is None:
    raise ValueError("Empty journal art")
source = source.crop(bounds)
out = root / "art/working/journal"
frames = out / "lumine_journal"
frames.mkdir(parents=True, exist_ok=True)

def render(size, max_size, target):
    image = source.copy()
    image.thumbnail(max_size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.alpha_composite(image, ((size[0] - image.width) // 2, (size[1] - image.height) // 2))
    canvas.save(target)

render((128, 128), (104, 104), frames / "lumine_journal-0.png")
render((128, 128), (88, 88), out / "lumine_journal-icon.png")

data = ET.Element("spriter_data", scml_version="1.0", generator="BrashMonkey Spriter", generator_version="b5")
folder = ET.SubElement(data, "folder", id="0", name="lumine_journal")
ET.SubElement(folder, "file", id="0", name="lumine_journal/lumine_journal-0.png", width="128", height="128", pivot_x="0.5", pivot_y="0.15")
entity = ET.SubElement(data, "entity", id="0", name="lumine_journal")
anim = ET.SubElement(entity, "animation", id="0", name="idle", length="1000", looping="true")
mainline = ET.SubElement(anim, "mainline")
key = ET.SubElement(mainline, "key", id="0", time="0")
ET.SubElement(key, "object_ref", id="0", timeline="0", key="0", z_index="0")
timeline = ET.SubElement(anim, "timeline", id="0", name="lumine_journal", object_type="sprite")
key = ET.SubElement(timeline, "key", id="0", time="0")
ET.SubElement(key, "object", folder="0", file="0", x="0", y="0", angle="0", scale_x="1", scale_y="1")
ET.indent(data)
ET.ElementTree(data).write(out / "lumine_journal.scml", encoding="utf-8", xml_declaration=True)
print(out)
