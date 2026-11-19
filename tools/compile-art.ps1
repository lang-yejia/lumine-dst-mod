param(
    [string]$ModToolsRoot = "F:\SteamLibrary\steamapps\common\Don't Starve Mod Tools"
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$scml = Join-Path $projectRoot 'art\working\lumine\lumine.scml'
$output = Join-Path $projectRoot '.build\lumine'
$compiler = Join-Path $ModToolsRoot 'mod_tools\scml.exe'

if (-not (Test-Path -LiteralPath $compiler)) { throw "找不到编译器：$compiler" }
if (-not (Test-Path -LiteralPath $scml)) { throw "找不到 SCML：$scml" }
New-Item -ItemType Directory -Path $output -Force | Out-Null
& $compiler $scml $output
if ($LASTEXITCODE -ne 0) { throw "SCML 编译失败，退出码：$LASTEXITCODE" }
$zip = Join-Path $output 'anim\lumine.zip'
if (-not (Test-Path -LiteralPath $zip)) { throw "编译器未生成：$zip" }
Write-Output $zip
