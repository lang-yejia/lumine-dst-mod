"""Format generated sword artwork into DST inventory and Spriter assets."""

from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/source/weapons"
OUTPUT = ROOT / "art/working/weapons"
TEMPLATE = ROOT / "reference/workshop-3808204425/sword-template.scml"
NAMES = (
    "lumine_dull_blade",
    "lumine_harbinger_of_dawn",
    "lumine_prototype_rancour",
    "lumine_aquila_favonia",
)


def draw(source: Image.Image, size: tuple[int, int], height: int) -> Image.Image:
    width, canvas_height = size
    sword = source.copy()
    sword.thumbnail((width - 12, height), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.alpha_composite(sword, ((width - sword.width) // 2, (canvas_height - sword.height) // 2))
    return canvas


for name in NAMES:
    source = Image.open(SOURCE / f"{name}.png").convert("RGBA")
    alpha = source.getchannel("A")
    # Ignore faint generation residue outside the sword silhouette.
    mask = alpha.point(lambda a: 255 if a > 16 else 0)
    bounds = mask.getbbox()
    if bounds is None:
        raise ValueError(f"Empty artwork: {name}")
    source = source.crop(bounds)
    folder = OUTPUT / name
    world = folder / name
    swap = folder / f"swap_{name}"
    world.mkdir(parents=True, exist_ok=True)
    swap.mkdir(parents=True, exist_ok=True)
    draw(source, (128, 248), 224).save(world / f"{name}-0.png")
    held = draw(source, (128, 320), 280)
    for index in range(7):
        held.save(swap / f"swap_{name}-{index}.png")
    # Leave room for the crafting preview's own scaling and frame padding.
    icon_sword = source.copy()
    icon_sword.thumbnail((70, 94), Image.Resampling.LANCZOS)
    icon_sword = icon_sword.rotate(-35, Image.Resampling.BICUBIC, expand=True)
    icon_sword.thumbnail((94, 94), Image.Resampling.LANCZOS)
    icon = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    icon.alpha_composite(icon_sword, ((128 - icon_sword.width) // 2, (128 - icon_sword.height) // 2))
    icon.save(folder / f"{name}-icon.png")
    scml = TEMPLATE.read_text(encoding="utf-8").replace("lumine_descension_sword", name)
    (folder / f"{name}.scml").write_text(scml, encoding="utf-8")
    print(f"{name}: {source.width}x{source.height} source, 1 ground + 7 held + icon")
