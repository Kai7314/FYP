param(
  [string]$Source = 'C:\Users\user\Downloads\RSW_OoKaiHeng 1_8_2026.docx',
  [string]$Output = 'C:\Users\user\StudioProjects\fyp\output\docs\EthernaCare_RSW_Updated_2026-08-03.docx',
  [string]$PdfOutput = 'C:\Users\user\StudioProjects\fyp\tmp\rsw_updated_2026_08_03\EthernaCare_RSW_Updated_2026-08-03.pdf'
)

$ErrorActionPreference = 'Stop'

function Paragraph-Text($paragraph) {
  return ($paragraph.Range.Text -replace "[\r\a]", '').Trim()
}

function Paragraph-Style($paragraph) {
  try { return $paragraph.Range.Style.NameLocal } catch { return '' }
}

function Find-Paragraph(
  $document,
  [string]$text,
  [int]$after = 0,
  [string]$styleLike = '',
  [bool]$contains = $false
) {
  for ($index = [Math]::Max(1, $after + 1); $index -le $document.Paragraphs.Count; $index++) {
    $paragraph = $document.Paragraphs.Item($index)
    $value = Paragraph-Text $paragraph
    $matches = if ($contains) { $value.Contains($text) } else { $value -eq $text }
    if (-not $matches) { continue }
    if ($styleLike -and -not (Paragraph-Style $paragraph).Contains($styleLike)) { continue }
    return [PSCustomObject]@{ Index = $index; Paragraph = $paragraph }
  }
  throw "Paragraph not found: $text"
}

function Set-Paragraph(
  $document,
  [string]$find,
  [string]$replacement,
  [bool]$contains = $false,
  [int]$after = 0,
  [string]$styleLike = ''
) {
  $match = Find-Paragraph $document $find $after $styleLike $contains
  $range = $match.Paragraph.Range.Duplicate
  $range.End = $range.End - 1
  $range.Text = $replacement
}

function Set-Paragraph-Style($paragraph, [string]$kind) {
  switch ($kind) {
    'H1' { $paragraph.Range.Style = -2 }
    'H2' { $paragraph.Range.Style = -3 }
    'H3' { $paragraph.Range.Style = -4 }
    'H4' { $paragraph.Range.Style = -5 }
    default { $paragraph.Range.Style = -1 }
  }
}

function Item([string]$style, [string]$text) {
  return [PSCustomObject]@{ Style = $style; Text = $text }
}

function Replace-Section-Body(
  $document,
  [string]$startText,
  [string]$endText,
  [array]$items,
  [string]$startStyle = '',
  [string]$endStyle = '',
  [int]$after = 0,
  [bool]$endContains = $false
) {
  $start = Find-Paragraph $document $startText $after $startStyle $false
  $end = Find-Paragraph $document $endText $start.Index $endStyle $endContains
  $range = $document.Range($start.Paragraph.Range.End, $end.Paragraph.Range.Start)
  $range.Text = (($items | ForEach-Object { $_.Text }) -join "`r") + "`r"

  $cursor = (Find-Paragraph $document $startText $after $startStyle $false).Index
  foreach ($item in $items) {
    $match = Find-Paragraph $document $item.Text $cursor '' $false
    Set-Paragraph-Style $match.Paragraph $item.Style
    $cursor = $match.Index
  }
}

function Set-Table-Cell($document, [int]$table, [int]$row, [int]$column, [string]$text) {
  $cell = $document.Tables.Item($table).Cell($row, $column)
  $range = $cell.Range.Duplicate
  $range.End = $range.End - 1
  $range.Text = $text
}

function Insert-Items-Before(
  $document,
  [string]$beforeText,
  [array]$items,
  [string]$beforeStyle = '',
  [int]$after = 0
) {
  $before = Find-Paragraph $document $beforeText $after $beforeStyle $false
  $range = $document.Range($before.Paragraph.Range.Start, $before.Paragraph.Range.Start)
  $range.Text = (($items | ForEach-Object { $_.Text }) -join "`r") + "`r"

  $cursor = [Math]::Max(0, $before.Index - 1)
  foreach ($item in $items) {
    $match = Find-Paragraph $document $item.Text $cursor '' $false
    Set-Paragraph-Style $match.Paragraph $item.Style
    $cursor = $match.Index
  }
}

function Insert-Chapter-Cover-BeforeHeading(
  $document,
  [string]$headingText,
  [string]$chapterLabel
) {
  $heading = Find-Paragraph $document $headingText 0 'Heading 1' $false
  $breakRange = $document.Range($heading.Paragraph.Range.Start, $heading.Paragraph.Range.Start)
  $breakRange.InsertBreak(2)

  $heading = Find-Paragraph $document $headingText 0 'Heading 1' $false
  $coverRange = $document.Range($heading.Paragraph.Range.Start, $heading.Paragraph.Range.Start)
  $coverRange.Text = "$chapterLabel`r$headingText`r"

  $chapter = Find-Paragraph $document $chapterLabel ([Math]::Max(0, $heading.Index - 4)) '' $false
  $coverBreak = $document.Range($chapter.Paragraph.Range.Start, $chapter.Paragraph.Range.Start)
  $coverBreak.InsertBreak(3)
  $chapter = Find-Paragraph $document $chapterLabel ([Math]::Max(0, $heading.Index - 4)) '' $false
  $chapter.Paragraph.Range.Style = -1
  $chapter.Paragraph.Range.Font.Name = 'Arial'
  $chapter.Paragraph.Range.Font.Size = 18
  $chapter.Paragraph.Range.ParagraphFormat.Alignment = 1
  $chapter.Paragraph.Range.ParagraphFormat.SpaceBefore = 180
  $chapter.Paragraph.Range.ParagraphFormat.SpaceAfter = 36

  $coverTitle = Find-Paragraph $document $headingText $chapter.Index '' $false
  $coverTitle.Paragraph.Range.Style = -1
  $coverTitle.Paragraph.Range.Font.Name = 'Arial'
  $coverTitle.Paragraph.Range.Font.Size = 24
  $coverTitle.Paragraph.Range.Font.Bold = -1
  $coverTitle.Paragraph.Range.ParagraphFormat.Alignment = 1

  $bodyHeading = Find-Paragraph $document $headingText $coverTitle.Index 'Heading 1' $false
  $bodyHeading.Paragraph.Range.ParagraphFormat.PageBreakBefore = -1
}

