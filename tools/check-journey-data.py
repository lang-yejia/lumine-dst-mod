"""Static cross-check for legacy milestone IDs, chapter copy, and links."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
progress = (root / "mod/lumine/scripts/lumine_progression.lua").read_text(encoding="utf-8")
chapters = (root / "mod/lumine/scripts/journey/chapters.lua").read_text(encoding="utf-8")
legacy = re.findall(r'\{id="([^"]+)", name=', progress.split("M.EVIDENCE")[0])
copy_block = chapters.split("local copy = {", 1)[1].split("\n}\n", 1)[0]
copy_ids = re.findall(r'^\s+([a-z0-9_]+)=\{', copy_block, re.M)
mod_block = chapters.split("local mod_entries = {", 1)[1].split("\n}\n", 1)[0]
mod_ids = re.findall(r'^\s+\{"(lumine_[^"]+)"', mod_block, re.M)
all_ids = legacy + mod_ids
assert len(legacy) == 20, f"expected 20 legacy IDs, got {len(legacy)}"
assert len(set(all_ids)) == len(all_ids), "duplicate chapter ID"
assert set(copy_ids) == set(legacy), f"copy mismatch: missing={set(legacy)-set(copy_ids)}, extra={set(copy_ids)-set(legacy)}"
links_block = chapters.split("local related = {", 1)[1].split("\n}\n", 1)[0]
links = re.findall(r'([a-z0-9_]+)=\{"([a-z0-9_]+)"', links_block)
assert all(a in all_ids and b in all_ids for a,b in links), "invalid chapter relation"
print(f"Checked {len(legacy)} legacy and {len(mod_ids)} mod chapters; {len(links)} valid links")
