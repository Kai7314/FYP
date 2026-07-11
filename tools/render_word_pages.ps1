param(
  [string]$InputPath = 'C:\Users\user\StudioProjects\fyp\output\docs\EthernaCare_RSW_Aligned_2026.docx',
  [string]$OutputDirectory = 'C:\Users\user\StudioProjects\fyp\tmp\docx_qa'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
Get-ChildItem -LiteralPath $OutputDirectory -Filter 'page-*.png' -ErrorAction SilentlyContinue | Remove-Item -Force

$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0
$document = $null

try {
  $document = $word.Documents.Open($InputPath, $false, $true)
  $word.Visible = $true
  $document.Repaginate()
  $document.ActiveWindow.View.Type = 3
  $pageCount = $document.ComputeStatistics(2)

  for ($pageNumber = 1; $pageNumber -le $pageCount; $pageNumber++) {
    $page = $document.ActiveWindow.ActivePane.Pages.Item($pageNumber)
    $bytes = $page.EnhMetaFileBits
    $emfPath = Join-Path $OutputDirectory ("page-{0:D3}.emf" -f $pageNumber)
    $pngPath = Join-Path $OutputDirectory ("page-{0:D3}.png" -f $pageNumber)
    [System.IO.File]::WriteAllBytes($emfPath, $bytes)

    $source = [System.Drawing.Image]::FromFile($emfPath)
    try {
      $bitmap = New-Object System.Drawing.Bitmap($source.Width, $source.Height)
      $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
      try {
        $graphics.Clear([System.Drawing.Color]::White)
        $graphics.DrawImage($source, 0, 0, $source.Width, $source.Height)
      }
      finally { $graphics.Dispose() }
      $bitmap.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
      $bitmap.Dispose()
    }
    finally { $source.Dispose() }
    Remove-Item -LiteralPath $emfPath -Force
  }

  "PAGE_COUNT=$pageCount"
  Get-ChildItem -LiteralPath $OutputDirectory -Filter 'page-*.png' | Select-Object Name, Length
}
finally {
  if ($null -ne $document) { $document.Close($false) }
  $word.Quit()
  [System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($word) | Out-Null
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
}
