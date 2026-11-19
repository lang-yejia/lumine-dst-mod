Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$archivePath = Join-Path $root 'reference\extended-sample-character-dst.zip'
$artRoot = Join-Path $root 'art\working\lumine'
$sourceRoot = Join-Path $root 'art\source\parts'

function Get-Bounds([System.Drawing.Bitmap]$image, [byte]$threshold = 12) {
    $left = $image.Width; $top = $image.Height; $right = -1; $bottom = -1
    for ($y = 0; $y -lt $image.Height; $y++) {
        for ($x = 0; $x -lt $image.Width; $x++) {
            if ($image.GetPixel($x, $y).A -gt $threshold) {
                if ($x -lt $left) { $left = $x }
                if ($x -gt $right) { $right = $x }
                if ($y -lt $top) { $top = $y }
                if ($y -gt $bottom) { $bottom = $y }
            }
        }
    }
    if ($right -lt 0) { return $null }
    return [System.Drawing.Rectangle]::new($left, $top, $right - $left + 1, $bottom - $top + 1)
}

function Export-Part([System.Drawing.Bitmap]$source, [System.Drawing.Rectangle]$sourceRect,
                     [System.Drawing.Rectangle]$targetRect, [int]$canvasWidth,
                     [int]$canvasHeight, [string]$targetPath, [double]$sizeFactor = 1.0,
                     [string]$verticalAnchor = 'bottom', [int]$maxDimension = 0) {
    $canvas = [System.Drawing.Bitmap]::new($canvasWidth, $canvasHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [System.Drawing.Graphics]::FromImage($canvas)
        try {
            $graphics.Clear([System.Drawing.Color]::Transparent)
            if ($source -and $sourceRect.Width -gt 0 -and $targetRect.Width -gt 0) {
                $scale = [Math]::Min($targetRect.Width / $sourceRect.Width, $targetRect.Height / $sourceRect.Height) * $sizeFactor
                if ($maxDimension -gt 0) {
                    $scale = [Math]::Min($scale, [Math]::Min($maxDimension / $sourceRect.Width, $maxDimension / $sourceRect.Height))
                }
                $w = [int][Math]::Max(1, [Math]::Round($sourceRect.Width * $scale))
                $h = [int][Math]::Max(1, [Math]::Round($sourceRect.Height * $scale))
                $x = [int][Math]::Round($targetRect.X + ($targetRect.Width - $w) / 2)
                $y = if ($verticalAnchor -eq 'top') { $targetRect.Y }
                     elseif ($verticalAnchor -eq 'center') { [int][Math]::Round($targetRect.Y + ($targetRect.Height - $h) / 2) }
                     else { [int][Math]::Round($targetRect.Bottom - $h) }
                $dest = [System.Drawing.Rectangle]::new($x, $y, $w, $h)
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.DrawImage($source, $dest, $sourceRect, [System.Drawing.GraphicsUnit]::Pixel)
            }
        } finally { $graphics.Dispose() }
        $canvas.Save($targetPath, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally { $canvas.Dispose() }
}

$sources = @{}
foreach ($name in @('headbase','hair','torso','face','skirt','arm','leg','head-side','head-back')) {
    $sources[$name] = [System.Drawing.Bitmap]::new((Join-Path $sourceRoot "$name.png"))
}
$sources['head-front'] = [System.Drawing.Bitmap]::new((Join-Path $root 'art\source\lumine-head-front-v1.png'))
$sources['torso-views'] = [System.Drawing.Bitmap]::new((Join-Path $sourceRoot 'torso-views-v2.png'))
$sources['skirt-views'] = [System.Drawing.Bitmap]::new((Join-Path $sourceRoot 'skirt-views-v2.png'))
$sources['foot-views'] = [System.Drawing.Bitmap]::new((Join-Path $sourceRoot 'foot-views-v2.png'))
$sources['hand-views'] = [System.Drawing.Bitmap]::new((Join-Path $sourceRoot 'hand-views-v2.png'))
$sources['leg-poses'] = [System.Drawing.Bitmap]::new((Join-Path $sourceRoot 'leg-poses-v2.png'))
$sourceBounds = @{
    'head-front' = [System.Drawing.Rectangle]::new(177,107,992,1025)
    'head-side' = [System.Drawing.Rectangle]::new(137,37,1013,1111)
    'head-back' = [System.Drawing.Rectangle]::new(126,63,1011,1049)
    'torso' = [System.Drawing.Rectangle]::new(381,148,550,896)
    'skirt' = [System.Drawing.Rectangle]::new(292,116,954,816)
    'arm' = [System.Drawing.Rectangle]::new(288,147,320,1419)
    'leg' = [System.Drawing.Rectangle]::new(150,144,427,1845)
    'torso-side' = [System.Drawing.Rectangle]::new(1118,65,350,695)
    'torso-back' = [System.Drawing.Rectangle]::new(392,65,410,695)
    'skirt-side' = [System.Drawing.Rectangle]::new(1118,60,500,775)
    'skirt-back' = [System.Drawing.Rectangle]::new(115,60,860,775)
}

$emptyGroups = @('face','face_sail','cheeks','hair','hair_hat','hairfront','hairpigtails','arm_upper_skin','torso_pelvis','tail')
$footRects = @(
    [System.Drawing.Rectangle]::new(106,149,437,436),
    [System.Drawing.Rectangle]::new(703,149,383,436),
    [System.Drawing.Rectangle]::new(1315,149,255,433),
    [System.Drawing.Rectangle]::new(1795,147,230,438)
)
$handRects = @(
    [System.Drawing.Rectangle]::new(156,182,262,385),
    [System.Drawing.Rectangle]::new(668,226,296,241),
    [System.Drawing.Rectangle]::new(1208,228,285,252),
    [System.Drawing.Rectangle]::new(1744,182,269,385)
)
$legPoseRects = @(
    [System.Drawing.Rectangle]::new(174,70,329,519),
    [System.Drawing.Rectangle]::new(662,70,324,547),
    [System.Drawing.Rectangle]::new(1206,75,286,572),
    [System.Drawing.Rectangle]::new(1754,72,281,576)
)
$archive = [System.IO.Compression.ZipFile]::OpenRead($archivePath)
try {
    $entries = $archive.Entries | Where-Object { $_.FullName.Replace('\','/') -match '^exported/esctemplate/([^/]+)/([^/]+\.png)$' }
    foreach ($entry in $entries) {
        $null = $entry.FullName.Replace('\','/') -match '^exported/esctemplate/([^/]+)/([^/]+\.png)$'
        $group = $Matches[1]
        $filename = $Matches[2]
        if ($filename -eq 'Texture template.png' -or $group -eq 'SWAP_ICON') { continue }
        $path = Join-Path (Join-Path $artRoot $group) $filename
        $stream = $entry.Open()
        try { $template = [System.Drawing.Bitmap]::new($stream) }
        finally { $stream.Dispose() }
        try {
            $bbox = Get-Bounds $template
            if ($null -eq $bbox) { continue }
            $sourceName = $null
            $part = $null
            if ($group -in @('headbase','headbase_hat')) {
                if ($filename -match '-([0-9]+)\.png$') {
                    $index = [int]$Matches[1]
                    $sourceName = @('head-front','head-side','head-back','head-front')[$index]
                }
            } elseif ($group -eq 'torso' -or $group -eq 'skirt') {
                $index = 0
                if ($filename -match '-([0-9]+)\.png$') { $index = [int]$Matches[1] }
                if ($group -eq 'torso') {
                    if ($index -in @(1,3,5,9)) { $sourceName = 'torso-side' }
                    elseif ($index -in @(2,6,10)) { $sourceName = 'torso-back' }
                    else { $sourceName = 'torso' }
                } else {
                    if ($index -in @(1,4)) { $sourceName = 'skirt-back' }
                    elseif ($index -in @(2,3)) { $sourceName = 'skirt-side' }
                    else { $sourceName = 'skirt' }
                }
            }
            elseif ($group -in @('arm_upper','arm_lower','hand')) { $sourceName = 'arm' }
            elseif ($group -in @('leg','foot')) { $sourceName = 'leg' }
            if ($sourceName) {
                $part = $sourceBounds[$sourceName]
                if ($sourceName -match '^(torso|skirt)-(side|back)$') { $sourceName = "$($Matches[1])-views" }
                $index = 0
                if ($filename -match '-([0-9]+)\.png$') { $index = [int]$Matches[1] }
                if ($group -eq 'foot') {
                    $sourceName = 'foot-views'
                    # The build sheet uses frame 0 for the front pair, 1/2 for
                    # the side pair, and 3 for the back pair. Mirroring is done
                    # by the animation bank for the opposite foot.
                    $part = $footRects[@(3,0,0,2,0,1,3,2)[$index % 8]]
                } elseif ($group -eq 'hand') {
                    $sourceName = 'hand-views'
                    $handIndex = if ($index -in @(0,3,6,9,13,14,16,17)) { 0 }
                                 elseif ($index -in @(1,4,5,7,10,15,18,19)) { 1 }
                                 elseif ($index -in @(2,8,11,12)) { 2 }
                                 else { 3 }
                    $part = $handRects[$handIndex]
                } elseif ($group -eq 'leg' -and $index -in @(4,6,7,8)) {
                    $sourceName = 'leg-poses'
                    $poseIndex = @{ 4 = 0; 6 = 1; 7 = 2; 8 = 3 }[$index]
                    $part = $legPoseRects[$poseIndex]
                }
                if ($group -eq 'arm_upper') { $part = [System.Drawing.Rectangle]::new(288,147,320,540) }
                elseif ($group -eq 'arm_lower') { $part = [System.Drawing.Rectangle]::new(288,490,320,790) }
                elseif ($group -eq 'leg' -and $sourceName -eq 'leg') { $part = [System.Drawing.Rectangle]::new(150,144,427,1390) }
                $sizeFactor = if ($group -in @('headbase','headbase_hat')) { 0.82 } elseif ($group -eq 'hand') { 0.8 } else { 1.0 }
                $verticalAnchor = if ($group -eq 'arm_upper') { 'top' } elseif ($group -eq 'hand') { 'center' } else { 'bottom' }
                $maxDimension = if ($group -eq 'hand') { 30 } else { 0 }
                Export-Part $sources[$sourceName] $part $bbox $template.Width $template.Height $path $sizeFactor $verticalAnchor $maxDimension
            } elseif ($group -in $emptyGroups) {
                Export-Part $null ([System.Drawing.Rectangle]::Empty) $bbox $template.Width $template.Height $path
            }
        } finally { $template.Dispose() }
    }
} finally {
    $archive.Dispose()
    foreach ($image in $sources.Values) { $image.Dispose() }
}
Write-Output '角色部件已导出到动画工作目录。'
