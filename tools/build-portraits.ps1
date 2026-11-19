Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$mod = Join-Path $root 'mod\lumine'
$full = [System.Drawing.Bitmap]::new((Join-Path $root 'art\source\lumine-fullbody-front-v1.png'))
$head = [System.Drawing.Bitmap]::new((Join-Path $root 'art\source\lumine-head-front-v1.png'))

function Save-Fitted([System.Drawing.Bitmap]$source, [System.Drawing.Rectangle]$sourceRect,
                     [int]$width, [int]$height, [string]$path, [double]$fill = 0.91) {
    $image = [System.Drawing.Bitmap]::new($width,$height,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [System.Drawing.Graphics]::FromImage($image)
        try {
            $graphics.Clear([System.Drawing.Color]::Transparent)
            $scale = [Math]::Min($width * $fill / $sourceRect.Width, $height * $fill / $sourceRect.Height)
            $w = [int][Math]::Round($sourceRect.Width * $scale)
            $h = [int][Math]::Round($sourceRect.Height * $scale)
            $dest = [System.Drawing.Rectangle]::new([int][Math]::Round(($width-$w)/2), [int][Math]::Round(($height-$h)/2),$w,$h)
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.DrawImage($source,$dest,$sourceRect,[System.Drawing.GraphicsUnit]::Pixel)
        } finally { $graphics.Dispose() }
        $image.Save($path,[System.Drawing.Imaging.ImageFormat]::Png)
    } finally { $image.Dispose() }
}

try {
    $fullRect = [System.Drawing.Rectangle]::new(252,12,592,1422)
    $headRect = [System.Drawing.Rectangle]::new(177,107,992,1025)
    Save-Fitted $full $fullRect 491 654 (Join-Path $mod 'bigportraits\lumine.png')
    Save-Fitted $full $fullRect 188 284 (Join-Path $mod 'images\selectscreen_portraits\lumine.png')
    Save-Fitted $head $headRect 120 104 (Join-Path $mod 'images\saveslot_portraits\lumine.png')
    Save-Fitted $head $headRect 64 64 (Join-Path $mod 'images\avatars\avatar_lumine.png')
    Save-Fitted $head $headRect 64 64 (Join-Path $mod 'images\avatars\self_inspect_lumine.png')
    Save-Fitted $head $headRect 64 64 (Join-Path $mod 'images\map_icons\lumine.png')
    Save-Fitted $head $headRect 128 128 (Join-Path $mod 'modicon.png')
} finally { $full.Dispose(); $head.Dispose() }
Write-Output '角色头像和立绘 PNG 已导出。'
