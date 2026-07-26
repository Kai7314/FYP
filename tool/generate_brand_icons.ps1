param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$primary = [System.Drawing.Color]::FromArgb(255, 8, 168, 120)
$white = [System.Drawing.Color]::White

function New-EthernaCareIcon {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Size
    )

    $bitmap = New-Object System.Drawing.Bitmap(
        $Size,
        $Size,
        [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
    )
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.Clear($primary)

    $scale = $Size / 1024.0
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.StartFigure()
    $path.AddLine(
        [System.Drawing.PointF]::new(512 * $scale, 205 * $scale),
        [System.Drawing.PointF]::new(728 * $scale, 295 * $scale)
    )
    $path.AddLine(
        [System.Drawing.PointF]::new(728 * $scale, 295 * $scale),
        [System.Drawing.PointF]::new(704 * $scale, 520 * $scale)
    )
    $path.AddBezier(
        [System.Drawing.PointF]::new(704 * $scale, 520 * $scale),
        [System.Drawing.PointF]::new(686 * $scale, 668 * $scale),
        [System.Drawing.PointF]::new(590 * $scale, 760 * $scale),
        [System.Drawing.PointF]::new(512 * $scale, 810 * $scale)
    )
    $path.AddBezier(
        [System.Drawing.PointF]::new(512 * $scale, 810 * $scale),
        [System.Drawing.PointF]::new(434 * $scale, 760 * $scale),
        [System.Drawing.PointF]::new(338 * $scale, 668 * $scale),
        [System.Drawing.PointF]::new(320 * $scale, 520 * $scale)
    )
    $path.AddLine(
        [System.Drawing.PointF]::new(320 * $scale, 520 * $scale),
        [System.Drawing.PointF]::new(296 * $scale, 295 * $scale)
    )
    $path.CloseFigure()

    $stroke = [Math]::Max(1.5, 58 * $scale)
    $pen = New-Object System.Drawing.Pen($white, $stroke)
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $graphics.DrawPath($pen, $path)

    $pen.Dispose()
    $path.Dispose()
    $graphics.Dispose()
    return $bitmap
}

function Save-IconPng {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Size,
        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    $destination = Join-Path $ProjectRoot $RelativePath
    $directory = Split-Path -Parent $destination
    New-Item -ItemType Directory -Path $directory -Force | Out-Null

    $bitmap = New-EthernaCareIcon -Size $Size
    $bitmap.Save($destination, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
}

function Get-IconPngBytes {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Size
    )

    $bitmap = New-EthernaCareIcon -Size $Size
    $stream = New-Object System.IO.MemoryStream
    $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
    $bytes = $stream.ToArray()
    $stream.Dispose()
    $bitmap.Dispose()
    return $bytes
}

function Save-WindowsIcon {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    $sizes = @(16, 32, 48, 64, 128, 256)
    $images = @()
    foreach ($size in $sizes) {
        $images += ,(Get-IconPngBytes -Size $size)
    }

    $destination = Join-Path $ProjectRoot $RelativePath
    $stream = [System.IO.File]::Create($destination)
    $writer = New-Object System.IO.BinaryWriter($stream)
    $writer.Write([uint16]0)
    $writer.Write([uint16]1)
    $writer.Write([uint16]$sizes.Count)

    $offset = 6 + (16 * $sizes.Count)
    for ($index = 0; $index -lt $sizes.Count; $index++) {
        $size = $sizes[$index]
        $dimension = if ($size -eq 256) { 0 } else { $size }
        $writer.Write([byte]$dimension)
        $writer.Write([byte]$dimension)
        $writer.Write([byte]0)
        $writer.Write([byte]0)
        $writer.Write([uint16]1)
        $writer.Write([uint16]32)
        $writer.Write([uint32]$images[$index].Length)
        $writer.Write([uint32]$offset)
        $offset += $images[$index].Length
    }

    foreach ($image in $images) {
        $writer.Write([byte[]]$image)
    }
    $writer.Dispose()
    $stream.Dispose()
}

$pngTargets = @{
    1024 = @(
        'assets/branding/ethernacare_app_icon.png',
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
        'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png'
    )
    512 = @(
        'web/icons/Icon-512.png',
        'web/icons/Icon-maskable-512.png',
        'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png'
    )
    256 = @('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png')
    192 = @(
        'web/icons/Icon-192.png',
        'web/icons/Icon-maskable-192.png',
        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png'
    )
    180 = @('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png')
    167 = @('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png')
    152 = @('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png')
    144 = @('android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png')
    128 = @('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png')
    120 = @(
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png',
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png'
    )
    96 = @('android/app/src/main/res/mipmap-xhdpi/ic_launcher.png')
    87 = @('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png')
    80 = @('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png')
    76 = @('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png')
    72 = @('android/app/src/main/res/mipmap-hdpi/ic_launcher.png')
    64 = @('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png')
    60 = @('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png')
    58 = @('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png')
    48 = @('android/app/src/main/res/mipmap-mdpi/ic_launcher.png')
    40 = @(
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png',
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png'
    )
    32 = @(
        'web/favicon.png',
        'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png'
    )
    29 = @('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png')
    20 = @('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png')
    16 = @('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png')
}

foreach ($sizeEntry in $pngTargets.GetEnumerator()) {
    foreach ($target in $sizeEntry.Value) {
        Save-IconPng -Size $sizeEntry.Key -RelativePath $target
    }
}

Save-WindowsIcon -RelativePath 'windows/runner/resources/app_icon.ico'
Write-Host 'EthernaCare icons generated successfully.'
