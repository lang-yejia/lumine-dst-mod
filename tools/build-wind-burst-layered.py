"""Build a layered wind burst with three independently paced rotations."""

from pathlib import Path
import math
import xml.etree.ElementTree as ET

from PIL import Image, ImageChops, ImageDraw, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "art" / "source" / "element"
OUT = ROOT / "art" / "working" / "wind_burst_layered"
FRAMES = OUT / "lumine_wind_burst"
FRAMES.mkdir(parents=True, exist_ok=True)
SIZE = (384, 384)
LOOP_FRAMES = 48  # ribbon: 1 turn, ground light: 2 turns, core: 1 turn


def clean(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    image.putalpha(image.getchannel("A").point(
        lambda a: 0 if a < 110 else min(255, round((a - 110) * 255 / 145))))
    return image


def full_layer(name: str) -> Image.Image:
    source = clean(Image.open(SRC / name).crop((250, 0, 1286, 1024)))
    body = source.resize((340, 336), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", SIZE)
    canvas.alpha_composite(body, (22, 31))
    return canvas


core = full_layer("wind-layer-core.png")
ground = full_layer("wind-layer-ground.png")
ribbon_source = clean(Image.open(SRC / "wind-layer-ribbon.png"))
bounds = ribbon_source.getchannel("A").getbbox()
if bounds is None:
    raise ValueError("Ribbon layer is empty")
ribbon_source = ribbon_source.crop(bounds)


def draw_ribbon(canvas: Image.Image, size: tuple[int, int], center_y: int,
                angle: float, front: bool) -> None:
    width = max(10, round(size[0] * (0.38 + 0.62 * abs(math.cos(angle)))))
    height = size[1]
    ribbon = ribbon_source.resize((width, height), Image.Resampling.LANCZOS)
    if math.cos(angle) < 0:
        ribbon = ImageOps.mirror(ribbon)
    split = round(height * 0.51)
    if front:
        ribbon.paste((0, 0, 0, 0), (0, 0, width, split))
    else:
        ribbon.paste((0, 0, 0, 0), (0, split, width, height))
    # Keep every ring's geometric center on the wind axis. The former side-to-
    # side orbit made the whole ring appear to rotate around an offset pivot.
    x = round(192 - width / 2)
    y = center_y - height // 2
    canvas.alpha_composite(ribbon, (x, y))


def ground_frame(phase: float) -> Image.Image:
    canvas = ground.copy()
    accent = Image.new("RGBA", SIZE)
    draw = ImageDraw.Draw(accent)
    points = []
    for step in range(20):
        angle = phase + step / 19 * 0.52
        points.append((192 + 130 * math.cos(angle), 340 + 14 * math.sin(angle)))
    draw.line(points, fill=(224, 255, 204, 145), width=5, joint="curve")
    accent.putalpha(ImageChops.multiply(accent.getchannel("A"), ground.getchannel("A")))
    canvas.alpha_composite(accent)
    return canvas


def rotated_core(phase: float) -> Image.Image:
    canvas = Image.new("RGBA", SIZE)
    for y in range(384):
        shift = round(6 * math.sin(phase + y / 65))
        canvas.alpha_composite(core.crop((0, y, 384, y + 1)), (shift, y))
    streak = Image.new("RGBA", SIZE)
    draw = ImageDraw.Draw(streak)
    points = [(round(192 + 24 * math.sin(phase + y / 70)), y) for y in range(75, 327, 8)]
    draw.line(points, fill=(236, 255, 222, 90), width=5, joint="curve")
    streak.putalpha(ImageChops.multiply(streak.getchannel("A"), canvas.getchannel("A")))
    canvas.alpha_composite(streak)
    return canvas


def loop_frame(index: int) -> Image.Image:
    phase = 2 * math.pi * index / LOOP_FRAMES
    ribbon_phase = phase
    core_phase = phase
    canvas = ground_frame(phase * 2)
    bands = ((118, (286, 85), 0), (210, (300, 86), 2 * math.pi / 3),
             (288, (230, 62), 4 * math.pi / 3))
    for y, size, offset in bands:
        draw_ribbon(canvas, size, y, ribbon_phase + offset, False)
    canvas.alpha_composite(rotated_core(core_phase))
    for y, size, offset in bands:
        draw_ribbon(canvas, size, y, ribbon_phase + offset, True)
    return canvas


def fade(frame: Image.Image, scale: float, opacity: float) -> Image.Image:
    width = round(SIZE[0] * scale)
    height = round(SIZE[1] * scale)
    body = frame.resize((width, height), Image.Resampling.LANCZOS)
    body.putalpha(body.getchannel("A").point(lambda a: round(a * opacity)))
    canvas = Image.new("RGBA", SIZE)
    canvas.alpha_composite(body, ((SIZE[0] - width) // 2, SIZE[1] - height))
    return canvas


files = []


def save(name: str, image: Image.Image) -> int:
    index = len(files)
    filename = f"lumine_wind_burst-{name}.png"
    image.save(FRAMES / filename)
    files.append(filename)
    return index


first = loop_frame(0)
opening = [save(f"in-{i}", fade(first, scale, opacity))
           for i, (scale, opacity) in enumerate(((0.62, 0.25), (0.82, 0.65), (1, 1)))]
looping = [save(f"loop-{i}", loop_frame(i)) for i in range(LOOP_FRAMES)]
closing = [save(f"out-{i}", fade(first, scale, opacity))
           for i, (scale, opacity) in enumerate(((1, 0.8), (1.07, 0.45), (1.12, 0.12)))]

data = ET.Element("spriter_data", scml_version="1.0", generator="BrashMonkey Spriter", generator_version="b5")
folder = ET.SubElement(data, "folder", id="0", name="lumine_wind_burst")
for index, filename in enumerate(files):
    ET.SubElement(folder, "file", id=str(index), name=f"lumine_wind_burst/{filename}",
                  width="384", height="384", pivot_x="0.5", pivot_y="0.045")
entity = ET.SubElement(data, "entity", id="0", name="lumine_wind_burst")
for anim_id, (name, frames, interval) in enumerate((("in", opening, 100), ("loop", looping, 60),
                                                    ("out", closing, 100))):
    animation = ET.SubElement(entity, "animation", id=str(anim_id), name=name,
                              length=str(len(frames) * interval), looping="true" if name == "loop" else "false")
    mainline = ET.SubElement(animation, "mainline")
    timeline = ET.SubElement(animation, "timeline", id="0", name="lumine_wind_burst", object_type="sprite")
    for key_id, file_id in enumerate(frames):
        time = key_id * interval
        mainkey = ET.SubElement(mainline, "key", id=str(key_id), time=str(time))
        ET.SubElement(mainkey, "object_ref", id="0", timeline="0", key=str(key_id), z_index="0")
        key = ET.SubElement(timeline, "key", id=str(key_id), time=str(time))
        ET.SubElement(key, "object", folder="0", file=str(file_id), x="0", y="0", angle="0",
                      scale_x="1", scale_y="1")

ET.indent(data)
ET.ElementTree(data).write(OUT / "lumine_wind_burst.scml", encoding="utf-8", xml_declaration=True)
print(OUT / "lumine_wind_burst.scml")
