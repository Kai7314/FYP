param(
  [string]$InputDirectory = 'C:\Users\user\StudioProjects\fyp\tmp\docx_qa',
  [string]$OutputDirectory = 'C:\Users\user\StudioProjects\fyp\tmp\docx_qa_sheets',
  [int]$PagesPerSheet = 6
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
Get-ChildItem -LiteralPath $OutputDirectory -Filter 'sheet-*.png' -ErrorAction SilentlyContinue | Remove-Item -Force

$pages = @(Get-ChildItem -LiteralPath $InputDirectory -Filter 'page-*.png' | Sort-Object Name)
$thumbWidth = 640
$thumbHeight = 905
$captionHeight = 42
$margin = 24
$columns = 3
$rows = [Math]::Ceiling($PagesPerSheet / $columns)
$sheetWidth = ($columns * $thumbWidth) + (($columns + 1) * $margin)
$sheetHeight = ($rows * ($thumbHeight + $captionHeight)) + (($rows + 1) * $margin)

for ($offset = 0; $offset -lt $pages.Count; $offset += $PagesPerSheet) {
  $sheetNumber = [int]($offset / $PagesPerSheet) + 1
  $bitmap = New-Object System.Drawing.Bitmap($sheetWidth, $sheetHeight)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  try {
    $graphics.Clear([System.Drawing.Color]::FromArgb(230, 230, 230))
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $font = New-Object System.Drawing.Font('Arial', 18, [System.Drawing.FontStyle]::Bold)
    try {
      for ($index = 0; $index -lt $PagesPerSheet -and ($offset + $index) -lt $pages.Count; $index++) {
        $page = $pages[$offset + $index]
        $column = $index % $columns
        $row = [Math]::Floor($index / $columns)
        $x = $margin + ($column * ($thumbWidth + $margin))
        $y = $margin + ($row * ($thumbHeight + $captionHeight + $margin))
        $source = [System.Drawing.Image]::FromFile($page.FullName)
        try {
          $graphics.FillRectangle([System.Drawing.Brushes]::White, $x, $y, $thumbWidth, $thumbHeight)
          $graphics.DrawImage($source, $x, $y, $thumbWidth, $thumbHeight)
          $graphics.DrawRectangle([System.Drawing.Pens]::Gray, $x, $y, $thumbWidth, $thumbHeight)
          $graphics.DrawString($page.BaseName, $font, [System.Drawing.Brushes]::Black, $x, ($y + $thumbHeight + 6))
        }
        finally { $source.Dispose() }
      }
    }
    finally { $font.Dispose() }
    $path = Join-Path $OutputDirectory ("sheet-{0:D2}.png" -f $sheetNumber)
    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  }
  finally {
    $graphics.Dispose()
    $bitmap.Dispose()
  }
}

Get-ChildItem -LiteralPath $OutputDirectory -Filter 'sheet-*.png' | Sort-Object Name | Select-Object Name, Length
