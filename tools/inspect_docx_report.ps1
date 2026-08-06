param(
  [Parameter(Mandatory = $true)]
  [string]$InputPath,
  [Parameter(Mandatory = $true)]
  [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $InputPath)) {
  throw "Document not found: $InputPath"
}

$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0
$document = $null

try {
  $document = $word.Documents.Open($InputPath, $false, $true)
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("PARAGRAPHS=$($document.Paragraphs.Count)")
  $lines.Add("TABLES=$($document.Tables.Count)")
  $lines.Add("INLINE_SHAPES=$($document.InlineShapes.Count)")
  $lines.Add("SECTIONS=$($document.Sections.Count)")
  $lines.Add('')

  for ($sectionIndex = 1; $sectionIndex -le $document.Sections.Count; $sectionIndex++) {
    $section = $document.Sections.Item($sectionIndex)
    $header = ''
    $firstHeader = ''
    try { $header = ($section.Headers.Item(1).Range.Text -replace "[\r\a]", '').Trim() } catch { }
    try { $firstHeader = ($section.Headers.Item(2).Range.Text -replace "[\r\a]", '').Trim() } catch { }
    $startPage = $section.Range.Information(3)
    $endRange = $section.Range.Duplicate
    $endRange.Collapse(0)
    $endPage = $endRange.Information(3)
    $differentFirst = $section.PageSetup.DifferentFirstPageHeaderFooter
    $lines.Add("SECTION $sectionIndex PAGES=$startPage-$endPage DIFFERENT_FIRST=$differentFirst HEADER=$header FIRST_HEADER=$firstHeader")
  }
  $lines.Add('')

  for ($i = 1; $i -le $document.Paragraphs.Count; $i++) {
    $paragraph = $document.Paragraphs.Item($i)
    $text = ($paragraph.Range.Text -replace "[\r\a]", '').Trim()
    if (-not $text) { continue }
    try { $style = $paragraph.Range.Style.NameLocal } catch { $style = '' }
    $lines.Add(('P{0:D4}`t[{1}]`t{2}' -f $i, $style, $text))
  }

  for ($tableIndex = 1; $tableIndex -le $document.Tables.Count; $tableIndex++) {
    $table = $document.Tables.Item($tableIndex)
    $lines.Add('')
    $lines.Add("TABLE $tableIndex ROWS=$($table.Rows.Count) COLS=$($table.Columns.Count)")
    for ($rowIndex = 1; $rowIndex -le $table.Rows.Count; $rowIndex++) {
      $cells = New-Object System.Collections.Generic.List[string]
      for ($columnIndex = 1; $columnIndex -le $table.Columns.Count; $columnIndex++) {
        try {
          $cellText = ($table.Cell($rowIndex, $columnIndex).Range.Text -replace "[\r\a]", ' ').Trim()
          $cells.Add($cellText)
        }
        catch {
          $cells.Add('<merged>')
        }
      }
      $lines.Add(('R{0:D3}`t{1}' -f $rowIndex, ($cells -join ' | ')))
    }
  }

  [IO.File]::WriteAllLines($OutputPath, $lines, [Text.UTF8Encoding]::new($false))
  "WROTE=$OutputPath"
}
finally {
  if ($null -ne $document) { $document.Close($false) }
  $word.Quit()
  [Runtime.InteropServices.Marshal]::FinalReleaseComObject($word) | Out-Null
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
}
