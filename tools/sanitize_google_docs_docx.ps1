param(
  [string]$InputPath = 'C:\Users\user\StudioProjects\fyp\output\docs\EthernaCare_RSW_Aligned_2026.docx',
  [string]$OutputPath = 'C:\Users\user\StudioProjects\fyp\output\docs\EthernaCare_RSW_Aligned_2026_GoogleDocs.docx'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
Copy-Item -LiteralPath $InputPath -Destination $OutputPath -Force

function Update-XmlEntry($archive, [string]$entryName, [scriptblock]$edit) {
  $entry = $archive.GetEntry($entryName)
  if ($null -eq $entry) { return 0 }

  $stream = $entry.Open()
  $reader = New-Object System.IO.StreamReader($stream)
  try { $content = $reader.ReadToEnd() }
  finally {
    $reader.Dispose()
    $stream.Dispose()
  }

  $xml = New-Object System.Xml.XmlDocument
  $xml.PreserveWhitespace = $true
  $xml.LoadXml($content)
  $removed = & $edit $xml

  $stream = $entry.Open()
  $stream.SetLength(0)
  $settings = New-Object System.Xml.XmlWriterSettings
  $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
  $settings.Indent = $false
  $writer = [System.Xml.XmlWriter]::Create($stream, $settings)
  try { $xml.Save($writer) }
  finally {
    $writer.Dispose()
    $stream.Dispose()
  }
  return $removed
}

$archive = [System.IO.Compression.ZipFile]::Open($OutputPath, [System.IO.Compression.ZipArchiveMode]::Update)
try {
  $documentRemoved = Update-XmlEntry $archive 'word/document.xml' {
    param($xml)
    $manager = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
    $manager.AddNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
    $paragraphs = @($xml.SelectNodes('//w:body/w:p[position() <= 10]', $manager))
    $count = 0
    foreach ($paragraph in $paragraphs) {
      foreach ($border in @($paragraph.SelectNodes('./w:pPr/w:pBdr', $manager))) {
        $border.ParentNode.RemoveChild($border) | Out-Null
        $count++
      }
    }
    return $count
  }

  $stylesRemoved = Update-XmlEntry $archive 'word/styles.xml' {
    param($xml)
    $manager = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
    $manager.AddNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
    $styles = @($xml.SelectNodes('//w:style[@w:styleId="Title" or w:name[@w:val="Title" or @w:val="title"]]', $manager))
    $count = 0
    foreach ($style in $styles) {
      foreach ($border in @($style.SelectNodes('./w:pPr/w:pBdr', $manager))) {
        $border.ParentNode.RemoveChild($border) | Out-Null
        $count++
      }
    }
    return $count
  }
}
finally { $archive.Dispose() }

[PSCustomObject]@{
  OutputPath = $OutputPath
  FirstParagraphBordersRemoved = $documentRemoved
  TitleStyleBordersRemoved = $stylesRemoved
}
