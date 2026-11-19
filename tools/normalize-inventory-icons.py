"""Unify Lumine inventory/crafting icon occupancy without changing world art."""

from pathlib import Path
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
INVENTORY = ROOT / "mod/lumine/images/inventoryimages"
ART = ROOT / "art/working"
OUTPUT = ART / "inventory_normalized"
OUTPUT.mkdir(parents=True, exist_ok=True)


def find_source(name):
    if name in ("lumine_wind_orb", "lumine_geo_orb"):
        # Legacy save items use the same neutral orb art as the current prefab.
        return ART / "element_energy/icons/lumine_element_orb.png"
    candidates = list(ART.rglob(name + "-icon.png")) + list(ART.rglob(name + ".png"))
    candidates = [p for p in candidates if OUTPUT not in p.parents]
    return candidates[0] if candidates else None


missing = []
for atlas in sorted(INVENTORY.glob("*.xml")):
    name = atlas.stem
    source = find_source(name)
    if source is None:
        missing.append(name)
        continue
    image = Image.open(source).convert("RGBA")
    alpha = image.getchannel("A")
    bounds = alpha.point(lambda value: 255 if value > 16 else 0).getbbox()
    if bounds is None:
        raise ValueError(f"Empty icon: {source}")
    crop = image.crop(bounds)
    crop.thumbnail((96, 96), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (128, 128))
    canvas.alpha_composite(crop, ((128 - crop.width) // 2, (128 - crop.height) // 2))
    canvas.save(OUTPUT / (name + ".png"))

print(f"Prepared {len(list(OUTPUT.glob('*.png')))} consistent 128px icons with 96px art bounds")
if missing:
    print("No editable source:", ", ".join(missing))
