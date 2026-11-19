"""Check image references used by the travel journal against DST and mod atlases."""
import argparse
from functools import cache
import os
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET
import zipfile

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / ".tools/journey-lua"))
try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    sys.exit("Run the Lua 5.1 dependency setup in tests/README.md first.")

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--dst-root", type=Path, default=os.environ.get("DST_ROOT"))
parser.add_argument("--mapping", type=Path, help="Write the verified chapter and encounter image mapping in Markdown.")
args = parser.parse_args()
game = args.dst_root or Path("F:/SteamLibrary/steamapps/common/Don't Starve Together")
bundles = game / "data/databundles"
try:
    images = zipfile.ZipFile(bundles / "images.zip")
    scripts = zipfile.ZipFile(bundles / "scripts.zip")
except (OSError, zipfile.BadZipFile) as exc:
    sys.exit(f"Resource check needs an installed DST archive. Set --dst-root. {exc}")

@cache
def atlas_icons(atlas):
    vanilla = not (root / "mod/lumine" / atlas).is_file()
    if vanilla:
        if atlas not in images.namelist():
            return (), "atlas missing"
        data = images.read(atlas)
    else:
        path = root / "mod/lumine" / atlas
        if not path.is_file():
            return (), "atlas missing"
        data = path.read_bytes()
    try:
        xml = ET.fromstring(data)
    except ET.ParseError as exc:
        return (), str(exc)
    texture = xml.find("Texture")
    if texture is None or not texture.get("filename"):
        return (), "texture missing from atlas"
    texture_path = Path(atlas).parent / texture.get("filename")
    if vanilla and texture_path.as_posix() not in images.namelist() and not (game / "data" / texture_path).is_file():
        return (), f"texture missing: {texture_path}"
    if not vanilla and not (root / "mod/lumine" / texture_path).is_file():
        return (), f"texture missing: {texture_path}"
    return {e.get("name") for e in xml.iter("Element")}, "image missing"

def has_icon(atlas, icon):
    names, reason = atlas_icons(atlas)
    return icon in names, reason

def lookup(prefix, count, tex):
    return next((atlas for i in range(1, count + 1)
                 if has_icon(atlas := f"images/{prefix}{i}.xml", tex)[0]), None)

runtime = LuaRuntime(unpack_returned_tuples=True)

def read_module(name):
    relative = name.replace(".", "/") + ".lua"
    if relative == "screens/redux/scrapbookdata.lua":
        return scripts.read("scripts/" + relative).decode("utf-8"), "@" + relative
    return (root / "mod/lumine/scripts" / relative).read_text(encoding="utf-8-sig"), "@" + relative

runtime.eval("""function(read)
    table.insert(package.loaders, 2, function(name)
        local source, path = read(name)
        return assert(loadstring(source, path))
    end)
end""")(read_module)
runtime.globals().GetScrapbookIconAtlas = lambda tex: lookup("scrapbook_icons", 3, tex)
runtime.globals().GetInventoryItemAtlas = lambda tex, _: lookup("inventoryimages", 4, tex)
catalog = runtime.eval('require("journey/catalog")')
artifacts = runtime.eval('require("lumine_artifact_data")')
forge = runtime.eval('require("lumine_forging_data")')
native = runtime.eval('require("journey/native_art")')
bosses = runtime.eval('require("journey/boss_guides")')
routes = runtime.eval('require("journey/expedition_routes")')
scrapbook = runtime.eval('require("screens/redux/scrapbookdata")')
prefab_files = set(scripts.namelist())
prefab_sources = [scripts.read(path).decode("utf-8", errors="replace")
                  for path in prefab_files if path.startswith("scripts/prefabs/") and path.endswith(".lua")]
prefab_definitions = {name for source in prefab_sources
                      for name in re.findall(r'\bPrefab\(\s*"([a-z0-9_]+)"\s*,', source)}

issues = []
checked = 0
animations = 0
chapter_rows = []
boss_rows = []

def check_icon(chapter_id, atlas, tex):
    global checked
    ok, reason = has_icon(atlas, tex)
    checked += 1
    if not ok:
        issues.append((chapter_id, atlas, tex, reason))

