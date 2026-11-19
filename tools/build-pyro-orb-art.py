"""Compile the fireball with its painted centre at the entity origin."""

import argparse
from math import sin, tau
from pathlib import Path
from shutil import copy2
from subprocess import run
from tempfile import TemporaryDirectory
import xml.etree.ElementTree as ET

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
NAME = "lumine_pyro_orb"
SOURCE = ROOT / "art/source/element/pyro-fireball.png"
DEFAULT_COMPILER = Path("F:/SteamLibrary/steamapps/common/Don't Starve Mod Tools/mod_tools/scml.exe")


def write_scml(folder):
    with Image.open(SOURCE) as source:
        sprite = source.convert("RGBA")
    alpha = sprite.getchannel("A").point(lambda value: value if value > 8 else 0)
    sprite.putalpha(alpha)
    bounds = alpha.getbbox()
    if not bounds or any(value == edge for value, edge in zip(bounds, (0, 0, *sprite.size))):
        raise ValueError("The fireball needs a transparent margin on every side")
    sprite = sprite.crop(bounds)
    sprite.thumbnail((112, 112), Image.Resampling.LANCZOS)
    # Plain square padding preserves the geometric centre through atlas trimming.
    frame = Image.new("RGBA", (128, 128))
    frame.alpha_composite(sprite, ((128 - sprite.width) // 2, (128 - sprite.height) // 2))
    (folder / NAME).mkdir()
    filename = f"{NAME}/orb.png"
    frame.save(folder / filename)

    data = ET.Element("spriter_data", scml_version="1.0", generator="BrashMonkey Spriter", generator_version="b5")
    images = ET.SubElement(data, "folder", id="0", name=NAME)
    ET.SubElement(images, "file", id="0", name=filename, width="128", height="128", pivot_x=".5", pivot_y=".5")
    entity = ET.SubElement(data, "entity", id="0", name=NAME)
    clip = ET.SubElement(entity, "animation", id="0", name="idle_loop", length="480", looping="true")
    main = ET.SubElement(clip, "mainline")
    timeline = ET.SubElement(clip, "timeline", id="0", name="orb", object_type="sprite")
    for index in range(12):
        key = str(index)
        time = str(index * 40)
        swing = sin(tau * index / 12)
        main_key = ET.SubElement(main, "key", id=key, time=time)
        ET.SubElement(main_key, "object_ref", id="0", timeline="0", key=key, z_index="0")
        timeline_key = ET.SubElement(timeline, "key", id=key, time=time)
        ET.SubElement(timeline_key, "object", folder="0", file="0", x="0", y="0",
                      scale_x=f"{1 + .045 * swing:.4f}", scale_y=f"{1 - .045 * swing:.4f}")
    scml = folder / f"{NAME}.scml"
    ET.ElementTree(data).write(scml, encoding="utf-8", xml_declaration=True)
    return scml


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiler", type=Path, default=DEFAULT_COMPILER)
    args = parser.parse_args()
    with TemporaryDirectory(prefix="LuminePyroOrb-") as temp:
        folder = Path(temp)
        scml = write_scml(folder)
        run((str(args.compiler), str(scml), str(folder)), check=True)
        copy2(folder / "anim" / f"{NAME}.zip", ROOT / "mod/lumine/anim" / f"{NAME}.zip")


if __name__ == "__main__":
    main()
