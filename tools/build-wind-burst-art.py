"""Turn the original wind burst painting into a compact DST Spriter animation."""

from pathlib import Path
import xml.etree.ElementTree as ET

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "art" / "source" / "element"
OUTPUT = ROOT / "art" / "working" / "wind_burst"
FRAMES = OUTPUT / "lumine_wind_burst"
FRAMES.mkdir(parents=True, exist_ok=True)

KEY_SOURCES = (
    "wind-burst-generated.png",
    "wind-burst-generated.png",
    "wind-burst-generated.png",
    "wind-burst-generated.png",
)


def prepare_key(filename: str) -> Image.Image:
    source = Image.open(SOURCE_DIR / filename).convert("RGBA")
    # A fixed crop keeps the painted cyclone and the ground ring in the same
    # place in every pose. Drop faint background haze from all four sources.
    source = source.crop((250, 0, 1286, 1024))
    source.putalpha(source.getchannel("A").point(
        lambda a: 0 if a < 120 else min(255, round((a - 120) * 255 / 135))))
    body = source.resize((340, 336), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (384, 384), (0, 0, 0, 0))
    canvas.alpha_composite(body, (22, 31))
    return canvas


keys = [prepare_key(filename) for filename in KEY_SOURCES]


def fade_frame(frame: Image.Image, scale: float, alpha: float) -> Image.Image:
    width = round(384 * scale)
    height = round(384 * scale)
    body = frame.resize((width, height), Image.Resampling.LANCZOS)
    body.putalpha(body.getchannel("A").point(lambda a: round(a * alpha)))
    canvas = Image.new("RGBA", (384, 384), (0, 0, 0, 0))
    canvas.alpha_composite(body, ((384 - width) // 2, 384 - height))
    return canvas


files = []
animations = []


def save_frame(key: str, frame: Image.Image) -> int:
    index = len(files)
    filename = f"lumine_wind_burst-{key}.png"
    frame.save(FRAMES / filename)
    files.append(filename)
    return index


opening = [save_frame(f"in-{i}", fade_frame(keys[0], scale, alpha))
           for i, (scale, alpha) in enumerate(((0.62, 0.25), (0.82, 0.65), (1, 1)))]
loop_frames = []
for index in range(4):
    loop_frames.append(keys[index])
    loop_frames.append(Image.blend(keys[index], keys[(index + 1) % 4], 0.5))
looping = [save_frame(f"loop-{i}", frame) for i, frame in enumerate(loop_frames)]
closing = [save_frame(f"out-{i}", fade_frame(keys[0], scale, alpha))
           for i, (scale, alpha) in enumerate(((1, 0.8), (1.07, 0.45), (1.12, 0.12)))]
animations.extend((
    ("in", opening, 300, 100, False),
    ("loop", looping, 800, 100, True),
    ("out", closing, 300, 100, False),
))

data = ET.Element("spriter_data", scml_version="1.0", generator="BrashMonkey Spriter", generator_version="b5")
folder = ET.SubElement(data, "folder", id="0", name="lumine_wind_burst")
for index, filename in enumerate(files):
    ET.SubElement(folder, "file", id=str(index), name=f"lumine_wind_burst/{filename}",
                  width="384", height="384", pivot_x="0.5", pivot_y="0.045")
entity = ET.SubElement(data, "entity", id="0", name="lumine_wind_burst")
for animation_id, (name, frame_ids, length, interval, looping_flag) in enumerate(animations):
    animation = ET.SubElement(entity, "animation", id=str(animation_id), name=name,
                              length=str(length), looping="true" if looping_flag else "false")
    mainline = ET.SubElement(animation, "mainline")
    timeline = ET.SubElement(animation, "timeline", id="0", name="lumine_wind_burst", object_type="sprite")
    for key_id, file_id in enumerate(frame_ids):
        time = key_id * interval
        mainkey = ET.SubElement(mainline, "key", id=str(key_id), time=str(time))
        ET.SubElement(mainkey, "object_ref", id="0", timeline="0", key=str(key_id), z_index="0")
        key = ET.SubElement(timeline, "key", id=str(key_id), time=str(time))
        ET.SubElement(key, "object", folder="0", file=str(file_id), x="0", y="0", angle="0",
                      scale_x="1", scale_y="1")

ET.indent(data)
ET.ElementTree(data).write(OUTPUT / "lumine_wind_burst.scml", encoding="utf-8", xml_declaration=True)
print(OUTPUT / "lumine_wind_burst.scml")