function Insert-Section-Break-BeforeHeading($document, [string]$headingText) {
  $heading = Find-Paragraph $document $headingText 0 'Heading 1' $false
  $range = $document.Range($heading.Paragraph.Range.Start, $heading.Paragraph.Range.Start)
  $range.InsertBreak(2)
}

function Insert-Section-Break-BeforeParagraph($document, [string]$paragraphText) {
  $paragraph = Find-Paragraph $document $paragraphText 0 '' $false
  $range = $document.Range($paragraph.Paragraph.Range.Start, $paragraph.Paragraph.Range.Start)
  $range.InsertBreak(3)
}

function Set-Section-Header(
  $document,
  [string]$paragraphText,
  [string]$paragraphStyle,
  [string]$headerText
) {
  $match = Find-Paragraph $document $paragraphText 0 $paragraphStyle $false
  $section = $match.Paragraph.Range.Sections.Item(1)
  foreach ($headerType in @(1, 2, 3)) {
    $header = $section.Headers.Item($headerType)
    try { $header.LinkToPrevious = $false } catch { }

    if ($header.Range.Tables.Count -gt 0) {
      $table = $header.Range.Tables.Item(1)
      if ($table.Columns.Count -ge 2) {
        $range = $table.Cell(1, 2).Range.Duplicate
        $range.End = $range.End - 1
        $range.Text = $headerText
      }
    }
    else {
      $header.Range.Text = "Project Title`t$headerText"
    }
  }

  try { $section.Footers.Item(1).PageNumbers.RestartNumberingAtSection = $false } catch { }
}

function Clear-Cover-Header-BeforeHeading($document, [string]$headingText) {
  $match = Find-Paragraph $document $headingText 0 'Heading 1' $false
  $bodySection = $match.Paragraph.Range.Sections.Item(1)
  if ($bodySection.Index -le 1) {
    throw "No cover section exists before heading: $headingText"
  }
  $section = $document.Sections.Item($bodySection.Index - 1)
  $section.PageSetup.DifferentFirstPageHeaderFooter = -1
  foreach ($headerType in @(1, 2, 3)) {
    $header = $section.Headers.Item($headerType)
    $header.LinkToPrevious = $false
    if ($header.Range.Tables.Count -gt 0) {
      $table = $header.Range.Tables.Item(1)
      for ($row = 1; $row -le $table.Rows.Count; $row++) {
        for ($column = 1; $column -le $table.Columns.Count; $column++) {
          $range = $table.Cell($row, $column).Range.Duplicate
          $range.End = $range.End - 1
          $range.Text = ''
        }
      }
    }
    else {
      $header.Range.Text = ''
    }
  }
}

if (-not (Test-Path -LiteralPath $Source)) {
  throw "Source document not found: $Source"
}

$outputDirectory = Split-Path -Parent $Output
$pdfDirectory = Split-Path -Parent $PdfOutput
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
New-Item -ItemType Directory -Force -Path $pdfDirectory | Out-Null
Copy-Item -LiteralPath $Source -Destination $Output -Force

$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0
$document = $null

