param(
  [string]$Source = 'C:\Users\user\Downloads\RSW_OoKaiHeng(Reference lists added).docx',
  [string]$Output = 'C:\Users\user\StudioProjects\fyp\output\docs\EthernaCare_RSW_Chapters_5_6_2026.docx',
  [string]$PdfOutput = 'C:\Users\user\StudioProjects\fyp\output\docs\EthernaCare_RSW_Chapters_5_6_2026.pdf'
)

$ErrorActionPreference = 'Stop'

function Paragraph-Text($paragraph) {
  return ($paragraph.Range.Text -replace "[\r\a]", '').Trim()
}

function Paragraph-Style($paragraph) {
  try { return $paragraph.Range.Style.NameLocal } catch { return '' }
}

function Find-Paragraph($document, [string]$text, [int]$after = 0, [string]$styleLike = '', [bool]$contains = $false) {
  for ($i = [Math]::Max(1, $after + 1); $i -le $document.Paragraphs.Count; $i++) {
    $paragraph = $document.Paragraphs.Item($i)
    $value = Paragraph-Text $paragraph
    $matches = if ($contains) { $value.Contains($text) } else { $value -eq $text }
    if (-not $matches) { continue }
    if ($styleLike -and -not (Paragraph-Style $paragraph).Contains($styleLike)) { continue }
    return [PSCustomObject]@{ Index = $i; Paragraph = $paragraph }
  }
  throw "Paragraph not found: $text"
}

function Set-Paragraph($document, [string]$find, [string]$replacement, [bool]$contains = $false, [int]$after = 0) {
  $match = Find-Paragraph $document $find $after '' $contains
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
    'Code' {
      $paragraph.Range.Style = -1
      $paragraph.Range.Font.Name = 'Consolas'
      $paragraph.Range.Font.Size = 9
      $paragraph.Range.ParagraphFormat.LeftIndent = 18
      $paragraph.Range.ParagraphFormat.SpaceAfter = 0
      $paragraph.Range.Shading.BackgroundPatternColor = 15132390
    }
    default { $paragraph.Range.Style = -1 }
  }
}

function Replace-Section-Body($document, [string]$startText, [string]$endText, [array]$items, [string]$startStyle = '', [int]$after = 0) {
  $start = Find-Paragraph $document $startText $after $startStyle $false
  $end = Find-Paragraph $document $endText $start.Index '' $false
  $range = $document.Range($start.Paragraph.Range.End, $end.Paragraph.Range.Start)
  $range.Text = (($items | ForEach-Object { $_.Text }) -join "`r") + "`r"

  $cursor = (Find-Paragraph $document $startText $after $startStyle $false).Index
  foreach ($item in $items) {
    $match = Find-Paragraph $document $item.Text $cursor '' $false
    Set-Paragraph-Style $match.Paragraph $item.Style
    $cursor = $match.Index
  }
}

function Item([string]$style, [string]$text) {
  return [PSCustomObject]@{ Style = $style; Text = $text }
}

function Remove-Section($document, [string]$startText, [string]$endText, [string]$startStyle = 'Heading 1') {
  $start = Find-Paragraph $document $startText 0 $startStyle $false
  $end = Find-Paragraph $document $endText $start.Index 'Heading 1' $false
  $range = $document.Range($start.Paragraph.Range.Start, $end.Paragraph.Range.Start)
  $range.Delete() | Out-Null
}

function Normalize-Body-Paragraph($paragraph) {
  $paragraph.Range.Style = -1
  $paragraph.Range.Font.Name = 'Times New Roman'
  $paragraph.Range.Font.Size = 12
  $paragraph.Range.Font.Italic = 0
  $paragraph.Range.ParagraphFormat.Alignment = 3
  $paragraph.Range.ParagraphFormat.LeftIndent = 0
  $paragraph.Range.ParagraphFormat.RightIndent = 0
  $paragraph.Range.ParagraphFormat.FirstLineIndent = 0
  $paragraph.Range.ParagraphFormat.LineSpacingRule = 0
  $paragraph.Range.ParagraphFormat.SpaceAfter = 8
}

function Insert-Figure-At-Marker(
  $document,
  [string]$marker,
  [string]$imagePath,
  [string]$caption,
  [double]$width = 210
) {
  if (-not (Test-Path -LiteralPath $imagePath)) { throw "Figure image not found: $imagePath" }
  $match = Find-Paragraph $document $marker
  $range = $match.Paragraph.Range.Duplicate
  $range.End = $range.End - 1
  $range.Text = ''
  $range.Collapse(1)

  $picture = $document.InlineShapes.AddPicture($imagePath, $false, $true, $range)
  $picture.LockAspectRatio = -1
  $picture.Width = $width
  if ($picture.Height -gt 360) { $picture.Height = 360 }
  $picture.Range.ParagraphFormat.Alignment = 1
  $picture.Range.ParagraphFormat.SpaceAfter = 4

  $captionRange = $document.Range($picture.Range.End, $picture.Range.End)
  $captionRange.InsertAfter("`r$caption`r")
  $captionMatch = Find-Paragraph $document $caption $match.Index
  $captionMatch.Paragraph.Range.Style = -1
  $captionMatch.Paragraph.Range.Font.Name = 'Times New Roman'
  $captionMatch.Paragraph.Range.Font.Size = 10
  $captionMatch.Paragraph.Range.Font.Italic = -1
  $captionMatch.Paragraph.Range.ParagraphFormat.Alignment = 1
  $captionMatch.Paragraph.Range.ParagraphFormat.SpaceAfter = 10
}

if (-not (Test-Path -LiteralPath $Source)) { throw "Source document not found: $Source" }
$outputDirectory = Split-Path -Parent $Output
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
Copy-Item -LiteralPath $Source -Destination $Output -Force