def check_item(chapter_id, prefab):
    check_icon(chapter_id, f"images/inventoryimages/{prefab}.xml", f"{prefab}.tex")

def check_native(label, key):
    image = native.Get(key)
    if image:
        check_icon(label, image.atlas, image.tex)
    else:
        issues.append((label, key, "native image missing"))
    return image

def check_prefab(label, key):
    # A Scrapbook row also confirms dynamically named vanilla prefabs.
    if not scrapbook[key] and key not in prefab_definitions and f"scripts/prefabs/{key}.lua" not in prefab_files:
        issues.append((label, key, "prefab definition missing"))

def check_materials(label, items):
    if items is None:
        return
    for item in items.values():
        check_prefab(label, item[1])
        check_native(label, item[1])
        if item[2] is not None and (not isinstance(item[2], int) or item[2] < 1):
            issues.append((label, item[1], "invalid quantity"))

for volume in catalog.volumes.values():
    for chapter in volume.entries.values():
        key = native.chapters[chapter.id]
        image = check_native(chapter.id, key) if key else chapter.image
        if image is None:
            continue
        if image.anim:
            animations += 1
            path = root / f"mod/lumine/anim/{image.anim}.zip"
            try:
                with zipfile.ZipFile(path) as anim:
                    if image.clip.encode() not in anim.read("anim.bin"):
                        issues.append((chapter.id, path.name, f"animation not found: {image.clip}"))
            except (OSError, zipfile.BadZipFile, KeyError) as exc:
                issues.append((chapter.id, path.name, str(exc)))
            chapter_rows.append((chapter.title, image.anim, "模组动画", f"anim/{image.anim}.zip · {image.clip}", "已接入"))
        elif not key:
            check_icon(chapter.id, image.atlas, image.tex)
        if not image.anim:
            art_type = ("原版 Scrapbook" if "scrapbook_icons" in image.atlas else
                        "原版物品图标，图鉴无独立图像" if key else "模组专用")
            chapter_rows.append((chapter.title, key or image.tex.removesuffix(".tex"), art_type,
                                 f"{image.atlas} · {image.tex}", "已接入"))
        if chapter.relic_set:
            for piece in artifacts.ALL.values():
                if piece.set == chapter.relic_set:
                    check_item(chapter.id, piece.prefab)
        if chapter.routes:
            for route in chapter.routes.values():
                for prefab in route.values():
                    check_item(chapter.id, prefab)
        if chapter.seasons:
            for season in chapter.seasons.values():
                check_icon(chapter.id, "images/inventoryimages.xml", season.icon + ".tex")
check_native("home", "campfire")
check_item("book cover", "lumine_journal")
for tex in ("scrap_square.tex", "scrap_wide.tex", "scrap2_wide.tex", "scrap2_square.tex",
            "scrap2_tall.tex", "tab.tex", "tab_over.tex", "tab_selected.tex"):
    check_icon("book style", "images/scrapbook.xml", tex)
for tex in ("button_long.tex", "button_long_highlight.tex", "button_long_disabled.tex", "button_long_down.tex"):
    check_icon("book style", "images/frontend.xml", tex)
check_icon("book style", "images/ui.xml", "white.tex")
for prefab in forge.ORDER.values():
    check_icon("forge requirement", catalog.forge_icons[prefab] or "images/inventoryimages.xml", prefab + ".tex")

boss_count = 0
seen_bosses = set()
for group in bosses.groups.values():
    for boss in group.entries.values():
        boss_count += 1
        if boss.id in seen_bosses or boss.id not in bosses.by_id or boss.group != group.title:
            issues.append((boss.id, "duplicate or invalid boss index"))
        seen_bosses.add(boss.id)
        check_prefab(boss.id, boss.id)
        image = check_native(boss.id, boss.image)
        if image:
            boss_rows.append((group.title, boss.title, boss.id, boss.kind, f"{image.atlas} · {image.tex}"))
        for field in ("title", "where", "trigger", "prep", "fight", "loot", "next_step"):
            if not boss[field]:
                issues.append((boss.id, field, "boss field missing"))
        if boss.route and boss.route not in routes:
            issues.append((boss.id, boss.route, "route missing"))
        for target in boss.related.values() if boss.related else ():
            if target not in bosses.by_id:
                issues.append((boss.id, target, "related boss missing"))
        check_materials(boss.id, boss["items"])

