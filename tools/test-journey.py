"""Run local journey tests. See tests/README.md for setup and test levels."""
import argparse
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".tools/journey-lua"))
try:
    from lupa.lua51 import LuaRuntime, LuaError
except ImportError:
    sys.exit("Lua 5.1 runtime missing. Run: py -3 -m pip install --target .tools/journey-lua -r tests/requirements.txt")

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("level", choices=("quick", "core", "full"))
parser.add_argument("--module", choices=("data", "recording", "flow", "skilltree", "statue", "wind_dash", "electro", "dendro", "hydro", "pyro", "cryo"))
parser.add_argument("--file", action="append", help="Limit quick syntax checks to this Lua file; repeat as needed.")
parser.add_argument("--dst-root", type=Path, help="Path to the installed Don't Starve Together folder.")
args = parser.parse_args()
if args.file and (args.level != "quick" or args.module):
    parser.error("--file is available for quick syntax checks only")

runtime = LuaRuntime(unpack_returned_tuples=True)
runtime.globals().print = lambda *values: print(*values, flush=True)

def read_module(name):
    # Lua 5.1 uses narrow fopen on Windows. Let Python open Unicode workspace paths.
    if not all(part.isidentifier() for part in name.replace("/", ".").split(".")):
        return None, None
    relative = name.replace(".", "/") + ".lua"
    for directory in ("mod/lumine/scripts", "tests"):
        file = ROOT / directory / relative
        if file.is_file():
            return file.read_text(encoding="utf-8-sig"), "@" + file.relative_to(ROOT).as_posix()
    return None, None

if args.module == "cryo" or args.level == "full":
    from zipfile import ZipFile
    dst = args.dst_root or Path(os.environ.get("DST_ROOT", "F:/SteamLibrary/steamapps/common/Don't Starve Together"))
    with ZipFile(dst / "data/databundles/scripts.zip") as bundle:
        source = bundle.read("scripts/components/freezable.lua").decode("utf-8-sig")
        runtime.globals().package.preload["native_freezable"] = runtime.compile(source, name="@DST/components/freezable.lua")

if args.module == "skilltree" or args.level == "full":
    from zipfile import ZipFile

    dst = args.dst_root or Path(os.environ.get("DST_ROOT", "F:/SteamLibrary/steamapps/common/Don't Starve Together"))
    try:
        with ZipFile(dst / "data/databundles/scripts.zip") as bundle:
            def native_text(name):
                return bundle.read("scripts/" + name + ".lua").decode("utf-8-sig")

            for native in ("prefabs/skilltree_defs", "skilltreedata"):
                source = native_text(native)
                if native == "prefabs/skilltree_defs":
                    # Skip loading unrelated character trees, keep native registration and validation.
                    source = source.replace("\nBuildAllData()", "\n-- Base characters omitted for this test.", 1)
                runtime.globals().package.preload[native] = runtime.compile(source, name="@DST/" + native + ".lua")
            tuning = native_text("tuning")
        with ZipFile(dst / "data/databundles/images.zip") as bundle:
            runtime.globals().DST_SKILLTREE_ICONS = bundle.read("images/skilltree_icons.xml").decode("utf-8-sig")
            runtime.globals().DST_SKILLTREE_PAPER = bundle.read("images/scrapbook.xml").decode("utf-8-sig")
    except (OSError, KeyError) as exc:
        sys.exit(f"Cannot load DST skill tree scripts or atlas. Set --dst-root: {exc}")
    import re

    thresholds = re.search(r"SKILL_THRESHOLDS\s*=\s*\{([^}]+)\}", tuning).group(1)
    thresholds = [int(value) for value in re.findall(r"^\s*(\d+)", thresholds, re.MULTILINE)]
    runtime.globals().DST_SKILL_THRESHOLDS = runtime.table_from(thresholds)
    mod = ROOT / "mod/lumine"

    def check_mod_icon(atlas, tex):
        from xml.etree import ElementTree

        path = mod / atlas
        document = ElementTree.parse(path)
        texture = document.find("Texture").get("filename")
        return (path.parent / texture).is_file() and document.find(f".//Element[@name='{tex}']") is not None

    runtime.globals().check_mod_skilltree_icon = check_mod_icon
    recipe_src = (mod / "modmain.lua").read_text(encoding="utf-8-sig")
    recipes = re.findall(
        r'^AddCharacterRecipe\("(?:lumine_relic_codex|lumine_aranara_hut)", \{\n.*?^\}\)\n',
        recipe_src, re.MULTILINE | re.DOTALL,
    )
    runtime.globals().DST_SKILLTREE_RECIPES = "\n".join(recipes)

runtime.eval(r"""function(read)
    table.insert(package.loaders, 2, function(module)
        local source, name = read(module)
        if source == nil then return "\n\tno local Lua file for " .. module end
        return assert(loadstring(source, name))
    end)
end""")(read_module)
print(runtime.eval("_VERSION"), flush=True)
failed = False
if args.module is None and args.level in ("quick", "full"):
    files = sorted({(ROOT / path).resolve() for path in args.file}) if args.file else sorted(
        (ROOT / "mod/lumine").rglob("*.lua")
    ) + sorted((ROOT / "tests").rglob("*.lua"))
    compile_file = runtime.eval("function(source, name) local fn, err = loadstring(source, name); return err end")
    syntax_failures = 0
    for file in files:
        name = file.relative_to(ROOT).as_posix() if file.is_relative_to(ROOT) else str(file)
        try:
            error = compile_file(file.read_text(encoding="utf-8-sig"), "@" + name)
        except OSError as exc:
            error = f"{name}: {exc.strerror}"
        except UnicodeError as exc:
            error = f"{name}: {exc}"
        if error:
            print(error, file=sys.stderr)
            syntax_failures += 1
    print(f"Syntax: {len(files)-syntax_failures} passed, {syntax_failures} failed", flush=True)
    failed = syntax_failures > 0
if not args.file:
    try:
        run = runtime.execute((ROOT / "tests/run.lua").read_text(encoding="utf-8"), name="@tests/run.lua")
        failed = run(args.level, args.module) != 0 or failed
    except LuaError as exc:
        print(str(exc).split("stack traceback:")[0].strip(), file=sys.stderr)
        failed = True
if args.level == "full" and args.module is None:
    command = [sys.executable, str(ROOT / "tools/check-journey-assets.py")]
    if args.dst_root:
        command += ["--dst-root", str(args.dst_root)]
    failed = subprocess.run(command, cwd=ROOT, check=False).returncode != 0 or failed
sys.exit(int(failed))
