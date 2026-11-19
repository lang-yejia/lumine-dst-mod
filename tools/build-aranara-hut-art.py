"""Prepare original hut/helper cutouts for the DST SCML compiler."""

from pathlib import Path
import xml.etree.ElementTree as ET
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/source/aranara_hut"
WORK = ROOT / "art/working/aranara_hut"


def cutout(name, size, canvas_size, bottom=8):
    image = Image.open(SOURCE / name).convert("RGBA")
    bounds = image.getchannel("A").point(lambda value: 255 if value > 8 else 0).getbbox()
    if bounds is None:
        raise ValueError(f"Empty art: {name}")
    image = image.crop(bounds)
    image.thumbnail(size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", canvas_size)
    canvas.alpha_composite(image, ((canvas_size[0] - image.width) // 2,
                                   canvas_size[1] - image.height - bottom))
    return canvas


def scml(name, dimensions, frames, animations):
    data = ET.Element("spriter_data", scml_version="1.0", generator="BrashMonkey Spriter", generator_version="b5")
    folder = ET.SubElement(data, "folder", id="0", name=name)
    for index in range(frames):
        ET.SubElement(folder, "file", id=str(index), name=f"{name}/{name}-{index}.png",
                      width=str(dimensions[0]), height=str(dimensions[1]), pivot_x="0.5", pivot_y="0.04")
    entity = ET.SubElement(data, "entity", id="0", name=name)
    for anim_id, (anim_name, length, keys) in enumerate(animations):
        animation = ET.SubElement(entity, "animation", id=str(anim_id), name=anim_name,
                                  length=str(length), looping="false" if anim_name in ("appear", "disappear", "idle_wave", "open", "close") else "true")
        mainline = ET.SubElement(animation, "mainline")
        timeline = ET.SubElement(animation, "timeline", id="0", name=name, object_type="sprite")
        for key_id, (time, file_id, x, y, angle, sx, sy) in enumerate(keys):
            ref = ET.SubElement(mainline, "key", id=str(key_id), time=str(time))
            ET.SubElement(ref, "object_ref", id="0", timeline="0", key=str(key_id), z_index="0")
            key = ET.SubElement(timeline, "key", id=str(key_id), time=str(time))
            ET.SubElement(key, "object", folder="0", file=str(file_id), x=str(x), y=str(y),
                          angle=str(angle), scale_x=str(sx), scale_y=str(sy))
    ET.indent(data)
    ET.ElementTree(data).write(WORK / f"{name}.scml", encoding="utf-8", xml_declaration=True)


hut_name = "lumine_aranara_hut"
hut_dir = WORK / hut_name
hut_dir.mkdir(parents=True, exist_ok=True)
hut = cutout("hut-original.png", (344, 340), (384, 384), 6)
hut.save(hut_dir / f"{hut_name}-0.png")
for index, glow_alpha in enumerate((8, 18, 28, 16), 1):
    lit = ImageEnhance.Brightness(hut).enhance(1 + glow_alpha / 260)
    glow = Image.new("RGBA", hut.size)
    draw = ImageDraw.Draw(glow)
    draw.ellipse((127, 229, 257, 356), fill=(255, 213, 112, glow_alpha))
    glow = glow.filter(ImageFilter.GaussianBlur(16))
    lit.alpha_composite(glow)
    lit.save(hut_dir / f"{hut_name}-{index}.png")
cutout("hut-half-open.png", (344, 340), (384, 384), 6).save(hut_dir / f"{hut_name}-5.png")
cutout("hut-open.png", (344, 340), (384, 384), 6).save(hut_dir / f"{hut_name}-6.png")
icon = cutout("hut-original.png", (116, 116), (128, 128), 6)
icon.save(WORK / f"{hut_name}-icon.png")
scml(hut_name, (384, 384), 7, (
    ("idle", 1000, ((0, 0, 0, 0, 0, 1, 1),)),
    ("active", 1600, tuple((i * 400, i + 1, 0, 0, 0, 1, 1) for i in range(4))),
    ("open", 420, ((0, 0, 0, 0, 0, 1, 1), (140, 5, 0, 0, 0, 1, 1),
                   (280, 6, 0, 0, 0, 1, 1))),
    ("open_idle", 1000, ((0, 6, 0, 0, 0, 1, 1),)),
    ("close", 420, ((0, 6, 0, 0, 0, 1, 1), (140, 5, 0, 0, 0, 1, 1),
                    (280, 0, 0, 0, 0, 1, 1))),
))

helper_name = "lumine_aranara"
helper_dir = WORK / helper_name
helper_dir.mkdir(parents=True, exist_ok=True)
idle = cutout("aranara-original.png", (140, 172), (192, 192), 3)
tend = cutout("aranara-tend.png", (140, 172), (192, 192), 3)
walk_left = cutout("aranara-walk-left.png", (140, 172), (192, 192), 3)
walk_right = cutout("aranara-walk-right.png", (140, 172), (192, 192), 3)
run_left = cutout("aranara-run.png", (140, 172), (192, 192), 3)
run_right = cutout("aranara-run-opposite.png", (140, 172), (192, 192), 3)
idle_wave = cutout("aranara-idle-wave.png", (140, 172), (192, 192), 3)
for index, frame in enumerate((idle, tend, walk_left, walk_right, run_left, run_right, idle_wave)):
    frame.save(helper_dir / f"{helper_name}-{index}.png")
scml(helper_name, (192, 192), 7, (
    ("idle", 1400, ((0, 0, 0, 0, -2, 1, 1), (350, 0, 0, 3, 0, 1, 1),
                     (700, 0, 0, 5, 2, 1, 1), (1050, 0, 0, 2, 0, 1, 1))),
    ("walk", 720, ((0, 0, 0, 0, 0, 1, 1), (180, 2, 0, 3, -2, 1, 1),
                   (360, 0, 0, 0, 0, 1, 1), (540, 3, 0, 3, 2, 1, 1))),
    ("run", 420, ((0, 4, 0, 3, -3, 1, 1), (105, 0, 0, 0, 0, 1, 1),
                  (210, 5, 0, 3, 3, 1, 1), (315, 0, 0, 0, 0, 1, 1))),
    ("idle_wave", 1400, ((0, 0, 0, 0, 0, 1, 1), (350, 6, 0, 2, 4, 1, 1),
                         (700, 6, 0, 0, -3, 1, 1), (1050, 0, 0, 0, 0, 1, 1))),
    ("tend", 1200, ((0, 0, 0, 0, 0, 1, 1), (250, 1, 0, -2, 4, 1, 1),
                    (600, 1, 0, 0, -2, 1, 1), (900, 0, 0, 0, 0, 1, 1))),
    ("appear", 550, ((0, 0, 0, -25, 0, .2, .2), (220, 0, 0, -9, -7, .7, .7),
                     (440, 0, 0, 0, 0, 1, 1))),
    ("disappear", 550, ((0, 0, 0, 0, 0, 1, 1), (220, 0, 0, -9, 7, .7, .7),
                        (440, 0, 0, -25, 0, .2, .2))),
))
print(WORK)