try {
  $document = $word.Documents.Open($Output)
  $document.TrackRevisions = $false
  if ($document.ProtectionType -ne -1) {
    try { $document.Unprotect() } catch { }
  }
  foreach ($control in @($document.ContentControls)) {
    try { $control.LockContents = $false } catch { }
    try { $control.LockContentControl = $false } catch { }
  }

  # Abstract: distinguish the authoritative server worker from best-effort phone work.
  Set-Paragraph $document 'The application uses a gamified virtual companion named Oren' @'
The application uses a gamified virtual companion named Oren to encourage regular interaction. Instead of using a fixed daily check-in, each user configures a rolling inactivity threshold from one to 168 hours. The first missed threshold window makes the check-in overdue and creates a local reminder. At the second missed window, the server worker attempts an SMS to the user's verified phone. At the third missed window, it records one inactivity alert and attempts one escalation SMS to the verified primary trusted contact. The cloud worker runs every 15 minutes and stores idempotent delivery state, while Android WorkManager provides best-effort local reminders. Oren also includes energy decay, feeding, playing, virtual tokens, owned toys, a shop and weather-based backgrounds. Check-in streaks separately allow users to collect virtual badges and vouchers.
'@.Trim() $true
  Set-Paragraph $document 'The system was developed using Flutter and Supabase' @'
The system was developed using Flutter and Supabase with Row Level Security, private Storage, Realtime, Edge Functions and scheduled server processing. Biometric session locking protects a locally restored signed-in session on supported devices. External SMS, email, weather and AI providers are accessed through controlled service boundaries, and 135 automated tests currently pass with 30.89 percent line coverage.
'@.Trim() $true

  # Literature comparison and scope statements.
  Set-Paragraph $document 'This system is related to EthernaCare because both involve emergency alerts' @'
This system is related to EthernaCare because both involve emergency alerts and contact notification. EthernaCare differs by using a configurable rolling check-in threshold and staged user/contact SMS escalation rather than direct emergency-service dispatch. It also includes protected Legacy Planning, which is outside Apple Emergency SOS.
'@.Trim() $true
  Set-Paragraph $document 'EthernaCare shares the concept of behavior monitoring but differs by using smartphone-based passive detection' @'
EthernaCare shares the objective of reducing delayed awareness but does not perform passive medical or behavioural sensing. It relies on an explicit Oren check-in, scheduled threshold evaluation and trusted-contact escalation, without requiring a wearable device.
'@.Trim() $true
  Set-Paragraph $document 'This chapter analyzed the challenges of elderly isolation' @'
This chapter analysed the challenges of social isolation and delayed awareness of emergencies among people who live alone. The reviewed systems support the value of accessible safety signals and trusted-contact communication. EthernaCare therefore uses a deliberate Oren interaction as a non-medical check-in, combines it with configurable threshold monitoring, and clearly limits its role to support and notification rather than diagnosis, fall detection or guaranteed emergency response.
'@.Trim() $true

  # Chapter 3: align requirements with the implemented actors and modules.
  $stakeholders = @(
    Item 'H3' 'Primary User'
    Item 'Normal' 'The primary user is an older adult or independent individual who lives alone. The user registers or signs in, completes profile and consent setup, verifies a phone number, configures an inactivity threshold, checks in through Oren, manages trusted contacts, uses rewards and AI guidance, and records Legacy Planning information.'
    Item 'H3' 'Primary Trusted Contact'
    Item 'Normal' 'A trusted contact is an emergency and Legacy recipient, not a second authenticated app role. One verified contact is selected as primary. That person may receive escalation messages and, after separate SMS verification, may view funeral preferences at any time and protected Legacy Notes or documents only during an authorised release window.'
    Item 'H3' 'Reward Administrator'
    Item 'Normal' 'An authorised administrator uses a separate admin route to create, edit, refresh and delete eligible virtual reward catalogue entries. The administrator does not gain access to personal user, contact or Legacy information.'
    Item 'H3' 'System Administrator / Developer'
    Item 'Normal' 'The system administrator maintains Flutter releases, Supabase migrations and policies, Storage, Edge Functions, Cron jobs, provider secrets, logs and backups. Production credentials are stored as server secrets and are not embedded in the mobile application or report.'
  )
  Replace-Section-Body $document 'Stakeholders' 'Functional Requirements' $stakeholders 'Heading 3' 'Heading 3'

  $functional = @(
    Item 'H3' 'Module 1: Authentication, Onboarding and Profile'
    Item 'Normal' 'Users register with email and password or a configured Google OAuth provider. Email sign-up and password recovery use Supabase confirmation flows. New users accept the Terms and Conditions, complete mandatory profile fields and verify the user phone by a six-digit SMS OTP. OAuth profile bootstrap ensures that the public user row uses the same authenticated UUID.'
    Item 'H3' 'Module 2: Oren Check-In and Care'
    Item 'Normal' 'Oren provides the explicit heartbeat action. A successful check-in is allowed when the configured rolling threshold has elapsed, resets the current inactivity cycle and updates history and rewards. Oren energy decays by one point for every complete hour, feeding restores energy, playing consumes energy, and owned toys and token state persist per user on the same device.'
    Item 'H3' 'Module 3: Inactivity and Emergency Response'
    Item 'Normal' 'The inactivity threshold can be set from one to 168 hours. At one missed window the status becomes overdue and a local reminder is created. At two missed windows the cloud worker attempts an SMS to the verified user phone. At three missed windows it creates one inactivity alert and attempts one SMS to the verified primary contact. The server worker runs every 15 minutes and uses persisted state and idempotency to prevent duplicate escalation. Manual SOS can record location and send a contact alert; calling 999 always requires explicit user action.'
    Item 'H3' 'Module 4: Trusted Contacts and Location'
    Item 'Normal' 'Users can manage up to five owned contacts and choose exactly one primary contact. Phone numbers must be verified by SMS OTP before they can be saved. Emergency records can include a Maps link when location permission and a valid position are available.'
    Item 'H3' 'Module 5: Virtual Rewards and Oren Shop'
    Item 'Normal' 'Check-in milestones unlock virtual badges and vouchers. A badge is stored in My Badge List when first collected, while a voucher displays a stable user-specific redemption code. An authorised admin maintains the catalogue through a separate route. Oren tokens are a separate local currency used to buy toys and care items.'
    Item 'H3' 'Module 6: Weather and AI Guidance'
    Item 'Normal' 'Weather first follows the Malaysian state and region saved in the profile through the data.gov.my weather service, with device coordinates and Open-Meteo as fallback. AI Guidance uses a secured Edge Function and provider fallback for general information only; it does not diagnose conditions or replace professional medical, legal or emergency advice.'
    Item 'H3' 'Module 7: Legacy Planning and Checking'
    Item 'Normal' 'The owner records funeral preferences, protected Legacy Notes and private PDF/JPEG/PNG documents up to 10 MB. Notes reject common password, PIN, OTP and recovery-secret patterns. Funeral preferences are available to the verified primary contact after a valid Legacy SMS OTP. Notes and documents require 90 days without check-in, a 24-hour owner warning/cancellation period and an active seven-day release window. Secure documents use short-lived signed links.'
    Item 'H3' 'Module 8: Biometric Session Lock'
    Item 'Normal' 'A signed-in user can enable biometric protection on a supported device. The app requests local authentication when restoring or resuming that user session. Asynchronous prompt coalescing prevents overlapping biometric requests, and a cancelled or failed prompt keeps the application locked.'
  )
  Replace-Section-Body $document 'Functional Requirements' 'Functions not included' $functional 'Heading 3' 'Heading 3'

  $nonFunctional = @(
    Item 'H3' 'Reliability'
    Item 'Normal' 'Server-side inactivity evaluation shall run every 15 minutes and persist each reminder stage. SMS work shall be queued with idempotency and retry state so repeated worker runs do not create duplicate escalation. Android local monitoring remains best-effort and shall not be described as exact-time or continuously running.'
    Item 'H3' 'Security and Privacy'
    Item 'Normal' 'Supabase Auth shall identify users; Row Level Security shall restrict owner data; private Storage shall protect documents; Edge Functions shall keep provider secrets off the client; phone and Legacy access shall use expiring OTPs with attempt limits; and biometric authentication shall protect only the local restored session rather than replace server authentication.'
    Item 'H3' 'Usability and Accessibility'
    Item 'Normal' 'The interface shall provide readable text, clear status/action differentiation, scrollable forms, guidance controls, safe error messages and responsive layouts. Threshold, escalation, contact verification and Legacy release states shall be explained in plain language.'
    Item 'H3' 'Performance and Efficiency'
    Item 'Normal' 'Weather, reward, chat and dashboard data shall use bounded caching where appropriate. Realtime subscriptions and manual refresh shall update shared catalogues without forcing unnecessary full-page reloads. Background work shall minimise battery usage and network calls.'
    Item 'H3' 'Maintainability and Portability'
    Item 'Normal' 'The Flutter client shall separate presentation, services, repositories and models. SQL migrations and Edge Functions shall be versioned and idempotent. Core deterministic rules shall be covered by automated tests, while Android hardware and carrier behaviours shall have documented physical acceptance cases.'
  )
  Replace-Section-Body $document 'Non-Functional Requirements' 'Use Case Diagram' $nonFunctional 'Heading 3' 'Heading 2'

  $useCases = @(
    Item 'H3' 'Use Case Actors'
    Item 'Normal' 'Primary User - authenticates, completes onboarding, manages the profile and contacts, performs Oren check-ins and care, views weather and rewards, asks AI Guidance, manages Legacy Planning, and triggers manual SOS.'
    Item 'Normal' 'Primary Trusted Contact - receives eligible SMS/email notifications and uses the public Legacy Check flow with the correct Legacy UID, verified primary phone and separate OTP. This actor does not log in to the owner account.'
    Item 'Normal' 'Reward Administrator - signs in through the separate admin route and maintains virtual reward catalogue entries within admin database policies.'
    Item 'Normal' 'External Services - Supabase provides authentication, data, private storage and scheduled functions; Twilio handles SMS; Brevo/SMTP handles transactional email; data.gov.my and Open-Meteo provide weather; an AI provider supplies general guidance; and device APIs provide location, local notifications and biometrics.'
    Item 'H3' 'Main Use Cases'
    Item 'Normal' 'Threshold Check-In - determine whether the rolling threshold has elapsed, insert one check-in atomically when due, reset inactivity state, and refresh rewards and Oren state.'
    Item 'Normal' 'Inactivity Escalation - evaluate elapsed windows every 15 minutes, update the current reminder stage, notify the user at stage two, notify the primary contact once at stage three, and suppress duplicates.'
    Item 'Normal' 'Manual Emergency Alert - ask for confirmation, capture location when available, store the event and attempt the selected contact action. Opening the 999 dialler remains manual.'
    Item 'Normal' 'Legacy Release - send the owner a 90-day warning, allow 24 hours to cancel or check in, open a seven-day protected-content window if not cancelled, and revoke access on expiry or a new check-in.'
    Item 'Normal' 'Virtual Reward Administration - create, edit, refresh or delete an eligible catalogue reward without exposing the administration route in the normal user navigation.'
  )
  Replace-Section-Body $document 'Use Case Actors' 'Chapter Summary and Evaluation' $useCases 'Heading 3' 'Heading 2'
  Set-Paragraph $document 'This chapter detailed the Agile methodology and functional requirements for EthernaCare' @'
This chapter described the Agile methodology, current stakeholders, implemented modules and system constraints. The requirements now distinguish the rolling threshold from a fixed daily timer, the cloud worker from best-effort Android execution, and notification support from guaranteed emergency response. They also define the current biometric session lock, virtual reward administration and staged Legacy release. These requirements provide a traceable basis for the design and context-based testing in later chapters.
'@.Trim() $true

  # Chapter 4: update the written design while preserving supplied diagrams and figures.
  Set-Paragraph $document 'The three-tier architecture is selected for the EthernaCare system' @'
EthernaCare uses a layered Flutter client connected to a managed Supabase backend. The Presentation layer contains responsive screens and reusable widgets. Controllers and services coordinate validation, threshold check-ins, inactivity state, rewards, weather, AI, biometric gating, notifications, SMS and local caching. Repositories isolate Supabase Auth, PostgreSQL, Storage, RPC and Edge Function access. Scheduled Edge Functions provide cloud execution independently of whether the phone is open.
'@.Trim() $true
  Set-Paragraph $document 'The Business Logic layer serves as the core processing unit' @'
The Business Logic layer applies reusable rules such as rolling check-in eligibility, three-stage inactivity escalation, one-primary-contact enforcement, OTP verification, reward claiming, Oren energy decay, weather fallback, biometric prompt coordination and Legacy release timing. Controllers delegate these rules to services so that they can be tested without the visual interface.
'@.Trim() $true
  Set-Paragraph $document 'The Data Access layer is responsible for managing all interactions' @'
The Data Access layer contains repositories for authentication, profiles, check-ins, contacts, emergencies, rewards, Legacy data and private documents. Supabase Row Level Security and storage policies enforce ownership. Edge Functions use server credentials only for narrow privileged operations such as SMS, AI requests and scheduled inactivity processing.
'@.Trim() $true
  Set-Paragraph $document 'The login activity begins when the user opens the application' @'
The login flow validates email/password credentials or starts Google OAuth. Supabase creates the authenticated session and the app ensures that the matching public profile exists. First-time accounts continue through Terms acceptance, profile setup, phone verification and primary-contact setup. Returning sessions can be protected by a per-user biometric lock on supported devices before the main interface is shown.
'@.Trim() $true
  Set-Paragraph $document 'The virtual petting process serves as the primary check-in mechanism' @'
The user taps Oren to request a check-in. The repository calculates eligibility from the latest check-in and the configured threshold, then creates one record atomically only when due. Success resets inactivity state, refreshes history and virtual rewards, and applies Oren energy, token, mood, sound and animation changes. Feeding and playing remain care actions and do not create false heartbeat records.
'@.Trim() $true
  Set-Paragraph $document 'Gemini said The Emergency Alert process' @'
The emergency design contains two paths. Manual SOS requires an explicit user action and may attach a location or Maps link when permission and positioning are available. Automatic inactivity processing is evaluated by the server every 15 minutes: the first missed window marks the user overdue and creates a local reminder, the second attempts a user SMS, and the third records one alert and attempts one trusted-contact SMS. Repeated runs are idempotent, and EthernaCare never automatically calls 999.
'@.Trim() $true

  $entities = @(
    Item 'H3' 'Core Entities and Attributes'
    Item 'Normal' 'User/Profile - authenticated UUID, name, contact and address data, blood type, inactivity threshold, escalation preference, phone verification, Terms acceptance, Legacy UID and Legacy consent/testing controls.'
    Item 'Normal' 'Check-In - owner UUID, timestamp and status used to calculate the rolling threshold, history and streaks.'
    Item 'Normal' 'Inactivity Monitor Status - per-user threshold snapshot, latest check-in, missed-window count, last notification stage, SMS attempt state and reset timestamps.'
    Item 'Normal' 'Contact - owner UUID, name, relationship, phone, address, primary flag and phone verification timestamp. Database logic preserves at most one primary contact.'
    Item 'Normal' 'Emergency Alert and Location - owner UUID, trigger source, status, timestamp and optional coordinates or Maps link.'
    Item 'Normal' 'Reward Catalogue and Earned Reward - virtual badge/voucher definition, milestone, active state, owner claim, claim timestamp and stable voucher code. Admin policies protect catalogue mutation.'
    Item 'Normal' 'Legacy Preference, Note and Document - owner-scoped funeral selections, protected notes, private object paths and upload timestamps.'
    Item 'Normal' 'Legacy Release and Access - owner warning, 24-hour grace deadline, cancellation token state, seven-day contact window, OTP verification and access audit events.'
    Item 'Normal' 'OTP and Delivery Outbox - hashed expiring verification codes, attempt counters, consumption timestamps, idempotency keys, provider responses, retries and final delivery state.'
    Item 'H3' 'Main Relationships'
    Item 'Normal' 'A user owns many check-ins, contacts, emergency alerts, rewards, notes and documents. Each contact, check-in and protected item belongs to one user. One user has one current inactivity-monitor row and can designate one primary contact. Legacy releases and delivery records reference the owner and preserve auditable state transitions.'
  )
  Replace-Section-Body $document 'Entities attributes' 'Security Handling' $entities 'Heading 3' 'Heading 2'

  Set-Paragraph $document 'The home page interface is designed for maximum simplicity' @'
The Home page places Oren and the weather-responsive pixel scene near the top. Borderless status text clearly separates Oren's mood from actions. Feed and Play appear in one row, owned items can be selected, and the token bar and Shop control show purchasing capacity. The safety check-in control is visually distinct from care actions so users do not mistake feeding or playing for a heartbeat. The Safety Monitor appears lower on the page with threshold and reminder-stage information.
'@.Trim() $true
  Set-Paragraph $document 'The Check-in History page provides a transparent and structured record' @'
The Check-In History page lists successful heartbeat timestamps and shows whether the current rolling threshold is still valid. It avoids an ambiguous percentage rate and instead explains the latest check-in and due state using the user's selected threshold.
'@.Trim() $true
  Set-Paragraph $document 'Gemini said The Emergency Contacts page' @'
The Emergency Contacts page presents up to five owner-managed contacts with a clear primary-contact indicator, call action and verified phone details. Oren's phone-call pose and concise guidance explain that the selected primary contact receives eligible SOS and inactivity alerts. Add, edit, delete and primary-selection actions remain visually separate.
'@.Trim() $true
  Set-Paragraph $document 'The Rewards page serves as the primary incentive hub' @'
The Rewards page contains virtual badges and vouchers rather than physical delivery items. Eligible badges can be collected into My Badge List, while Check Reward opens details for badges or vouchers and displays a stable user-specific redemption code when applicable. A separate authorised admin route maintains catalogue entries with Realtime updates and manual refresh fallback.
'@.Trim() $true
  Set-Paragraph $document 'The My Profile page serves as a centralized hub' @'
The Profile page displays and edits the user's contact, address, blood type, rolling inactivity threshold and escalation preference. It shows phone verification state, provides a copyable Legacy UID, allows biometric session protection on supported devices, and links to the Terms and Conditions and Legacy Planning. Age and a public profile photograph are not required by the current data model.
'@.Trim() $true
  Set-Paragraph $document 'This chapter presented the overall system design of the EthernaCare application' @'
This chapter presented the current layered client/cloud architecture, activity flows, data entities, security controls and user-interface design. The design separates local usability state from cloud authority, uses scheduled workers for safety and Legacy timing, and protects owner data through authenticated repositories, Row Level Security, private Storage and short-lived access. The preserved diagrams should be read together with the updated textual rules where the implementation evolved during Agile development.
'@.Trim() $true

  # Chapter 5: remove assignment instructions and update implementation evidence.
  $chapter5Introduction = @(
    Item 'Normal' 'This chapter explains how EthernaCare was translated from the requirements and system design into a working safety, well-being and legacy-planning application. It covers the system architecture, implemented modules, representative screens, test strategy, context-based test cases and current evaluation evidence.'
    Item 'Normal' 'Development was iterative and evidence-driven. Business rules were isolated in services and repositories for deterministic testing, while high-risk workflows use persisted server state, database controls and auditable provider boundaries. Interface changes were checked across compact mobile and wider desktop layouts.'
  )
  Replace-Section-Body $document 'Implementation and Testing' 'System Implementation' $chapter5Introduction 'Heading 1' 'Heading 2'

  Set-Paragraph $document 'EthernaCare uses a layered Flutter-and-Supabase architecture' @'
EthernaCare uses a layered Flutter-and-Supabase architecture. Flutter widgets form the presentation layer, controllers and services apply reusable business rules, and repositories isolate Supabase Auth, PostgreSQL, Storage, RPC and Edge Function calls. Android WorkManager provides best-effort local reminder evaluation. Independently, Supabase Cron invokes the inactivity-threshold worker every 15 minutes and the Legacy worker daily at 12:00 a.m. Malaysia time, so authoritative server processing does not depend on the application remaining open.
'@.Trim() $true

  Set-Table-Cell $document 1 7 2 'SMS OTP, emergency SMS, AI guidance, threshold processing, Legacy access/cancellation and daily Legacy processing'
  Set-Table-Cell $document 1 7 3 'Server-side secrets and narrow privileged operations outside the Flutter client'
  Set-Table-Cell $document 1 8 2 'Runs the threshold worker every 15 minutes and the Legacy worker daily at midnight MYT'
  Set-Table-Cell $document 1 8 3 'Cloud execution continues when the phone is closed or offline'
  Set-Table-Cell $document 1 9 1 'Python FastAPI reference worker (non-production)'
  Set-Table-Cell $document 1 9 2 'Readable reference implementation in server/python_legacy_server'
  Set-Table-Cell $document 1 9 3 'Documents the 90-day domain workflow; Supabase Edge Functions are the deployed production workers'
  Set-Table-Cell $document 1 11 2 'Best-effort Android local reminders and notification presentation'
  Set-Table-Cell $document 1 11 3 'Improves local responsiveness without acting as the authoritative SMS scheduler'

  Set-Table-Cell $document 4 4 3 'Allow the 15-minute server worker and the Android local monitor to evaluate inactivity.'
  Set-Table-Cell $document 4 4 4 'The persisted status becomes not current; a local reminder is shown and no contact escalation occurs.'
  Set-Table-Cell $document 4 4 5 'Logic and worker tests PASS; exact local timing PENDING PHYSICAL.'
  Set-Table-Cell $document 4 5 3 'Allow the next server worker evaluation.'
  Set-Table-Cell $document 4 5 4 'One user-reminder SMS is queued/attempted, delivery state is recorded and no check-in is created.'
  Set-Table-Cell $document 4 5 5 'Worker/orchestration PASS; carrier receipt PENDING PHYSICAL.'
  Set-Table-Cell $document 4 6 3 'Allow the third-stage server evaluation more than once.'
  Set-Table-Cell $document 4 6 4 'One inactivity alert and one primary-contact SMS are queued/attempted; idempotency suppresses duplicate escalation.'
  Set-Table-Cell $document 4 6 5 'Worker/idempotency PASS; carrier receipt PENDING PHYSICAL.'

  Set-Paragraph $document 'The current automated suite contains 132 passing tests' @'
The current automated suite contains 135 passing tests. Line coverage is 2,449 of 7,927 lines, or 30.89 percent. The suite covers important domain and widget behaviour, including biometric prompt coordination and rolling inactivity logic. Line coverage remains modest for the full presentation and provider-integration surface, so it is reported as a limitation rather than complete assurance. Real carrier delivery, Android Doze/background execution, biometric hardware and GPS accuracy still require physical-device acceptance testing.
'@.Trim() $true
  Set-Paragraph $document 'This chapter documented the current EthernaCare implementation according to the supplied guide' @'
This chapter documented the current EthernaCare implementation. The application combines a layered Flutter client with Supabase Auth, PostgreSQL, Row Level Security, private Storage, Realtime and Edge Functions. A 15-minute cloud worker applies the rolling inactivity stages, while a daily cloud worker manages the 90-day Legacy sequence. The key rules are explicit: check-in eligibility follows the selected threshold; server-side SMS attempts occur at missed windows two and three; Oren energy decays hourly; badges and vouchers have distinct redemption behaviour; biometric prompts are asynchronously coordinated; and protected Legacy content follows a 90-day, 24-hour owner-protection and seven-day contact-access sequence.
'@.Trim() $true
  Set-Paragraph $document 'The 132-test suite' @'
The 135-test suite and 30.89 percent line coverage provide useful regression evidence for deterministic logic and key interfaces. The deployed workers and versioned migrations provide an auditable backend implementation. However, automated tests and desktop builds cannot prove SMS receipt, external email delivery, Android operating-system scheduling, physical biometric sensors or GPS accuracy. EthernaCare is suitable for a final-year project and controlled demonstration, while production use requires the physical acceptance tests, provider monitoring and operational controls identified in this chapter.
'@.Trim() $true

  # Chapter 6: replace the remaining assignment template with actual deployment content.
  Set-Paragraph $document 'Chapter 6 (if applicable)' 'Chapter 6'
  $chapter6 = @(
    Item 'Normal' 'This chapter explains the controlled deployment of EthernaCare as a Flutter client with a managed Supabase backend. The project is not an industrial changeover from an earlier production system; deployment therefore focuses on repeatable cloud configuration, client builds, protected secrets, scheduled workers, rollback planning and user acceptance.'
    Item 'H2' 'Deployment Architecture'
    Item 'Normal' 'The deployed production backend is Supabase. Authentication, PostgreSQL, Row Level Security, private Storage, Realtime, database functions and Edge Functions run in the configured Supabase project. The Python FastAPI worker stored in the repository is a readable reference implementation only and is not the production scheduler.'
    Item 'H3' 'Client Deployment'
    Item 'Normal' 'The Flutter project can produce Android APK/app-bundle, Windows and web builds from the same Dart source. Environment-specific public Supabase connection values are supplied at build time. Secret provider credentials are never compiled into the client. Android deployment also requires notification, location and biometric permissions and the registered WorkManager entry point.'
    Item 'H3' 'Cloud Functions and External Providers'
    Item 'Normal' 'Edge Functions implement phone OTP, emergency SMS, AI guidance, threshold processing, Legacy access, cancellation and Legacy inactivity processing. Supabase encrypted function secrets store the Twilio, transactional-email, AI and OTP-signing credentials. Twilio handles SMS delivery and Brevo/SMTP handles email; each provider must be configured, funded or verified according to its own account rules before real delivery can be accepted.'
    Item 'H2' 'Database and Storage Deployment'
    Item 'Normal' 'Versioned SQL migrations create or alter tables, constraints, indexes, RPCs, RLS policies, Realtime publication settings, delivery outboxes and scheduled-job configuration. Migrations are applied in filename order and verified before the matching client release. The legacy-documents bucket is private, restricts file type and size, uses owner folders and returns short-lived signed URLs only through authorised flows.'
    Item 'H2' 'Scheduled Worker Deployment'
    Item 'Normal' 'Supabase Cron invokes process-inactivity-thresholds every 15 minutes. The function recalculates missed windows for all eligible users, persists the latest stage, queues idempotent SMS work and retries eligible failures. A separate Cron job invokes process-legacy-inactivity at 12:00 a.m. Malaysia time each day to evaluate 90-day eligibility, owner warnings, cancellation grace, primary-contact release and seven-day expiry. Cron logs and Edge Function logs are checked after deployment.'
    Item 'H2' 'System Backup and Risk Management'
    Item 'Normal' 'Source code and migrations are version-controlled. Database backups and provider exports should be retained according to the Supabase plan, while private files require a documented storage backup policy. Before a schema change, the developer reviews affected policies, functions and clients and prepares a backward-compatible or rollback migration. Secrets are stored only in encrypted project settings and must be rotated after accidental disclosure.'
    Item 'Normal' 'Major risks include provider outage, invalid SMS/email credentials, carrier filtering, delayed Android background work, revoked location permission, migration mismatch and duplicate alerts. The implementation reduces these risks with server scheduling, persisted outboxes, idempotency keys, retries, friendly status messages, local fallbacks and audit logs. It cannot guarantee that an external message is delivered or read.'
    Item 'H2' 'On-site Setup'
    Item 'Normal' 'A demonstration setup applies all migrations, deploys every Edge Function, configures required secrets, verifies both Cron jobs, enables authentication providers and redirect URLs, creates the private Storage bucket and builds the target Flutter package. Test accounts then complete email confirmation, phone verification, a primary contact, threshold configuration, biometric opt-in and Legacy consent. Production and testing phone numbers must be valid international numbers.'
    Item 'H2' 'Training Procedure'
    Item 'Normal' 'Training begins with account creation and consent, then demonstrates Oren check-in versus Feed/Play, the rolling threshold, reminder stages, contact verification, manual SOS, virtual rewards, profile controls and AI limitations. A separate Legacy exercise covers the Legacy UID, funeral preferences, owner protection, the public contact flow and the fact that Notes/documents remain time-restricted. Administrators receive separate training for reward catalogue maintenance and provider/log monitoring.'
    Item 'H2' 'Follow-up and Operational Monitoring'
    Item 'Normal' 'After release, the developer reviews Cron execution, Edge Function errors, SMS/email provider logs, failed outbox records, authentication delivery, Storage access and user-reported issues. Regression tests and static analysis are run before each release. Physical-device checks are repeated for notification permission, app resume, Doze/background behaviour, biometric cancellation/retry, GPS capture and carrier delivery.'
    Item 'H2' 'Chapter Summary and Evaluation'
    Item 'Normal' 'EthernaCare deployment separates a portable Flutter client from cloud-authoritative safety and Legacy workers. Versioned migrations, protected secrets, RLS, private Storage, scheduled functions and logs make the deployment repeatable and auditable. The approach resolves the main phone-background limitation, but continued reliability still depends on provider configuration, operational monitoring and physical acceptance testing.'
  )
  Replace-Section-Body $document 'System Deployment' 'Discussions and Conclusion' $chapter6 'Heading 1' 'Heading 1'
  Insert-Section-Break-BeforeParagraph $document 'Chapter 6'

  # Chapter 7: replace instructions with a formal evaluation of the completed system.
  $chapter7 = @(
    Item 'H2' 'Summary'
    Item 'Normal' 'EthernaCare was developed to reduce delayed awareness when an older adult or independent individual living alone stops providing an expected safety signal. The solution combines a configurable Oren check-in, staged inactivity reminders, verified trusted contacts, manual SOS support, location-assisted alerts, virtual rewards, weather-responsive interaction, AI guidance and consent-controlled Legacy Planning. Flutter supports a consistent multi-platform client, while Supabase provides managed identity, relational data, security policies, private files and scheduled server execution.'
    Item 'H2' 'Achievements'
    Item 'Normal' 'The project achieved its principal functional objectives. Check-ins now follow a one-to-168-hour rolling threshold instead of a fixed daily flag. A cloud worker evaluates every 15 minutes and persists the first, second and third missed-window stages. Contact phone verification, duplicate suppression and server delivery state support safer escalation. Oren has hourly energy decay and user-scoped care state. Rewards are fully virtual, with badge collection, voucher codes and a separate catalogue-admin route. Legacy Planning implements owner consent, funeral preferences, secret-aware notes, private documents, a 90-day trigger, a 24-hour owner-protection step and seven-day protected access. Supported sessions can be locked by asynchronously coordinated device biometrics.'
    Item 'Normal' 'Quality evidence includes 135 passing automated tests and 30.89 percent line coverage. The tests exercise important service, repository and widget paths, including threshold calculations, Oren decay, OTP rules, Legacy timing, virtual rewards and biometric prompt behaviour. This gives repeatable regression evidence, although it does not replace physical and provider acceptance testing.'
    Item 'H2' 'Contributions'
    Item 'Normal' 'The main contribution is the integration of a low-friction virtual companion with an explicit, configurable safety heartbeat and a server-controlled escalation model. Separating care actions from the heartbeat reduces ambiguity, while virtual rewards support engagement without physical delivery administration. The Legacy design also contributes a consent-based staged release: the owner receives a final protection opportunity before time-limited access is offered to a verified primary contact.'
    Item 'H2' 'Limitations and Future Improvements'
    Item 'Normal' 'EthernaCare is not a medical device and cannot detect falls, unconsciousness, vital signs, death or the cause of inactivity. It does not automatically dispatch Malaysian emergency services. SMS and email delivery depend on provider accounts, carrier filtering and valid contact data. Android local scheduling is best-effort, GPS depends on permission and signal, and biometric authentication protects a restored local session rather than proving the identity of a trusted contact.'
    Item 'Normal' 'Future work should raise automated coverage, add provider sandbox and delivery-status integration tests, complete a structured physical-device matrix, add accessibility testing with older adults, introduce operational dashboards and alerting, support secure cross-device synchronization for Oren state, and perform professional privacy, legal and security reviews. A production release should also define data retention, incident response, account recovery and support procedures.'
    Item 'H2' 'Issues and Solutions'
    Item 'Normal' 'A major issue was that phone-only background execution could not guarantee threshold processing after the app was closed. This was addressed by moving authoritative evaluation to a 15-minute Supabase Cron worker while retaining WorkManager for local reminders. Duplicate SMS risk was reduced through persisted stages, idempotency keys and delivery outboxes. OAuth users missing public profile rows were addressed with profile bootstrap logic. Private Legacy files were protected with RLS, private Storage and short-lived signed URLs. Repeated biometric prompts were addressed through asynchronous request coalescing and lifecycle-aware gating.'
    Item 'Normal' 'External delivery and platform behaviour remain the most important unresolved acceptance risks. The project therefore distinguishes a successful provider request from confirmed receipt and labels physical SMS, email, GPS, Android lifecycle and biometric-sensor tests separately from automated evidence.'
    Item 'H2' 'Conclusion'
    Item 'Normal' 'The completed prototype demonstrates that a friendly check-in experience can be combined with explicit safety rules, server scheduling and privacy-conscious Legacy controls. EthernaCare provides useful support and earlier notification, but it must be presented honestly as a supplementary well-being system rather than a guaranteed emergency or medical service. Within those boundaries, the project satisfies its main academic objectives and provides a maintainable foundation for further validation and development.'
  )
  Replace-Section-Body $document 'Discussions and Conclusion' 'References' $chapter7 'Heading 1' 'Heading 1'
  Insert-Chapter-Cover-BeforeHeading $document 'Discussions and Conclusion' 'Chapter 7'
  Insert-Section-Break-BeforeHeading $document 'References'

  # Add authoritative implementation references without removing the literature review sources.
  $technicalReferences = @(
    Item 'Normal' 'Android Developers. (n.d.). WorkManager overview. Retrieved August 3, 2026, from https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started'
    Item 'Normal' 'Brevo. (n.d.). Send a transactional email. Retrieved August 3, 2026, from https://developers.brevo.com/docs/send-a-transactional-email'
    Item 'Normal' 'Flutter. (n.d.). Guide to app architecture. Retrieved August 3, 2026, from https://docs.flutter.dev/app-architecture/guide'
    Item 'Normal' 'Flutter. (n.d.). local_auth package. Retrieved August 3, 2026, from https://pub.dev/packages/local_auth'
    Item 'Normal' 'Government of Malaysia. (n.d.). Weather API. Retrieved August 3, 2026, from https://developer.data.gov.my/realtime-api/weather'
    Item 'Normal' 'Supabase. (n.d.). Auth. Retrieved August 3, 2026, from https://supabase.com/docs/guides/auth'
    Item 'Normal' 'Supabase. (n.d.). Edge Functions. Retrieved August 3, 2026, from https://supabase.com/docs/guides/functions'
    Item 'Normal' 'Supabase. (n.d.). Row Level Security. Retrieved August 3, 2026, from https://supabase.com/docs/guides/database/postgres/row-level-security'
    Item 'Normal' 'Supabase. (n.d.). Scheduling Edge Functions. Retrieved August 3, 2026, from https://supabase.com/docs/guides/functions/schedule-functions'
    Item 'Normal' 'Twilio. (n.d.). Message resource. Retrieved August 3, 2026, from https://www.twilio.com/docs/messaging/api/message-resource'
  )
  Insert-Items-Before $document 'Appendices' $technicalReferences '' 0

  # Replace appendix instructions with concise, usable project guides.
  $appendices = @(
    Item 'H1' 'Appendix A: User Guide'
    Item 'H2' 'Account and Setup'
    Item 'Normal' 'Install or launch EthernaCare, create an account or continue with Google, complete email confirmation where required, accept the Terms and Conditions, complete the profile, verify the user phone and add a verified primary trusted contact. No shared demonstration password is embedded in the application.'
    Item 'H2' 'Daily Operation'
    Item 'Normal' 'Open Home and review Oren''s status and the Safety Monitor. Tap Oren when the rolling threshold allows a check-in. Feed and Play change Oren care state but do not count as a safety heartbeat. Use History to inspect successful timestamps, Contacts to manage the verified safety network, Rewards to collect virtual items and Profile to change threshold, escalation and biometric settings.'
    Item 'H2' 'Emergency and Legacy Functions'
    Item 'Normal' 'Use SOS only when a trusted contact should be notified; location is included only when permission and coordinates are available. Use the 999 action only for a real emergency because it opens an explicit call flow. In Legacy Planning, save funeral preferences, safe notes and supported private files, choose the authorised existing primary contact and enable release consent. Never store passwords, PINs, OTPs, recovery phrases or account credentials in Legacy Notes.'
    Item 'H1' 'Appendix B: Developer Guide'
    Item 'H2' 'Required Software'
    Item 'Normal' 'Flutter/Dart compatible with the project SDK constraint, Android Studio or Visual Studio Code, Android SDK for mobile builds, Visual Studio with Desktop development with C++ for Windows builds, Git, Node.js/npx for the Supabase CLI, and access to the configured Supabase project.'
    Item 'H2' 'Backend Setup'
    Item 'Normal' 'Apply SQL migrations in supabase/migrations in filename order. Deploy all functions in supabase/functions, configure encrypted Twilio, email, AI and OTP secrets, verify authentication redirect URLs and providers, confirm private Storage policies, and inspect the 15-minute threshold and midnight Legacy Cron jobs. Do not commit secret values or include them in screenshots.'
    Item 'H2' 'Verification'
    Item 'Normal' 'Run flutter analyze, flutter test --coverage and the required release builds. Confirm database migration parity and Edge Function health. Complete physical Android checks for notification permission, background/resume behaviour, biometric success/cancel/retry, GPS capture and real SMS/email receipt. Record provider message IDs and errors without exposing tokens.'
  )
  Replace-Section-Body $document 'Appendices' 'This page is intentionally left blank' $appendices '' '' 0 $true
  Set-Paragraph $document 'This page is intentionally left blank' '' $true

  Set-Section-Header $document 'Chapter 6' '' 'Chapter 6'
  Set-Section-Header $document 'System Deployment' 'Heading 1' 'Chapter 6'
  Set-Section-Header $document 'Chapter 7' '' 'Chapter 7'
  Set-Section-Header $document 'Discussions and Conclusion' 'Heading 1' 'Chapter 7'
  Set-Section-Header $document 'References' 'Heading 1' 'References'
  Set-Section-Header $document 'Appendix A: User Guide' 'Heading 1' 'Appendices'
  Clear-Cover-Header-BeforeHeading $document 'System Deployment'
  Clear-Cover-Header-BeforeHeading $document 'Discussions and Conclusion'

  # Refresh generated fields after all edits.
  foreach ($toc in @($document.TablesOfContents)) {
    $toc.Update() | Out-Null
  }
  $document.Fields.Update() | Out-Null
  $document.Repaginate()
  $document.Save()
  $document.ExportAsFixedFormat($PdfOutput, 17)

  "OUTPUT=$Output"
  "PDF=$PdfOutput"
  "PAGES=$($document.ComputeStatistics(2))"
}
finally {
  if ($null -ne $document) { $document.Close($false) }
  $word.Quit()
  [System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($word) | Out-Null
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
}