$assetDirectory = Join-Path $outputDirectory '.rsw_chapter_assets'
if (Test-Path -LiteralPath $assetDirectory) {
  $resolvedAssets = [IO.Path]::GetFullPath($assetDirectory)
  $resolvedOutput = [IO.Path]::GetFullPath($outputDirectory)
  if (-not $resolvedAssets.StartsWith($resolvedOutput, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Unsafe temporary asset path: $resolvedAssets"
  }
  [IO.Directory]::Delete($resolvedAssets, $true)
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::ExtractToDirectory($Output, $assetDirectory)

$figureSource = Join-Path $outputDirectory 'EthernaCare_RSW_Aligned_2026.docx'
if (-not (Test-Path -LiteralPath $figureSource)) {
  throw "Representative screen source not found: $figureSource"
}
$figureAssetDirectory = Join-Path $outputDirectory '.rsw_figure_assets'
if (Test-Path -LiteralPath $figureAssetDirectory) {
  $resolvedFigureAssets = [IO.Path]::GetFullPath($figureAssetDirectory)
  $resolvedOutput = [IO.Path]::GetFullPath($outputDirectory)
  if (-not $resolvedFigureAssets.StartsWith($resolvedOutput, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Unsafe temporary figure path: $resolvedFigureAssets"
  }
  [IO.Directory]::Delete($resolvedFigureAssets, $true)
}
[IO.Compression.ZipFile]::ExtractToDirectory($figureSource, $figureAssetDirectory)

$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0
$document = $null

try {
  $document = $word.Documents.Open($Output)
  $document.TrackRevisions = $false

  Set-Paragraph $document 'EthernaCare is a mobile application created to address the issue of elderly individuals dying alone without being discovered in time.' @'
EthernaCare is a Flutter mobile application designed to support elderly people and independent individuals who live alone. It combines a daily virtual-pet check-in, configurable inactivity monitoring, trusted-contact escalation, location-assisted emergency records, rewards, legacy planning, weather-responsive visuals, and AI guidance. The objective is to reduce delayed awareness of prolonged inactivity while providing an accessible way to organize safety information and personal preferences.
'@.Trim() $true
  Set-Paragraph $document "The project features a gamified check-in mechanism using a virtual pet" @'
The daily safety signal is completed by tapping Oren, the virtual cat. Each successful daily check-in is stored in Supabase and can award Oren tokens and streak-based rewards. The Android app uses WorkManager for best-effort periodic inactivity checks. A local reminder counter progresses through three missed threshold windows; reminders 1 and 2 prompt the user, while reminder 3 starts the configured escalation. When the primary trusted contact option is selected, the app attempts an automated SMS and records the alert and available location. The app never automatically calls Malaysia's 999 service; a 999 call requires an explicit user action.
'@.Trim() $true
  Set-Paragraph $document 'The development of EthernaCare follows an Agile mobile application approach.' @'
The project follows an Agile approach. Flutter implements the responsive Android and web interface, while Supabase provides authentication, PostgreSQL data storage, Row Level Security, private file storage, and Edge Functions. Malaysia's official weather API is used first, with Open-Meteo as a location-based fallback. Gemini provides server-side AI guidance with a built-in offline fallback. SharedPreferences caches selected dashboard, weather, reward, chat, Oren, and inactivity state to reduce repeated network requests. Automated widget and logic tests verify the principal user flows, while external SMS, OAuth, weather, and AI providers require configured credentials and integration testing.
'@.Trim() $true

  $stakeholders = @(
    Item 'Normal' 'The primary user is an elderly person or independent individual living alone. The user registers or signs in, completes first-login profile and consent setup, verifies phone numbers, taps Oren for daily check-ins, manages trusted contacts, configures inactivity thresholds, views rewards and weather, uses AI guidance, and records legacy-planning information.'
    Item 'H3' 'Primary Trusted Contact'
    Item 'Normal' 'A trusted contact is an emergency recipient rather than a separate authenticated app role. The contact receives SMS follow-up when the user manually triggers an alert or reaches the configured inactivity escalation. One contact is designated as primary, and each stored contact number must be verified by SMS OTP before it can be saved.'
    Item 'H3' 'System Administrator / Developer'
    Item 'Normal' 'The administrator or developer maintains the Flutter application, Supabase schema and policies, storage bucket, Edge Functions, OAuth providers, API secrets, logs, backups, and releases. There is currently no administrator dashboard exposed inside the end-user application.'
  )
  Replace-Section-Body $document 'Stakeholders' 'Functional Requirements' $stakeholders 'Heading 3'

  $functional = @(
    Item 'H3' 'Module 1: Authentication, Onboarding, and Profile'
    Item 'Normal' 'Users can register with validated email and password credentials or sign in through configured OAuth providers. New accounts complete mandatory profile details, accept the Terms and Conditions, choose Malaysian state and region values, select a blood type, configure inactivity settings, and verify the user phone number by SMS OTP. OAuth users are linked to a public profile row so that all Supabase-backed modules use the authenticated user ID consistently (Supabase, n.d.-a).'
    Item 'H3' 'Module 2: Gamified Daily Check-In and Oren Care'
    Item 'Normal' 'Tapping Oren records at most one safety check-in per day, updates the history and streak, awards a daily token when eligible, and changes Oren mood and animation. Users can feed Oren, buy toys with Oren tokens, play with owned toys, hear interaction sounds, and return Oren to the default state after a short reaction.'
    Item 'H3' 'Module 3: Inactivity Monitoring and Emergency Response'
    Item 'Normal' 'The configurable inactivity threshold represents one missed check-in window. Android WorkManager performs best-effort periodic checks when operating-system constraints allow (Android Developers, n.d.). The app shows reminders 1/3, 2/3, and 3/3. On the third reminder it records an alert and starts the configured escalation. Primary-contact escalation attempts SMS delivery; 999 remains a manual dialer action. A separate safe test counter sends a clearly labelled test SMS on test reminder 3.'
    Item 'H3' 'Module 4: Trusted Contact and Location Management'
    Item 'Normal' 'Users can create, read, update, delete, and select one primary contact. Each account can store up to five contacts with validated name, relationship, international phone number, address, state, and region. Contact phone numbers require SMS OTP verification. Emergency alerts can store the device location and include a Google Maps link when location permission and positioning are available.'
    Item 'H3' 'Module 5: Rewards and Oren Shop'
    Item 'Normal' 'The reward service calculates streaks from check-in history, synchronizes the reward catalogue, caches reward snapshots locally, displays the next reward on the dashboard, and supports virtual voucher-style rewards. Oren tokens are separate local gamification currency used for toys and interactions.'
    Item 'H3' 'Module 6: Adaptive Malaysia Weather'
    Item 'Normal' 'The user selects a Malaysian state and region. The app requests the district or town forecast from the official data.gov.my Weather API and maps the returned Malay forecast summary to Oren backgrounds. If profile weather is unavailable, the app uses device coordinates with Open-Meteo. Successful weather responses are cached for 30 minutes (Government of Malaysia, n.d.; Open-Meteo, n.d.).'
    Item 'H3' 'Module 7: Legacy Planning'
    Item 'Normal' 'Users can create, edit, read, and delete legacy notes; save funeral preferences; and upload, open, or remove private PDF or image documents up to 10 MB. Notes reject common credential and recovery-secret terms. When the owner explicitly enables Legacy Checking, the SMS-verified primary contact can use the owner''s Legacy UID and a separate SMS OTP after 90 days without a check-in to view preferences and Legacy Notes without logging in. Secure documents are never released through this flow. EthernaCare stores completed documents but does not draft, validate, or notarize legal wills.'
    Item 'H3' 'Module 8: AI Guidance'
    Item 'Normal' 'The AI Guidance screen sends the latest question and up to ten recent chat messages to a secured Supabase Edge Function. Gemini is the preferred provider, with optional OpenAI or custom-provider fallback. Conversation history is cached locally. The assistant gives general information only, does not diagnose or provide legal advice, and directs immediate Malaysian emergencies to 999 (Google AI for Developers, n.d.; Supabase, n.d.-b).'
  )
  Replace-Section-Body $document 'Functional Requirements' 'Functions not included' $functional 'Heading 3'

  Set-Paragraph $document 'The system shall operate 24/7 without unexpected crashes during background execution.' 'On Android, inactivity checks shall use best-effort WorkManager scheduling and continue after normal app restarts when operating-system constraints permit. The system shall not claim exact-time or uninterrupted 24/7 execution.'
  Set-Paragraph $document 'The system shall provide confirmation prompts before triggering alerts to reduce false alarms.' 'Manual SOS and 999 actions shall use confirmation or explicit user actions. Automatic primary-contact escalation shall occur only after three missed threshold windows.'

  $useCases = @(
    Item 'Normal' 'Primary User - registers or signs in, completes onboarding, verifies a phone number, manages the profile and contacts, taps Oren to check in, uses Oren care and rewards, views weather, asks AI guidance, manages legacy planning, and triggers SOS.'
    Item 'Normal' 'Primary Trusted Contact - receives a verified, user-authorized emergency or test SMS. The contact does not log in to the current application.'
    Item 'Normal' 'External Services - Supabase provides authentication and protected data services; data.gov.my and Open-Meteo provide weather; Gemini provides AI content; Twilio or the Android SMS bridge provides SMS delivery; and device services provide location and notifications.'
    Item 'H3' 'Main Use Cases'
    Item 'Normal' 'Daily Check-In - the user taps Oren; the system prevents duplicate daily records, updates history and rewards, resets the current inactivity cycle, and refreshes the dashboard.'
    Item 'Normal' 'Inactivity Escalation - the scheduler calculates elapsed threshold windows, records reminder counts, shows three notifications, and starts the configured escalation on the third reminder without automatically calling 999.'
    Item 'Normal' 'Contact Management - the user validates and verifies a contact number, stores up to five contacts, selects one primary contact atomically, and can edit or delete owned records.'
    Item 'Normal' 'Legacy Planning - the user manages funeral preferences, notes, and private documents under authenticated ownership policies.'
    Item 'Normal' 'AI Guidance - the user asks a question, receives provider or offline guidance, and retains recent local chat history.'
  )
  Replace-Section-Body $document 'Use Case Actors' 'Chapter Summary and Evaluation' $useCases 'Heading 3'

  Set-Paragraph $document 'The three-tier architecture is selected for the EthernaCare system' @'
EthernaCare follows a layered Flutter client and cloud-service architecture. The Presentation layer contains responsive screens and reusable widgets. Controllers and services coordinate validation, check-ins, inactivity policy, rewards, weather, AI, notifications, SMS, Oren care, and local caching. Repository classes isolate Supabase Auth, PostgreSQL, Storage, and Edge Function access. Models provide typed serialization, while Android background components invoke the inactivity service outside the foreground UI. This separation follows Flutter guidance that distinguishes UI responsibilities from repositories and services in the data layer (Flutter, n.d.).
'@.Trim() $true
  Set-Paragraph $document 'The Business Logic layer serves as the core processing unit' @'
The business and service layer applies application rules, including one check-in per day, reward synchronization, contact validation, primary-contact selection, three-stage inactivity escalation, safe test flows, weather caching, AI fallback behavior, and Oren state transitions. Controllers remain thin and delegate reusable work to services.
'@.Trim() $true
  Set-Paragraph $document 'The Data Access layer is responsible for managing all interactions' @'
The Data Access layer contains repositories for authentication, users, check-ins, contacts, rewards, emergencies, legacy planning, and documents. Repositories use the authenticated Supabase session and RLS-protected tables. Edge Functions hold third-party secrets and integrate Gemini, Twilio, and phone OTP delivery without exposing provider credentials in the Flutter client (Supabase, n.d.-b; Supabase, n.d.-c).
'@.Trim() $true

  Set-Paragraph $document 'The login activity begins when the user opens the application' @'
The login flow validates email and password inputs or starts a configured OAuth provider. Supabase creates a JWT-backed session and the app ensures that an associated public user profile exists. A new account is routed through mandatory profile, Terms and Conditions, user-phone OTP, and primary-contact OTP setup before reaching the dashboard. Returning users with complete setup proceed directly to the home screen. Friendly error dialogs replace raw provider exceptions.
'@.Trim() $true
  Set-Paragraph $document 'The virtual petting process serves as the primary check-in mechanism' @'
The user taps Oren directly rather than pressing a separate Pet button. The repository checks for an existing record in the current local day and inserts a new Supabase check-in only when one does not exist. The service then refreshes the dashboard, streak, rewards, Oren tokens, mood, sound, and interaction animation. A completed check-in also makes any earlier local inactivity reminder state obsolete.
'@.Trim() $true
  Set-Paragraph $document 'Gemini said The Emergency Alert process' @'
The emergency process supports manual SOS and automatic inactivity escalation. For inactivity, the service divides elapsed time since the latest check-in by the user's configured threshold. It shows one local notification per missed window and records a visible 0/3 to 3/3 dashboard counter. Reminder 3 starts escalation. If the profile target is the primary trusted contact, the app retrieves that contact, records an emergency alert, attempts Android SMS, and otherwise queues a Twilio Edge Function delivery with retry information. Location is attached when available. If the user selects 999, the inactivity event records a critical notice but does not automatically dial emergency services. Test alerts are stored separately and cannot suppress or duplicate real alerts.
'@.Trim() $true

  $entities = @(
    Item 'H3' 'User'
    Item 'Normal' 'Attributes: id, name, email identity, phone, phone_verified_at, address, address_state, address_region, blood_type, inactivity_threshold, emergency_escalation_target, terms_version, terms_accepted_at, and profile_completed_at. Age is not collected.'
    Item 'H3' 'Contact'
    Item 'Normal' 'Attributes: id, user_id, name, relationship, phone, phone_verified_at, address, address_state, address_region, and is_primary. One user owns up to five contacts and one primary contact.'
    Item 'H3' 'Check-In'
    Item 'Normal' 'Attributes: id, user_id, checkin_time, and status. A user owns many daily activity records.'
    Item 'H3' 'Emergency Alert and Location'
    Item 'Normal' 'Emergency alerts contain id, user_id, triggered_time, and status. Optional location records contain alert_id, latitude, longitude, and timestamp.'
    Item 'H3' 'Reward and Reward Catalogue'
    Item 'Normal' 'User rewards contain streak, reward type/code, status, earned and redeemed timestamps. The catalogue stores title, sponsor, milestone, kind, voucher value, version, and active state.'
    Item 'H3' 'Legacy Planning'
    Item 'Normal' 'Funeral preferences are one-to-one with the user. Legacy notes and secure documents are one-to-many. Documents store private storage paths and upload timestamps.'
    Item 'H3' 'SMS Delivery and Phone Verification'
    Item 'Normal' 'The emergency delivery outbox stores contact, message, provider, attempts, status, errors, and processed time. OTP records store only a code hash, purpose, expiry, consumption state, and attempt count; successful verification records are retained separately.'
  )
  Replace-Section-Body $document 'Entities attributes' 'ERD Relationships' $entities 'Heading 3'

  $security = @(
    Item 'H3' 'Authentication and Access Control'
    Item 'Normal' 'Supabase Auth supports email/password and configured OAuth providers. Authenticated sessions use JWTs. A database trigger creates the matching public profile for email and OAuth accounts so every repository uses the same authenticated user ID (Supabase, n.d.-a).'
    Item 'H3' 'Row Level Security and Private Storage'
    Item 'Normal' 'RLS is enabled on exposed user-owned tables. Policies compare auth.uid() with id or user_id for select, insert, update, and delete operations. The legacy-documents bucket is private and storage policies restrict paths to the authenticated user folder (Supabase, n.d.-c).'
    Item 'H3' 'Phone Verification and Input Validation'
    Item 'Normal' 'Six-digit OTP codes are generated server-side, stored as hashes with expiry and attempt limits, and delivered through an Edge Function. Database triggers reject changed profile or contact phone numbers that do not have a recent successful verification. Client and database validation also enforce name, password, phone, address, contact-count, and primary-contact rules.'
    Item 'H3' 'Secrets and Secure Communication'
    Item 'Normal' 'The Flutter client communicates through HTTPS. Gemini, Twilio, SMS worker, and OTP secrets are stored as Supabase Edge Function environment secrets rather than in source code. Edge Functions validate authenticated users or a worker secret before privileged operations (Supabase, n.d.-b).'
  )
  Replace-Section-Body $document 'Security Handling' 'UI Prototype' $security 'Heading 2'

  Set-Paragraph $document 'The home page interface is designed for maximum simplicity' @'
The current home page uses a responsive premium dashboard. Oren appears at the top as the direct check-in target and changes pixel-art mood, energy, interaction, selected toy, and weather background. Feed Fish and Play are presented together below the Oren scene, while the token balance and shop controls support toy purchase and selection. The Safety Monitor is positioned lower on the page and shows real inactivity reminder progress, a separate three-step test action, emergency state, SOS, and SMS testing. Contextual guidance, scroll cues, and safe-area spacing support small Android screens.
'@.Trim() $true
  Set-Paragraph $document 'Gemini said The Emergency Contacts page' @'
The Emergency Contacts page lists up to five owned contacts with name, relationship, verified international phone number, address, state, and region. A star action changes the primary contact through an atomic database function, while edit and delete operations refresh the interface immediately. Adding or changing a phone number requires SMS OTP verification.
'@.Trim() $true
  Set-Paragraph $document 'The Rewards page serves as the primary incentive hub' @'
The Rewards page combines server-backed streak rewards and locally cached reward catalogue data with Oren tokens and toys. The dashboard shows the next milestone reward, while the Oren shop allows owned toys to be purchased and used. Reward examples include virtual sponsor vouchers rather than guaranteed physical inventory.
'@.Trim() $true
  Set-Paragraph $document 'The My Profile page serves as a centralized hub' @'
The Profile page displays name, verified phone, home address, Malaysian state and region, blood type, inactivity threshold, and escalation target. Age has been removed. Editing uses a full-page responsive form, country calling-code selection, validation, blood-type selection, and OTP verification when the phone number changes. The page provides a copyable Legacy UID, contextual guidance, AI Guidance, and Legacy Planning access.
'@.Trim() $true

  $chapter5 = @(
    Item 'H2' '5.1 Introduction'
    Item 'Normal' 'This chapter explains how EthernaCare was translated from the requirements and system design into a working Flutter application. It follows the prescribed implementation structure by describing the development tools, implemented modules, representative code, sample screens, functional testing, non-functional testing, and the final module-based test plan.'
    Item 'Normal' 'Implementation was incremental. Each module was developed around a service or repository boundary, connected to the responsive presentation layer, and then checked with automated Flutter tests and manual walkthroughs. High-risk behavior such as inactivity escalation, SMS delivery, phone verification, private documents, Legacy Checking, and emergency calling was kept explicit and auditable.'
    Item 'H2' '5.2 System Implementation'
    Item 'Normal' 'EthernaCare uses a layered mobile-and-cloud architecture. Flutter widgets form the presentation layer; controllers and services apply reusable application rules; repositories isolate Supabase Auth, PostgreSQL, Storage, and Edge Function calls; typed models serialize data; and Android WorkManager invokes best-effort inactivity checks outside the foreground interface. SharedPreferences supplies per-user local caching for dashboard, weather, chat, rewards, Oren care, and reminder state.'
    Item 'H3' '5.2.1 Development Tools and Technologies'
    Item 'H4' 'Flutter and Dart'
    Item 'Normal' 'Flutter 3 with Dart implements the Android, Windows, and web-capable interface from one codebase. Material 3 components, responsive constraints, safe areas, scrolling forms, semantic labels, and reusable widgets support consistent behavior across compact and wide viewports. The pubspec uses Dart SDK 3.10.4 or later and declares packages for Supabase, Riverpod, HTTP, location, notifications, WorkManager, caching, file selection, audio, and URL launching.'
    Item 'H4' 'Supabase and PostgreSQL'
    Item 'Normal' 'Supabase provides email/password and OAuth authentication, PostgreSQL tables, Row Level Security, private Storage, remote procedure calls, and Edge Functions. SQL files in the repository are idempotent where practical so schema repairs, phone verification, document storage, legacy access, contact constraints, and OAuth profile bootstrap can be audited and applied independently (Supabase, n.d.-a; Supabase, n.d.-b; Supabase, n.d.-c).'
    Item 'H4' 'Android and External Services'
    Item 'Normal' 'Android WorkManager performs a connected periodic task every 15 minutes when operating-system constraints allow. Local notifications present reminder stages. Device location can be attached to an alert, and direct SMS is attempted only with permission. Twilio is the server-side SMS alternative. The official Malaysia weather API is preferred for the selected region, Open-Meteo is the fallback, and Gemini is the preferred AI provider (Android Developers, n.d.; Government of Malaysia, n.d.; Google AI for Developers, n.d.; Open-Meteo, n.d.; Twilio, n.d.).'
    Item 'H4' 'Development and Verification Utilities'
    Item 'Normal' 'Android Studio, the Android SDK, Git, PowerShell, the Supabase CLI through npx, Flutter Test, and the recommended Flutter lints support development and verification. Word and PDF rendering are used to maintain the report artefacts. API credentials are stored as Supabase project secrets and are not committed to the Flutter source.'
    Item 'H3' '5.2.2 Modules and Code Snippets'
    Item 'H4' 'Authentication, Onboarding, and Profile Module'
    Item 'Normal' 'AuthRepository encapsulates registration, email sign-in, signup-code verification, resend verification, Google OAuth, and sign-out. AuthGate routes authenticated users through mandatory profile completion, Terms and Conditions, phone OTP verification, primary-contact setup, and the first-login tutorial. An authentication trigger and backfill create the matching public.users row for both email and OAuth identities so all repositories use the same authenticated UUID.'
    Item 'Code' 'final response = await client.auth.signInWithPassword(email: email, password: password);'
    Item 'Code' 'await userRepository.createProfileIfMissing(userId: user.id, email: user.email);'
    Item 'H4' 'Daily Check-In, Oren Care, and Rewards Module'
    Item 'Normal' 'Oren is the direct daily check-in control. CheckinRepository first searches the current local calendar day and inserts only when no row exists. After a successful or already-existing check-in, the dashboard, streak, reward snapshot, Oren token balance, mood, energy, sound, and selected-toy reaction are refreshed. OrenCareService stores tokens, owned toys, selected toy, mood, energy, and daily reward dates under a user-specific cache key, so signing out and signing back in does not reset the shop state.'
    Item 'Code' 'if (existing.isNotEmpty) return false;'
    Item 'Code' 'await client.from(''checkins'').insert({''user_id'': userId, ''checkin_time'': now.toIso8601String(), ''status'': ''active''});'
    Item 'H4' 'Inactivity Monitoring and Emergency Response Module'
    Item 'Normal' 'InactivityService converts elapsed time into missed threshold windows. Reminder 1 and reminder 2 notify the user. Reminder 3 records an emergency event and starts the configured escalation without automatically calling Malaysia''s 999 service. EmergencyService obtains the primary contact, records location when available, attempts direct-device SMS, and otherwise creates or processes a server delivery. A separate test counter uses clearly labelled messages and cannot silently become a real emergency event.'
    Item 'Code' 'missedCheckIns = elapsed.inSeconds ~/ Duration(hours: threshold).inSeconds;'
    Item 'Code' 'if (missedCheckIns >= 3) await emergencyService.triggerEmergencyDetailed(allow999Dialer: false, sendAutomatedSms: true);'
    Item 'H4' 'Trusted Contacts, OTP, and Location Module'
    Item 'Normal' 'Users manage up to five contacts through full-page add and edit forms. Validation covers name, relationship, international phone, address, state, region, duplicate numbers, and primary-contact rules. A changed number must have a recent phone_verifications record before a database trigger accepts it. Contact ownership is enforced with RLS, while an atomic RPC and unique partial index preserve one primary contact. SOS and inactivity alerts use the primary contact and include a Google Maps link when location permission is available.'
    Item 'Code' 'create policy "contacts_select_own" on public.contacts for select'
    Item 'Code' 'to authenticated using ((select auth.uid()) = user_id);'
    Item 'H4' 'Weather, AI Guidance, and Local Cache Module'
    Item 'Normal' 'WeatherService first requests the selected Malaysian region from data.gov.my, maps Malay and English summaries to clear, cloudy, rain, and thunderstorm scenes, and caches successful data for 30 minutes. Device-coordinate Open-Meteo data is used only as a fallback. AiService sends the latest question and limited local conversation history to a secured Edge Function and returns a safety-oriented offline answer when the provider is unavailable.'
    Item 'H4' 'Legacy Planning, Secure Documents, and Legacy Checking Module'
    Item 'Normal' 'DocumentService loads funeral preferences, Legacy Notes, secure document metadata, and the owner''s Legacy Checking consent together. Notes support CRUD but reject common credential terms and secret-value patterns. File upload accepts PDF, JPG, JPEG, and PNG up to 10 MB, validates the extension and binary signature, stores the object in a private user folder, and opens it through a short-lived signed URL. Deletion removes both metadata and the private object.'
    Item 'Code' 'if (fileSize > maxDocumentBytes) throw StateError(''Document must not exceed 10 MB.'');'
    Item 'Code' 'if (!_matchesDocumentSignature(extension, bytes)) throw StateError(''The file content does not match its extension.'');'
    Item 'Normal' 'Legacy Checking is intentionally separate from ordinary authentication. The owner copies a Legacy UID from Profile and explicitly enables access. After at least 90 days without check-in activity, the verified primary contact can request a dedicated SMS code and view only funeral preferences and Legacy Notes for a ten-minute foreground session. Secure documents, account credentials, and general profile data are excluded. The SQL and Edge Function source are implemented locally; cloud deployment and end-to-end SMS verification remain required before production use.'
    Item 'Code' 'export const legacyInactivityDays = 90;'
    Item 'Code' 'if (Date.now() - lastActivityMs < legacyInactivityDays * 86400000) denyLegacyAccess();'
    Item 'H4' 'Responsive Guidance and Error Handling'
    Item 'Normal' 'Contextual information buttons open a reusable scrollable guidance sheet. The Profile guide explains tabs, Oren, tokens, contacts, SOS, and status colours; Legacy Planning and Legacy Check guides explain privacy and access conditions. Raw Supabase and provider exceptions are converted into task-specific dialogs, while layouts use stable dimensions, full-page forms, scrolling, tooltips, and responsive text constraints.'
    Item 'H3' '5.2.3 Sample Screens'
    Item 'Normal' 'The following screens demonstrate the major interaction modules. Figures 5.1 to 5.4 are representative captures from the application report build. Figure 5.5 is retained as an earlier profile prototype to document the UI evaluation that led to the current full-page editor, Malaysian address fields, copyable Legacy UID, and removal of age and date-of-birth collection.'
    Item 'Normal' 'FIGURE_HOME_PLACEHOLDER'
    Item 'Normal' 'FIGURE_HISTORY_PLACEHOLDER'
    Item 'Normal' 'FIGURE_CONTACTS_PLACEHOLDER'
    Item 'Normal' 'FIGURE_REWARDS_PLACEHOLDER'
    Item 'Normal' 'FIGURE_PROFILE_PLACEHOLDER'
    Item 'Normal' 'The prototype reward wording and profile sample data shown in Figures 5.4 and 5.5 are not production promises or current data fields. The current rewards are virtual catalogue examples, and the current Profile does not collect age or date of birth.'
    Item 'H2' '5.3 Testing Strategies'
    Item 'Normal' 'Testing was performed continuously during Agile iterations. Automated tests verify deterministic logic and widget behavior, while manual integration and system walkthroughs cover flows that depend on Supabase, Android permissions, background scheduling, OAuth, SMS, location, weather, and AI services. The current Flutter suite contains 34 passing tests: 23 logic or model tests and 11 widget tests.'
    Item 'H3' '5.3.1 Functional Testing'
    Item 'H4' 'Unit Testing'
    Item 'Normal' 'Unit tests validate inactivity boundaries, the three-step reminder cycle, streak calculation, reward and Oren serialization, per-user cache preservation, weather mapping, validation limits, onboarding rules, funeral-preference serialization, Legacy Note security, document file signatures and size limits, Legacy Checking payload filtering, AI fallback behavior, and chat-history serialization. These tests isolate predictable rules without requiring a live provider.'
    Item 'H4' 'Widget and Component Testing'
    Item 'Normal' 'Widget tests render the tutorial, responsive guidance sheet, bounded action rows, shared controls, Oren check-in and energy states, Add Contact validation, and Edit Profile validation. A 360 by 640 viewport is included for the guidance sheet to detect overflow and ensure that confirmation controls remain reachable.'
    Item 'H4' 'Integration Testing'
    Item 'Normal' 'Repository and service boundaries were exercised through development builds against the configured Supabase project, including authentication, profile loading, contacts, check-ins, rewards, weather, and document metadata. Provider-dependent flows require valid remote migrations, deployed Edge Functions, Android permissions, and secrets. A dedicated automated integration_test suite is not yet included, so OAuth, Twilio delivery, phone OTP, Legacy Checking OTP, Gemini, location, and WorkManager behavior are listed separately as deployment-environment tests rather than reported as automated passes.'
    Item 'H4' 'System Testing'
    Item 'Normal' 'System walkthroughs followed the main user journey: account access, first-login setup, profile editing, contact verification, Oren check-in, history refresh, rewards, weather, inactivity reminder testing, AI guidance, Legacy Planning, and file validation. The walkthroughs exposed and corrected blank post-login routing, stale OAuth profile data, small dialog forms, setState asynchronous callbacks, weather scenes that repeatedly appeared rainy, local Oren state reset, and inconsistent emergency presentation.'
    Item 'H4' 'User Acceptance Testing'
    Item 'Normal' 'Developer-supervised acceptance checks were performed iteratively using direct user feedback on screenshots and working builds. Feedback resulted in full-page contact and profile forms, simpler Oren check-in, clearer region labels, scroll cues, consistent emergency controls, distinct Oren reactions, contextual guidance, and safer Legacy Notes. This is formative acceptance testing; a formal study with elderly participants, measured task completion, and accessibility instruments remains future work.'
    Item 'H3' '5.3.2 Non-Functional Testing'
    Item 'H4' 'Reliability Testing'
    Item 'Normal' 'The 24, 48, and 72-hour boundary test confirms reminder counts of 1, 2, and 3 for a 24-hour threshold. Duplicate reminders and duplicate daily check-ins are suppressed, Oren state is preserved per user, and provider calls use retry or fallback behavior where implemented. WorkManager scheduling is best-effort, so exact execution timing, force-stop recovery, and restart behavior must be verified on physical Android devices rather than claimed as continuous 24/7 monitoring.'
    Item 'H4' 'Usability and Accessibility Testing'
    Item 'Normal' 'Compact widget tests check overflow, while manual review checks safe areas, scrolling, touch targets, labels, tooltips, contrast, information hierarchy, and full-page input forms. The first-login tutorial and contextual guides reduce reliance on prior knowledge of Oren or safety terminology. Formal accessibility audits, screen-reader studies, and elderly-user task measurements are not yet complete.'
    Item 'H4' 'Performance Efficiency Testing'
    Item 'Normal' 'Cache-first loading reduces repeated Supabase and weather calls, weather data is retained for 30 minutes, AI history is limited, and the background task runs at the platform minimum periodic interval rather than continuously. Development builds were checked for responsive interaction and absence of obvious lag. Formal CPU, memory, battery, network, and load benchmarks have not yet been conducted and remain a release-readiness activity.'
    Item 'H4' 'Security Testing'
    Item 'Normal' 'Security-oriented tests and review cover validated authentication inputs, hashed and expiring OTP records, recent-phone-verification triggers, RLS ownership checks, private storage paths, signed document URLs, file magic-byte validation, Legacy Note credential rejection, dedicated Legacy access OTPs, release-field filtering, foreground timeout, and audit events. Production assurance still depends on applying the supplied SQL, deploying the intended Edge Functions, rotating exposed secrets, and reviewing Supabase policies in the deployed project.'
    Item 'H4' 'Compatibility and Maintainability Testing'
    Item 'Normal' 'The same widgets are exercised at compact phone dimensions and compile for Flutter''s supported targets, while Android-specific behavior is isolated behind platform components. Models, services, repositories, and screens are separated so external providers and UI layouts can change independently. The automated architecture and serialization checks reduce regression risk, but a broader physical-device and OS-version matrix is still required.'
    Item 'H2' '5.4 Test Plan and Test Cases'
    Item 'Normal' 'The test plan below is arranged by functional module as required by the supplied Chapter 5 guide. Pass indicates a reproducible automated test in the current suite. Configuration required identifies a valid test case whose result depends on remote deployment, credentials, a physical device, or a consented SMS recipient and therefore must not be presented as an automated pass.'
    Item 'Normal' 'TEST CASE MATRIX PLACEHOLDER'
    Item 'Normal' 'The matrix demonstrates broad automated coverage of core rules and responsive components, while clearly separating external integration work. This distinction is important because a passing model or widget test cannot prove Twilio delivery, Google OAuth redirect configuration, Android background timing, or remote RLS deployment.'
  )
  Replace-Section-Body $document 'Implementation and Testing' 'Chapter Summary and Evaluation' $chapter5 'Heading 1'
  $chapter5Title = Find-Paragraph $document 'Implementation and Testing' 0 'Heading 1'
  $chapter5Title.Paragraph.Range.ListFormat.RemoveNumbers() | Out-Null
  $chapter5TitleRange = $chapter5Title.Paragraph.Range.Duplicate
  $chapter5TitleRange.End = $chapter5TitleRange.End - 1
  $chapter5TitleRange.Text = '5 Implementation'
  Set-Paragraph $document 'Implementation and Testing' 'Implementation'
  $chapter5Summary = Find-Paragraph $document 'Chapter Summary and Evaluation' $chapter5Title.Index
  $chapter5Summary.Paragraph.Range.ListFormat.RemoveNumbers() | Out-Null
  $chapter5SummaryRange = $chapter5Summary.Paragraph.Range.Duplicate
  $chapter5SummaryRange.End = $chapter5SummaryRange.End - 1
  $chapter5SummaryRange.Text = '5.5 Chapter Summary and Evaluation'
  Set-Paragraph $document 'At the end of each chapter, evaluate the contents stated or discussed in the relevant sub-sections.' 'This chapter implemented the required Flutter and Supabase modules, documented representative code and screens, and evaluated both functional and non-functional testing. Thirty-four automated tests pass for deterministic logic and widget behavior. External OAuth, SMS, OTP, AI, location, background execution, and deployed-policy checks remain explicitly identified as integration work. The implementation therefore satisfies the principal software requirements while avoiding unsupported claims about third-party delivery or exact-time emergency monitoring.'
  $chapter5SummaryBody = Find-Paragraph $document 'This chapter implemented the required Flutter and Supabase modules' $chapter5Title.Index '' $true
  Normalize-Body-Paragraph $chapter5SummaryBody.Paragraph

  $document.Save()
  $document.Close($false)
  $document = $word.Documents.Open($Output)

  Insert-Figure-At-Marker $document 'FIGURE_HOME_PLACEHOLDER' (Join-Path $figureAssetDirectory 'word\media\image15.png') 'Figure 5.1: Home and Oren daily check-in module' 205
  Insert-Figure-At-Marker $document 'FIGURE_HISTORY_PLACEHOLDER' (Join-Path $figureAssetDirectory 'word\media\image5.png') 'Figure 5.2: Check-in History module' 205
  Insert-Figure-At-Marker $document 'FIGURE_CONTACTS_PLACEHOLDER' (Join-Path $figureAssetDirectory 'word\media\image6.png') 'Figure 5.3: Trusted Contacts module' 205
  Insert-Figure-At-Marker $document 'FIGURE_REWARDS_PLACEHOLDER' (Join-Path $figureAssetDirectory 'word\media\image16.png') 'Figure 5.4: Rewards module' 205
  Insert-Figure-At-Marker $document 'FIGURE_PROFILE_PLACEHOLDER' (Join-Path $figureAssetDirectory 'word\media\image17.png') 'Figure 5.5: Earlier Profile prototype used during UI evaluation' 205

  $tokenRange = $document.Content.Duplicate
  $tokenRange.Find.ClearFormatting()
  $markerFound = $tokenRange.Find.Execute('TEST CASE MATRIX PLACEHOLDER')
  if (-not $markerFound) { throw 'Test table insertion point was not found.' }
  $tokenRange.Text = ''
  $tokenRange.Collapse(1)
  $tests = @(
    @('TC01','Authentication','Validate email/password and OAuth screen states','Enter invalid and valid credentials; inspect validation and routing','Invalid input is blocked; a valid session routes through setup','Pass'),
    @('TC02','Onboarding/Profile','Enforce mandatory first-login setup','Leave required values empty, then complete profile, terms and phone state','Incomplete setup remains blocked; complete setup can continue','Pass'),
    @('TC03','Check-In/Oren','Prevent duplicate daily check-ins','Tap Oren twice on the same local day','Only one daily record is eligible; the UI refreshes without duplication','Pass'),
    @('TC04','Oren Care','Restore per-user shop and interaction state','Serialize tokens, toys, selected toy, mood and energy; reload the same user','The same user receives the saved Oren state after reload','Pass'),
    @('TC05','Inactivity','Calculate three missed threshold windows','Evaluate elapsed times at 24, 48 and 72 hours for a 24-hour threshold','Reminder counts are 1/3, 2/3 and 3/3 respectively','Pass'),
    @('TC06','Reminder Test','Keep testing separate from real emergencies','Trigger the dashboard test action three times','The third action starts a clearly labelled test SMS flow only','Pass'),
    @('TC07','Contacts','Validate contact data and primary-contact rules','Test names, phone digits, addresses, duplicates, limit and primary selection','Invalid data is rejected and only one contact is primary','Pass'),
    @('TC08','Phone OTP','Verify profile and contact phone delivery','Deploy functions and secrets; request and submit a code on a consented phone','A valid code creates verification; invalid or expired codes fail','Configuration required'),
    @('TC09','Rewards','Calculate streaks and restore reward snapshots','Load dated check-ins, reward catalogue and cached token data','Streak, next reward, tokens and owned items are consistent','Pass'),
    @('TC10','Weather','Map forecast summaries to Oren scenes','Provide clear, cloudy, rain, thunderstorm and night forecast samples','Each summary selects the intended scene without defaulting to rain','Pass'),
    @('TC11','Legacy Preferences','Serialize and restore funeral preferences','Save religion, service type, authorized contact and wishes, then reload','All selected and entered values are preserved','Pass'),
    @('TC12','Legacy Notes','Reject credentials and support safe note CRUD','Try password/recovery terms, then create, edit and delete a normal note','Secret-like content is blocked; safe notes complete CRUD','Pass'),
    @('TC13','Secure Documents','Validate uploaded document size and signature','Test valid PDF/PNG/JPEG plus oversized and mismatched files','Only supported files up to 10 MB with matching signatures are accepted','Pass'),
    @('TC14','Legacy Checking','Release only authorized legacy fields','Build a release payload containing preferences, notes and private fields','Only preferences and notes remain; documents and profile data are excluded','Pass'),
    @('TC15','Guidance/UI','Keep contextual help reachable on a compact screen','Render guidance and action rows at 360 by 640 pixels','Content scrolls without overflow and controls remain reachable','Pass'),
    @('TC16','AI Guidance','Restore history and provide a safe offline fallback','Serialize recent messages and simulate unavailable AI service','History restores and general fallback guidance is returned','Pass'),
    @('TC17','External Services','Verify live provider and Android integrations','Test Google OAuth, Twilio SMS, Gemini, location and WorkManager on deployment','Configured services complete with logs, permissions and delivery evidence','Integration setup required')
  )
  $table = $document.Tables.Add($tokenRange, $tests.Count + 1, 6)
  $headers = @('ID','Module','Test scenario','Test steps / data','Expected result','Status')
  for ($c=1; $c -le 6; $c++) { $table.Cell(1,$c).Range.Text = $headers[$c-1] }
  for ($r=0; $r -lt $tests.Count; $r++) {
    for ($c=0; $c -lt 6; $c++) { $table.Cell($r+2,$c+1).Range.Text = $tests[$r][$c] }
  }
  $table.Style = 'Table Grid'
  $table.Rows.Item(1).Range.Bold = 1
  $table.Rows.Item(1).HeadingFormat = -1
  $table.Range.Font.Name = 'Times New Roman'
  $table.Range.Font.Size = 8
  $table.AllowAutoFit = $false
  $table.Rows.AllowBreakAcrossPages = 0
  $table.Columns.Item(1).PreferredWidth = 30
  $table.Columns.Item(2).PreferredWidth = 60
  $table.Columns.Item(3).PreferredWidth = 90
  $table.Columns.Item(4).PreferredWidth = 105
  $table.Columns.Item(5).PreferredWidth = 105
  $table.Columns.Item(6).PreferredWidth = 75

  $chapter6 = @(
    Item 'H2' '6.1 Summary'
    Item 'Normal' 'EthernaCare was developed as an accessible safety and legacy-planning application for elderly people and independent individuals who live alone. It uses a friendly virtual cat as a daily activity signal, applies measured inactivity escalation, protects user-owned cloud records, and presents supporting weather, rewards, AI guidance, contacts, and legacy-planning functions in one Flutter application.'
    Item 'H3' '6.1.1 Project Objectives and Achievement'
    Item 'Normal' 'The first objective was to use a gamified virtual-cat interaction to confirm that a user is active. This objective was achieved through direct Oren check-in, one-record-per-day protection, history, token rewards, mood and energy changes, toys, and a three-stage inactivity reminder process. The experience is less clinical than a conventional monitoring form while still producing an auditable activity record.'
    Item 'Normal' 'The second objective was to help users prepare post-death information. This objective was achieved through funeral-preference fields, selection of an authorized existing contact, safe Legacy Note CRUD, and private PDF or image document storage. Legacy Checking extends the design by allowing an explicitly authorized, verified primary contact to view only preferences and notes after 90 days of inactivity. The cloud deployment of its dedicated OTP functions remains a required production step.'
    Item 'Normal' 'The third objective was to provide basic AI-assisted information. This objective was achieved through AI Guidance with recent chat history, a secured provider function, safety boundaries, and an offline fallback. The system provides general guidance rather than medical, legal, or emergency diagnosis. Collectively, these objectives support SDG 3 by combining well-being, safety awareness, dignity, and family preparedness.'
    Item 'H3' '6.1.2 Overall System or Product Developed'
    Item 'Normal' 'The resulting product is a responsive Flutter application with five primary navigation areas: Home, History, Contacts, Rewards, and Profile. Home contains Oren, the selected regional weather scene, care actions, token and shop controls, the next reward, and a lower Safety Monitor. Additional full-page flows cover onboarding, profile editing, contact verification, AI Guidance, Legacy Planning, secure documents, and public Legacy Checking.'
    Item 'H3' '6.1.3 Methods and Tools Used'
    Item 'Normal' 'Agile iteration was used to refine requirements and repair issues discovered through screenshots, working builds, schema errors, provider responses, and user feedback. Flutter and Dart implemented the client; Riverpod, services, repositories, and typed models separated concerns; Supabase supplied Auth, PostgreSQL, RLS, Storage, RPCs, and Edge Functions; SharedPreferences supplied local per-user caching; and Android notifications, location, WorkManager, and SMS bridges supported safety behavior. Flutter Test, SQL audits, Git, Android Studio, Supabase CLI, PowerShell, Word, and PDF review supported implementation and verification.'
    Item 'H3' '6.1.4 Outcome and System Performances'
    Item 'Normal' 'The deterministic application logic and responsive components currently pass 34 automated tests, comprising 23 logic or model tests and 11 widget tests. Cache-first reads and a 30-minute weather cache reduce repeated network calls, while bounded histories and periodic background work limit unnecessary processing. Compact-screen tests confirm reachable scrollable guidance and stable controls. Formal battery, memory, network-load, accessibility, and elderly-participant benchmarks have not yet been completed; provider-dependent performance also remains subject to deployment configuration and third-party availability.'
    Item 'H2' '6.2 Achievements & Contribution'
    Item 'H3' '6.2.1 System Achievements'
    Item 'Normal' 'The project implements email and Google-capable authentication, OAuth profile bootstrap, mandatory first-login setup, verified profile and contact phones, trusted-contact CRUD, direct Oren check-in, immediate history refresh, rewards, persistent Oren tokens and toys, region-based weather, local reminders, inactivity escalation, location-assisted emergency records, safe SMS testing, AI history and fallback, funeral preferences, credential-aware notes, private document upload, copyable Legacy UID, and contextual guidance. Important safety distinctions are preserved: reminder testing is separate from real alerts, secure documents are not shared by Legacy Checking, and 999 calling always requires an explicit user action.'
    Item 'H3' '6.2.2 Contributions'
    Item 'Normal' 'The main contribution is the combination of a low-effort virtual-pet habit with an explicit safety signal and privacy-aware personal planning. Oren provides an emotionally approachable reason to return each day, while the Safety Monitor keeps the meaning of missed activity visible. Per-user cache separation, verified trusted contacts, controlled legacy release, private signed document access, friendly error presentation, and honest fallback states contribute practical safeguards that are often missing from simple check-in demonstrations.'
    Item 'H2' '6.3 Limitations and Future Improvements'
    Item 'Normal' 'Android background work is best-effort and can be delayed by battery optimization, connectivity, manufacturer policy, or force-stop behavior; the web build has no equivalent periodic scheduler. SMS, phone OTP, Google OAuth, Gemini, weather, and location depend on external credentials, quotas, billing, device permissions, and provider availability. Twilio trial restrictions can also limit recipients. The local cache is device-specific, and the application is not a medical monitor: it does not detect falls, vital signs, or unconsciousness.'
    Item 'Normal' 'Future work should move inactivity evaluation to a reliable server scheduler, add push notification and SMS delivery receipts, deploy and exercise all Legacy Checking functions, add automated integration and end-to-end tests, measure battery and network use, conduct formal accessibility and elderly-user acceptance studies, add Malay and Chinese language support, provide secure account recovery, and evaluate a consent-based caregiver portal. Any legal-document feature should be developed only with professional legal review.'
    Item 'H2' '6.4 Issues and Solutions'
    Item 'H3' '6.4.1 Technical Issues'
    Item 'Normal' 'Google OAuth users initially authenticated without a matching public profile, which caused Supabase-backed pages to appear stale or empty. An auth.users trigger and backfill now create the public.users row and repositories use the authenticated UUID consistently. Schema-cache errors such as a missing documents.uploaded_at column were addressed with idempotent SQL repair files and schema audits. Contact validation conflicts were resolved with aligned columns, triggers, RLS, and an atomic primary-contact RPC.'
    Item 'Normal' 'Several UI defects were also corrected. Small profile and contact dialogs became scrollable full-page forms; asynchronous setState callbacks were separated from awaited work; a blank post-login route was isolated behind explicit loading and setup states; weather selection now prioritizes the saved Malaysian region instead of defaulting to a rain scene; Oren state uses user-specific cache keys; and emergency controls use consistent messages and confirmation paths. OTP authentication errors are now surfaced as configuration problems rather than silent failures.'
    Item 'H3' '6.4.2 Project Management Issues'
    Item 'Normal' 'The project scope expanded as safety, privacy, accessibility, and deployment details became clearer. A modular backlog and small idempotent SQL files allowed urgent defects to be repaired without rewriting unrelated modules. The report was repeatedly reconciled with the actual repository so unfinished provider deployment, external quotas, formal benchmarking, and legal limitations were not overstated. Future iterations should define integration acceptance criteria and secret-management tasks earlier in the schedule.'
    Item 'H3' '6.4.3 Team Dynamics and Collaboration Issues'
    Item 'Normal' 'This is an individual final-year project, so group-team conflict and task-allocation issues are not applicable. Collaboration instead occurred through supervisor guidance, direct user feedback, platform documentation, and iterative review of builds and report artefacts. Recording decisions and maintaining clear module boundaries helped keep those inputs traceable.'
    Item 'H3' '6.4.4 Learning and Skill Development Challenges'
    Item 'Normal' 'The project required growth across Flutter responsive layout, asynchronous state, Android lifecycle constraints, Supabase Auth and RLS, PostgreSQL triggers and RPCs, private Storage, Edge Functions, OAuth redirects, SMS credentials, secure OTP design, file-signature validation, API fallback behavior, automated testing, and academic documentation. The most important learning was that a successful local widget test is different from proof of remote policy, provider delivery, or background execution on a physical device.'
    Item 'H3' '6.4.5 Overall Lessons Learnt and Future Improvements'
    Item 'Normal' 'Safety-critical wording and behavior must be conservative, test modes must remain visibly separate, private data release must use explicit authorization and minimum necessary fields, and external dependencies require observable configuration checks. Future planning should reserve time for physical-device testing, provider dashboards, elderly-participant evaluation, deployment logs, privacy review, and regression automation. These lessons provide a realistic route from the current final-year project to a more dependable production service.'
  )
  Replace-Section-Body $document 'System Deployment' 'Chapter Summary and Evaluation' $chapter6 'Heading 1'
  $chapter6Title = Find-Paragraph $document 'System Deployment' 0 'Heading 1'
  $chapter6Title.Paragraph.Range.ListFormat.RemoveNumbers() | Out-Null
  $chapter6TitleRange = $chapter6Title.Paragraph.Range.Duplicate
  $chapter6TitleRange.End = $chapter6TitleRange.End - 1
  $chapter6TitleRange.Text = '6 Conclusion'
  Set-Paragraph $document 'System Deployment' 'Conclusion'
  $chapter6Summary = Find-Paragraph $document 'Chapter Summary and Evaluation' $chapter6Title.Index
  $chapter6SummaryRange = $chapter6Summary.Paragraph.Range.Duplicate
  $chapter6SummaryRange.End = $chapter6SummaryRange.End - 1
  $chapter6Summary.Paragraph.Range.ListFormat.RemoveNumbers() | Out-Null
  $chapter6SummaryRange.Text = '6.5 Conclusion'
  Set-Paragraph $document 'At the end of each chapter, evaluate the contents stated or discussed in the relevant sub-sections. For example,' 'EthernaCare demonstrates that a simple daily virtual-pet interaction can become a broader safety and preparedness system without disguising its limitations. The project achieved its principal software objectives and produced a modular, tested application foundation. Production use still requires completed provider deployment, physical-device verification, formal user evaluation, operational monitoring, and continued privacy and accessibility review.' $false $chapter6Title.Index
  $chapter6SummaryBody = Find-Paragraph $document 'EthernaCare demonstrates that a simple daily virtual-pet interaction' $chapter6Title.Index '' $true
  Normalize-Body-Paragraph $chapter6SummaryBody.Paragraph
  Set-Paragraph $document 'Chapter 6 (if applicable)' 'Chapter 6'
  $instructionStart = Find-Paragraph $document 'Problems faced.  Describe the various problems faced by students in the course of doing the project.' $chapter6Title.Index
  $referencesHeading = Find-Paragraph $document 'References' $instructionStart.Index 'Heading 1'
  $document.Range($instructionStart.Paragraph.Range.Start, $referencesHeading.Paragraph.Range.Start).Delete() | Out-Null

  $references = @(
    'Anderson, J. E., Ross, A. J., Macrae, C., & Wiig, S. (2020). Defining adaptive capacity in healthcare: A new framework for researching resilient performance. Applied Ergonomics, 87, 103111. https://doi.org/10.1016/j.apergo.2020.103111',
    'Android Developers. (n.d.). WorkManager API reference. Retrieved July 11, 2026, from https://developer.android.com/reference/androidx/work/WorkManager',
    'Apple Inc. (n.d.). Use Emergency SOS via satellite on your iPhone. Retrieved February 24, 2026, from https://support.apple.com/en-us/101573',
    'CarePredict. (n.d.). Senior living safety and care optimization. Retrieved February 24, 2026, from https://www.carepredict.com/',
    'Czaja, S. J., et al. (2006). Factors predicting the use of technology: Findings from the Center for Research and Education on Aging and Technology Enhancement. Psychology and Aging, 21(2), 333-352. https://doi.org/10.1037/0882-7974.21.2.333',
    'Davis, F. D. (1989). Perceived usefulness, perceived ease of use, and user acceptance of information technology. MIS Quarterly, 13(3), 319-340. https://doi.org/10.2307/249008',
    'Department of Statistics Malaysia. (2023). Current population estimates, Malaysia, 2023. https://www.dosm.gov.my',
    'Department of Statistics Malaysia. (2024). Marriage and divorce statistics, Malaysia, 2024. https://www.dosm.gov.my/portal-main/release-content/marriage-and-divorce-2024',
    'Department of Statistics Malaysia. (2025). Migration survey report, Malaysia, 2024. https://www.dosm.gov.my/portal-main/release-content/migration-survey-report-malaysia-2024',
    'Dusseljee-Peute, L. W. P., Jaspers, M. W. M., & Wildenbos, G. A. (2018). Aging barriers influencing mobile health usability for older adults: A literature-based framework (MOLD-US). International Journal of Medical Informatics, 114, 66-75.',
    'Flutter. (n.d.). Guide to app architecture. Retrieved July 11, 2026, from https://docs.flutter.dev/app-architecture/guide',
    'Google AI for Developers. (n.d.). Gemini API: Generating content. Retrieved July 11, 2026, from https://ai.google.dev/api/generate-content',
    'Government of Malaysia. (n.d.). Weather API. Malaysia''s Official Open API. Retrieved July 11, 2026, from https://developer.data.gov.my/realtime-api/weather',
    'Lee, C.-W., & Chuang, H.-M. (2021). Design of a seniors and Alzheimer''s disease caring service platform. BMC Medical Informatics and Decision Making, 21(Suppl 10), 273. https://doi.org/10.1186/s12911-021-01626-3',
    'Melchiorre, M. G., D''Amen, B., Quattrini, S., Lamura, G., Socci, M., & Tchounwou, P. B. (2022). Health emergencies, falls, and use of communication technologies by older people with functional and social frailty. International Journal of Environmental Research and Public Health, 19(22), 15150. https://pmc.ncbi.nlm.nih.gov/articles/PMC9691100/',
    'Open-Meteo. (n.d.). Weather Forecast API. Retrieved July 11, 2026, from https://open-meteo.com/en/docs',
    'Patel, S., Park, H., Bonato, P., Chan, L., & Rodgers, M. (2012). A review of wearable sensors and systems with application in rehabilitation. Journal of NeuroEngineering and Rehabilitation, 9, 21. https://doi.org/10.1186/1743-0003-9-21',
    'Rashidi, P., & Mihailidis, A. (2013). A survey on ambient-assisted living tools for older adults. IEEE Journal of Biomedical and Health Informatics, 17(3), 579-590. https://doi.org/10.1109/JBHI.2012.2234129',
    'Supabase. (n.d.-a). Auth. Retrieved July 11, 2026, from https://supabase.com/docs/guides/auth',
    'Supabase. (n.d.-b). Edge Functions. Retrieved July 11, 2026, from https://supabase.com/docs/guides/functions',
    'Supabase. (n.d.-c). Row Level Security. Retrieved July 11, 2026, from https://supabase.com/docs/guides/database/postgres/row-level-security',
    'Twilio. (n.d.). Messages resource. Retrieved July 11, 2026, from https://www.twilio.com/docs/messaging/api/message-resource',
    'Venkatesh, V., Morris, M. G., Davis, G. B., & Davis, F. D. (2003). User acceptance of information technology: Toward a unified view. MIS Quarterly, 27(3), 425-478. https://doi.org/10.2307/30036540',
    'Vlaev, I., King, D., Darzi, A., & Dolan, P. (2019). Changing health behaviors using financial incentives: A review from behavioral economics. BMC Public Health, 19, 1059. https://pmc.ncbi.nlm.nih.gov/articles/PMC6686221/',
    'Wang, R., et al. (2014). StudentLife: Assessing mental health, academic performance and behavioral trends of college students using smartphones. Proceedings of UbiComp 2014, 3-14. https://doi.org/10.1145/2632048.2632054',
    'Wang, Z., Wang, Y., Zeng, Y., Su, J., & Li, Z. (2025). An investigation into the acceptance of intelligent care systems: An extended technology acceptance model. Scientific Reports, 15, 17912. https://doi.org/10.1038/s41598-025-02746-w',
    'World Health Organization. (2015). World report on ageing and health. https://www.who.int/publications/i/item/9789241565042',
    'United Nations, Department of Economic and Social Affairs, Population Division. (2022). World population prospects 2022: Summary of results. https://www.un.org/development/desa/pd/'
  ) | Sort-Object
  $referenceItems = $references | ForEach-Object { Item 'Normal' $_ }
  Replace-Section-Body $document 'References' 'Appendices' $referenceItems '' (Find-Paragraph $document 'References' 0 'Heading 1').Index
  $referencesTitle = Find-Paragraph $document 'References' 0 'Heading 1'
  $referencesTitle.Paragraph.Range.ListFormat.RemoveNumbers() | Out-Null

  Set-Paragraph $document 'APPENDIX n User Guide' 'APPENDIX A User Guide'
  Set-Paragraph $document 'APPENDIX n+1 Developer Guide*' 'APPENDIX B Developer Guide'
  Replace-Section-Body $document 'Appendices' 'APPENDIX A User Guide' @() ''
  $userGuide = @(
    Item 'H2' 'Account and First Login'
    Item 'Normal' 'Register with a valid email and strong password or use a configured OAuth provider. Complete required profile details, accept the Terms and Conditions, verify the user phone, and add and verify a primary trusted contact.'
    Item 'H2' 'Daily Use'
    Item 'Normal' 'Open Home and tap Oren once each day to check in. Review History for timestamps, Rewards for streak milestones, and the dashboard for weather, next reward, and inactivity state. Use Feed and owned toys for Oren interactions.'
    Item 'H2' 'Safety Functions'
    Item 'Normal' 'Maintain an accurate primary contact and inactivity threshold. The real counter reaches three reminders before configured escalation. Use the Safe reminder test only with the contact''s consent. For immediate danger, explicitly open the 999 dialer and place the call.'
    Item 'H2' 'Profile, AI, and Legacy Planning'
    Item 'Normal' 'Edit state, region, blood type, threshold, and escalation target from Profile. Use the copy button beside Legacy UID only when preparing an authorized Legacy Checking request. AI Guidance provides general information only. Legacy Planning stores preferences, safe notes, and completed private documents; it does not create legal documents. Legacy Checking must be enabled by the owner, is limited to the verified primary contact after 90 days without a check-in, and never releases secure documents.'
    Item 'H2' 'Contextual Guidance'
    Item 'Normal' 'Use the information buttons in Profile, Legacy Planning, and Legacy Check to open the scrollable guidance sheet. It explains Oren check-in, tokens, shop items, inactivity status, contacts, SOS, Legacy UID privacy, and the conditions for legacy access.'
  )
  Replace-Section-Body $document 'APPENDIX A User Guide' 'APPENDIX B Developer Guide' $userGuide ''

  $developerGuide = @(
    Item 'H2' 'Development Requirements'
    Item 'Normal' 'Install Flutter/Dart, Android Studio or Android SDK tools, Git, and Node.js for npx-based Supabase CLI commands. Restore packages with flutter pub get and verify with flutter test.'
    Item 'H2' 'Supabase Setup'
    Item 'Normal' 'Create the Supabase project, configure the app URL and anon key, run the SQL migration and RLS files, create the private legacy-documents bucket, configure OAuth redirect URLs, deploy Edge Functions, and set Gemini, Twilio, OTP, and worker secrets. Apply the Legacy Checking consent, audit, release, and OTP schema before deploying its dedicated functions. Never commit service-role or provider secrets.'
    Item 'H2' 'Build and Verification'
    Item 'Normal' 'Run schema_audit.sql, execute the Flutter tests, build an Android APK or release bundle, install on a physical device, grant permissions, and test email/OAuth, OTP, contacts, check-in, rewards, weather, AI, legacy documents, location, notifications, and the safe three-reminder SMS cycle.'
    Item 'H2' 'Maintenance'
    Item 'Normal' 'Monitor Supabase Auth, database, Storage, Edge Function logs, SMS outbox failures, API quotas, and crash reports. Apply idempotent migrations before releasing code that expects new columns. Rotate leaked credentials immediately and keep provider billing and sender verification current.'
  )
  Replace-Section-Body $document 'APPENDIX B Developer Guide' 'This page is intentionally left blank to indicate the back cover. Ensure that the back cover is black in color.' $developerGuide ''
  Set-Paragraph $document 'This page is intentionally left blank to indicate the back cover. Ensure that the back cover is black in color.' ''

  foreach ($toc in $document.TablesOfContents) { $toc.Update() }
  $document.Fields.Update() | Out-Null
  $document.Repaginate()
  $document.Save()
  $document.ExportAsFixedFormat($PdfOutput, 17)
  $document.Close($false)
  $document = $null
}
finally {
  if ($null -ne $document) { $document.Close($false) }
  $word.Quit()
  [System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($word) | Out-Null
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
  foreach ($temporaryDirectory in @($assetDirectory, $figureAssetDirectory)) {
    if (-not (Test-Path -LiteralPath $temporaryDirectory)) { continue }
    $resolvedTemporary = [IO.Path]::GetFullPath($temporaryDirectory)
    $resolvedOutput = [IO.Path]::GetFullPath($outputDirectory)
    if (-not $resolvedTemporary.StartsWith($resolvedOutput, [StringComparison]::OrdinalIgnoreCase)) {
      throw "Unsafe temporary cleanup path: $resolvedTemporary"
    }
    [IO.Directory]::Delete($resolvedTemporary, $true)
  }
}

Get-Item -LiteralPath $Output, $PdfOutput | Select-Object FullName, Length, LastWriteTime
