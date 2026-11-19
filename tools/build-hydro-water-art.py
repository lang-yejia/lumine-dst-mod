"""Compile loops for the Hydro water surfaces and their skill icon overlays."""

from math import cos, pi, sin
from pathlib import Path
import xml.etree.ElementTree as ET

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
NAME = "lumine_hydro_water"
SOURCE = ROOT / "art/source/element/hydro-water-sprites.png"
OUTPUT = ROOT / ".build/hydro_water/art"
TAU = 2 * pi


def crop_sprite(sheet, index, size):
    left, right = index * sheet.width // 2, (index + 1) * sheet.width // 2
    sprite = sheet.crop((left, 0, right, sheet.height))
    sprite.putalpha(sprite.getchannel("A").point(lambda value: value if value > 8 else 0))
    bounds = sprite.getchannel("A").getbbox()
    if not bounds or any(value == edge for value, edge in zip(bounds, (0, 0, *sprite.size))):
        raise ValueError(f"Hydro sprite {index} needs a transparent edge")
    sprite = sprite.crop(bounds)
    sprite.thumbnail(size, Image.Resampling.LANCZOS)
    return sprite


def water_surface(sprite, inner_mask, phase, is_orb):
    width, height = sprite.size

    def sample(x, y):
        u, v = x / width, y / height
        horizontal = (.078 if is_orb else .083) * sin(phase - v * TAU + u * 3)
        vertical = (.046 if is_orb else .028) * cos(phase + u * TAU - v * 4)
        return x + width * horizontal, y + height * vertical

    mesh = []
    for row in range(10):
        top, bottom = row * height // 10, (row + 1) * height // 10
        for column in range(10):
            left, right = column * width // 10, (column + 1) * width // 10
            quad = (*sample(left, top), *sample(left, bottom),
                    *sample(right, bottom), *sample(right, top))
            mesh.append(((left, top, right, bottom), quad))
    current = sprite.transform(sprite.size, Image.Transform.MESH, mesh, Image.Resampling.BICUBIC)
    result = Image.composite(current, sprite, inner_mask)
    result.putalpha(sprite.getchannel("A"))

    # Move a translucent reflection through the darker body of each sprite.
    light = Image.new("RGBA", sprite.size)
    draw = ImageDraw.Draw(light)
    y = height * (.29 + .13 * sin(phase))
    draw.arc((width * .16, y, width * .78, y + height * .39), 185, 280,
             fill=(141, 225, 244, round(58 + 18 * cos(phase))), width=3 if is_orb else 1)
    light.putalpha(Image.composite(light.getchannel("A"), Image.new("L", sprite.size), inner_mask))
    result.alpha_composite(light)
    result.putalpha(sprite.getchannel("A"))
    return result


def skill_overlay(skill, t):
    image = Image.new("RGBA", (256, 256))
    draw = ImageDraw.Draw(image)

    def colour(strength):
        return (171, 232, 250, round(strength * sin(pi * t) ** 2))

    if skill == "hydro_drop":
        for index in range(2):
            radius = 12 + index * 9 + 15 * t
            draw.arc((2 * (64 - radius), 174 - radius * .26, 2 * (64 + radius), 174 + radius * .26),
                     8, 173, fill=colour(175 - 32 * index), width=3)
    elif skill == "hydro_stream":
        x, y = 90 + 97 * t, 178 - 94 * t
        draw.line((x - 11, y + 10, x + 12, y - 12), fill=colour(235), width=4)
        draw.line((x - 23, y + 15, x - 8, y + 1), fill=colour(150), width=3)
    else:
        for index in range(3):
            phase = (t + index / 3) % 1
            x = 105 + 21 * index + 7 * sin(phase * TAU)
            y = 138 - (38 + 9 * index) * phase
            radius = 3.5 + 3 * phase
            tint = (165, 229, 248, round(172 * sin(pi * phase) ** 2))
            draw.ellipse((x - radius, y - radius, x + radius, y + radius), outline=tint, width=2)
    return image.resize((128, 128), Image.Resampling.LANCZOS)


