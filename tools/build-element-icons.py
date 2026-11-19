"""Prepare transparent, square element skill art for DST's png compiler."""

from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "art" / "source" / "element"

for name in ("wind-passive", "wind-dash", "wind-tornado"):
    source = Image.open(ART / f"{name}-generated.png").convert("RGBA")
    alpha = source.getchannel("A")
    bounds = alpha.point(lambda value: 255 if value > 12 else 0).getbbox()
    if bounds is None:
        raise ValueError(f"Empty source icon: {name}")
    icon = source.crop(bounds)
    icon.thumbnail((112, 112), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    canvas.alpha_composite(icon, ((128 - icon.width) // 2, (128 - icon.height) // 2))
    canvas.save(ART / f"{name}.png")
    print(ART / f"{name}.png")
