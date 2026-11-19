"""Create a separate, usable copy of krane's Paimon sprite export.

The compiled source atlas has opaque RGB-black padding on several frame
rectangles. Keep model-export/ untouched and clean only the preview copy.
"""
from pathlib import Path
import shutil
from collections import deque
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1] / "reference/workshop-3808204425/paimon"
SOURCE = ROOT / "model-export"
TARGET = ROOT / "model-export-clean"
TARGET.mkdir(exist_ok=True)
shutil.copy2(SOURCE / "lumine_paimon.scml", TARGET / "lumine_paimon.scml")

images = sorted(SOURCE.glob("*/*.png"))
for path in images:
    image = Image.open(path).convert("RGBA")
    width, height = image.size
    mask = [a > 0 and max(r, g, b) <= 8 for r, g, b, a in image.getdata()]
    visited = bytearray(width * height)
    remove = set()
    for start, black in enumerate(mask):
        if not black or visited[start]:
            continue
        queue = deque([start])
        visited[start] = 1
        component = []
        touches_edge = False
        min_x = min_y = 10**9
        max_x = max_y = 0
        while queue:
            index = queue.popleft()
            x, y = index % width, index // width
            component.append(index)
            touches_edge = touches_edge or x == 0 or y == 0 or x == width - 1 or y == height - 1
            min_x, min_y = min(min_x, x), min(min_y, y)
            max_x, max_y = max(max_x, x), max(max_y, y)
            for next_index in (index - 1 if x else -1,
                               index + 1 if x < width - 1 else -1,
                               index - width if y else -1,
                               index + width if y < height - 1 else -1):
                if next_index >= 0 and mask[next_index] and not visited[next_index]:
                    visited[next_index] = 1
                    queue.append(next_index)
        # Padding blocks are large solid-black areas anchored to atlas frame
        # edges. Fine dark character linework remains untouched.
        if (touches_edge and len(component) >= 400 and max_x - min_x >= 15 and max_y - min_y >= 15) or (path.parent.name in {"blink_down", "blink_side", "eat_down"} and len(component) >= 500 and max_x - min_x >= 20 and max_y - min_y >= 20):
            remove.update(component)
    pixels = image.load()
    for index in remove:
        pixels[index % width, index // width] = (0, 0, 0, 0)
    output = TARGET / path.parent.name / path.name
    output.parent.mkdir(exist_ok=True)
    image.save(output)

font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 16)
sheet = Image.new("RGB", (240 * 4, 300 * 5), (220, 215, 200))
draw = ImageDraw.Draw(sheet)
for index, path in enumerate(sorted(TARGET.glob("*/*.png"))):
    image = Image.open(path).convert("RGBA")
    image.thumbnail((210, 245))
    x = index % 4 * 240 + (240 - image.width) // 2
    y = index // 4 * 300 + 28
    sheet.paste(image, (x, y), image)
    draw.text((index % 4 * 240 + 10, index // 4 * 300 + 8), path.parent.name, fill=(30, 25, 25), font=font)
sheet.save(ROOT / "preview-contact-clean.png")
print(f"Cleaned {len(images)} sprites")