def add_animation(entity, name, frames, period, looping):
    animation = ET.SubElement(entity, "animation", id=str(len(entity)), name=name,
                              length=str(period), looping="true" if looping else "false")
    mainline = ET.SubElement(animation, "mainline")
    timeline = ET.SubElement(animation, "timeline", id="0", name=name, object_type="sprite")
    for index, (time, file_id, x, y, scale_x, scale_y) in enumerate(frames):
        key = ET.SubElement(mainline, "key", id=str(index), time=str(time))
        ET.SubElement(key, "object_ref", id="0", timeline="0", key=str(index), z_index="0")
        key = ET.SubElement(timeline, "key", id=str(index), time=str(time))
        ET.SubElement(key, "object", folder="0", file=file_id, x=str(x), y=str(y),
                      scale_x=str(scale_x), scale_y=str(scale_y))


def add_loop(folder, entity, name, frames, period, pivot_y):
    keys = []
    for index, (sprite, y) in enumerate(frames):
        file_id = str(len(folder))
        filename = f"{NAME}/{name}-{index:02d}.png"
        sprite.save(OUTPUT / filename)
        ET.SubElement(folder, "file", id=file_id, name=filename,
                      width=str(sprite.width), height=str(sprite.height), pivot_x=".5", pivot_y=pivot_y)
        keys.append((round(index * period / len(frames)), file_id, 0, y, 1, 1))
    add_animation(entity, name, keys, period, True)
    return [key[1] for key in keys]


def main():
    with Image.open(SOURCE) as source:
        sheet = source.convert("RGBA")
    (OUTPUT / NAME).mkdir(parents=True, exist_ok=True)
    data = ET.Element("spriter_data", scml_version="1.0", generator="BrashMonkey Spriter", generator_version="b5")
    folder = ET.SubElement(data, "folder", id="0", name=NAME)
    entity = ET.SubElement(data, "entity", id="0", name=NAME)

    for index, (name, size, count, period) in enumerate((
        ("orb", (222, 222), 24, 1800), ("drop", (51, 71), 20, 1800),
    )):
        sprite = crop_sprite(sheet, index, size)
        is_orb = index == 0
        mask = sprite.getchannel("A").filter(ImageFilter.MinFilter(25 if is_orb else 9))
        mask = mask.filter(ImageFilter.GaussianBlur(3 if is_orb else 1))
        phases = [TAU * frame / count for frame in range(count)]
        baseline, amplitude = (9, 3) if is_orb else (18, 12)
        frames = [(water_surface(sprite, mask, phase, is_orb),
                   baseline + amplitude * sin(phase)) for phase in phases]
        files = add_loop(folder, entity, name, frames, period, "0")
        if is_orb:
            # Render-only recoil. Keep the visual centre raised as the sphere compresses.
            add_animation(entity, "orb_hit", (
                (0, files[0], 0, 9, 1, 1),
                (55, files[1], -12, 27, .79, .83),
                (105, files[2], 10, 21, .85, .88),
                (155, files[3], -7, 12, .97, .96),
                (220, files[4], 4, 7, 1.045, 1.025),
                (280, files[2], -2, 10, .99, 1),
                (330, files[0], 0, 9, 1, 1),
            ), 360, False)

    for skill, period in (("hydro_drop", 1400), ("hydro_stream", 1100), ("hydro_bubble", 1500)):
        frames = [(skill_overlay(skill, (frame + .5) / 20), 0) for frame in range(20)]
        add_loop(folder, entity, skill, frames, period, ".5")

    ET.indent(data)
    ET.ElementTree(data).write(OUTPUT / f"{NAME}.scml", encoding="utf-8", xml_declaration=True)


if __name__ == "__main__":
    main()