# Reconcile Klei's giant entries with grouped guides and phase/variant pages.
grouped = {
    "alterguardian_phase1": "alterguardian_phase3",
    "shadow_bishop": "shadow_knight",
    "shadow_rook": "shadow_knight",
    "twinofterror2": "twinofterror1",
}
for key, entry in sorted(scrapbook.items()):
    if entry.type == "giant" and grouped.get(key, key) not in seen_bosses:
        issues.append((key, "native Scrapbook giant has no guide"))

required_routes = {
    "lunar": {"altar", "sanctum", "tribute", "triangle", "wagstaff", "siphon", "upgrade",
              "champion", "rift", "mutations", "map", "relocate", "floor", "cages",
              "revenant", "robot", "scion", "base", "replay"},
    "shadow": {"key", "gate", "fossils", "atrium", "weaver", "repair", "sanctum_key", "ritual",
               "friend", "larynx", "claw", "guts", "queen", "abomination", "shadow_replay"},
}
if set(routes.keys()) != set(required_routes):
    issues.append(("expedition_routes.lua", "missing or unexpected main routes"))
route_steps = 0
for route_id, route in sorted(routes.items()):
    seen_steps = set()
    for stage in route.stages.values():
        if not stage.title or len(stage.lanes) not in (1, 2, 3):
            issues.append((route_id, stage.title or "", "invalid route stage"))
        for lane in stage.lanes.values():
            if not lane.title or not 1 <= len(lane.steps) <= 6:
                issues.append((route_id, stage.title, "invalid route branch"))
            for step in lane.steps.values():
                route_steps += 1
                if step.id in seen_steps or not step.title or not step.text:
                    issues.append((route_id, step.id, "duplicate or incomplete route node"))
                seen_steps.add(step.id)
                if step.boss and step.boss not in bosses.by_id:
                    issues.append((route_id, step.id, "linked boss missing"))
                check_native(f"{route_id}/{step.id}", step.image)
                check_materials(f"{route_id}/{step.id}", step["items"])
    for step in sorted(required_routes.get(route_id, set()) - seen_steps):
        issues.append((route_id, step, "required route step missing"))

evidence = set(runtime.eval('require("lumine_progression").BY_EVIDENCE').keys())
# The three boss sketches are generated by sketch.lua rather than individual prefab files.
sketches = set(re.findall(r'item\s*=\s*"(chesspiece_[a-z0-9_]+)"',
                          scripts.read("scripts/prefabs/sketch.lua").decode("utf-8")))
for prefab in sorted(evidence):
    if (f"scripts/prefabs/{prefab}.lua" not in prefab_files
            and not (prefab.endswith("_sketch") and prefab.removesuffix("_sketch") in sketches)
            and not (root / f"mod/lumine/scripts/prefabs/{prefab}.lua").is_file()):
        issues.append(("lumine_progression.lua", prefab, "prefab definition not found"))
print("Journal atlas references checked:", checked, "animations:", animations, "issues:", len(issues))
print(f"Evidence prefabs: {len(evidence)} | Boss guides: {boss_count} | Route nodes: {route_steps}")
for issue in issues:
    print(" | ".join(issue), file=sys.stderr)

if args.mapping and not issues:
    def table(columns, rows):
        return ["| " + " | ".join(columns) + " |", "| " + " | ".join("---" for _ in columns) + " |",
                *("| " + " | ".join(row) + " |" for row in rows)]

    args.mapping.write_text("\n".join([
        "# 旅行手册原版图片映射",
        "",
        "根据本机 DST 的 Scrapbook 数据、atlas 和 TEX 验证。资源路径均相对于游戏或模组的数据根目录。",
        "",
        "## 30 个收录章节",
        "",
        *table(("章节", "生物、地标或物品", "图片来源", "资源路径与图元", "状态"), chapter_rows),
        "",
        "## 首领与特殊遭遇",
        "",
        *table(("分组", "名称", "Prefab", "类别", "已接入资源"), boss_rows),
        "",
    ]), encoding="utf-8")
sys.exit(bool(issues))
