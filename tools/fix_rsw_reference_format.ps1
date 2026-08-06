param(
  [string]$Path = 'C:\Users\user\StudioProjects\fyp\output\docs\EthernaCare_RSW_Updated_2026-08-05.docx'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Path)) {
  throw "Document not found: $Path"
}

$sourceText = 'Twilio. (n.d.). Message resource. Retrieved August 3, 2026, from https://www.twilio.com/docs/messaging/api/message-resource'
$targetTexts = @(
  'Flutter. (2026). Accessibility. Retrieved August 5, 2026, from https://docs.flutter.dev/ui/accessibility',
  'OWASP Foundation. (n.d.). MASWE-0006: Sensitive data stored unencrypted in private storage locations. Retrieved August 5, 2026, from https://mas.owasp.org/MASWE-0006/',
  'Google Play. (n.d.). Use of SMS or Call Log permission groups. Retrieved August 5, 2026, from https://support.google.com/googleplay/android-developer/answer/10208820?hl=en'
)

$tempPath = Join-Path (Split-Path -Parent $Path) (([System.IO.Path]::GetFileNameWithoutExtension($Path)) + '.formatting-fix.docx')
Copy-Item -LiteralPath $Path -Destination $tempPath -Force

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$archive = [System.IO.Compression.ZipFile]::Open($tempPath, [System.IO.Compression.ZipArchiveMode]::Update)
try {
  $entry = $archive.GetEntry('word/document.xml')
  if ($null -eq $entry) { throw 'word/document.xml is missing.' }

  $reader = New-Object System.IO.StreamReader($entry.Open())
  try { $xmlText = $reader.ReadToEnd() } finally { $reader.Dispose() }

  $xml = New-Object System.Xml.XmlDocument
  $xml.PreserveWhitespace = $true
  $xml.LoadXml($xmlText)
  $ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
  $ns.AddNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')

  function Get-Paragraph-Text([System.Xml.XmlNode]$paragraph) {
    return (($paragraph.SelectNodes('.//w:t', $ns) | ForEach-Object { $_.InnerText }) -join '')
  }

  $paragraphs = @($xml.SelectNodes('//w:body/w:p', $ns))
  $source = $paragraphs | Where-Object { (Get-Paragraph-Text $_) -eq $sourceText } | Select-Object -First 1
  if ($null -eq $source) { throw 'Reference-format source paragraph was not found.' }

  $sourcePPr = $source.SelectSingleNode('./w:pPr', $ns)
  foreach ($targetText in $targetTexts) {
    $target = $paragraphs | Where-Object { (Get-Paragraph-Text $_) -eq $targetText } | Select-Object -First 1
    if ($null -eq $target) { throw "Target reference was not found: $targetText" }

    $targetPPr = $target.SelectSingleNode('./w:pPr', $ns)
    if ($null -ne $targetPPr) { $target.RemoveChild($targetPPr) | Out-Null }
    if ($null -ne $sourcePPr) {
      $target.PrependChild($sourcePPr.CloneNode($true)) | Out-Null
    }
    foreach ($runProperties in @($target.SelectNodes('.//w:rPr', $ns))) {
      $runProperties.ParentNode.RemoveChild($runProperties) | Out-Null
    }
  }

  $entry.Delete()
  $newEntry = $archive.CreateEntry('word/document.xml', [System.IO.Compression.CompressionLevel]::Optimal)
  $writer = New-Object System.IO.StreamWriter($newEntry.Open(), (New-Object System.Text.UTF8Encoding($false)))
  try { $xml.Save($writer) } finally { $writer.Dispose() }
}
finally {
  $archive.Dispose()
}

$validation = [System.IO.Compression.ZipFile]::OpenRead($tempPath)
try {
  if ($null -eq $validation.GetEntry('[Content_Types].xml') -or $null -eq $validation.GetEntry('word/document.xml')) {
    throw 'Corrected DOCX failed package validation.'
  }
}
finally {
  $validation.Dispose()
}

Copy-Item -LiteralPath $tempPath -Destination $Path -Force
Remove-Item -LiteralPath $tempPath -Force
Get-Item -LiteralPath $Path | Select-Object FullName, Length, LastWriteTime
