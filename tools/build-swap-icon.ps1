Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root 'art\source\lumine-head-front-v1.png'
$target = Join-Path $root 'art\working\lumine\SWAP_ICON\SWAP_ICON-0.png'
$inputImage = [System.Drawing.Bitmap]::new($source)
try {
    $minX = $inputImage.Width; $minY = $inputImage.Height
    $maxX = -1; $maxY = -1
    for ($y = 0; $y -lt $inputImage.Height; $y++) {
        for ($x = 0; $x -lt $inputImage.Width; $x++) {
            if ($inputImage.GetPixel($x, $y).A -gt 8) {
                if ($x -lt $minX) { $minX = $x }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }
    if ($maxX -lt 0) { throw '头部源图没有可见像素。' }
    $crop = [System.Drawing.Rectangle]::new($minX, $minY, $maxX - $minX + 1, $maxY - $minY + 1)
    $scale = [Math]::Min(186.0 / $crop.Width, 190.0 / $crop.Height)
    $width = [int][Math]::Round($crop.Width * $scale)
    $height = [int][Math]::Round($crop.Height * $scale)
    $dest = [System.Drawing.Rectangle]::new([int][Math]::Round((268 - $width) / 2), [int][Math]::Round((244 - $height) / 2), $width, $height)
    $canvas = [System.Drawing.Bitmap]::new(268, 244, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $g = [System.Drawing.Graphics]::FromImage($canvas)
        try {
            $g.Clear([System.Drawing.Color]::Transparent)
            $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $g.DrawImage($inputImage, $dest, $crop, [System.Drawing.GraphicsUnit]::Pixel)
        } finally { $g.Dispose() }
        $canvas.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally { $canvas.Dispose() }
} finally { $inputImage.Dispose() }
Write-Output $target
