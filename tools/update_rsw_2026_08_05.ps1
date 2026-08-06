param(
  [string]$Source = 'C:\Users\user\StudioProjects\fyp\output\docs\EthernaCare_RSW_Updated_2026-08-03.docx',
  [string]$Output = 'C:\Users\user\StudioProjects\fyp\output\docs\EthernaCare_RSW_Updated_2026-08-05.docx'
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
  [bool]$contains = $false,
  [string]$styleLike = ''
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
  [int]$after = 0
) {
  $match = Find-Paragraph $document $find $after $contains
  $range = $match.Paragraph.Range.Duplicate
  $range.End = $range.End - 1
  $range.Text = $replacement
}

function Set-Table-Cell($document, [int]$table, [int]$row, [int]$column, [string]$text) {
  $cell = $document.Tables.Item($table).Cell($row, $column)
  $range = $cell.Range.Duplicate
  $range.End = $range.End - 1
  $range.Text = $text
}

function Add-Table-Row($document, [int]$tableNumber, [string[]]$values) {
  $table = $document.Tables.Item($tableNumber)
  if ($values.Count -ne $table.Columns.Count) {
    throw "Table $tableNumber requires $($table.Columns.Count) values; received $($values.Count)."
  }
  $row = $table.Rows.Add()
  for ($column = 1; $column -le $values.Count; $column++) {
    Set-Table-Cell $document $tableNumber $row.Index $column $values[$column - 1]
  }
}

function Get-Reference-Texts($document) {
  $start = Find-Paragraph $document 'References' 0 $false 'Heading 1'
  $end = Find-Paragraph $document 'Appendices' $start.Index $false
  $values = New-Object System.Collections.Generic.List[string]
  for ($index = $start.Index + 1; $index -lt $end.Index; $index++) {
    $text = Paragraph-Text $document.Paragraphs.Item($index)
    if ($text) { $values.Add($text) }
  }
  return $values.ToArray()
}

function Insert-References-Before-Appendices($document, [string[]]$references) {
  $appendices = Find-Paragraph $document 'Appendices'
  $range = $document.Range($appendices.Paragraph.Range.Start, $appendices.Paragraph.Range.Start)
  $range.Text = ($references -join "`r") + "`r"
}

if (-not (Test-Path -LiteralPath $Source)) {
  throw "Source document not found: $Source"
}

$outputDirectory = Split-Path -Parent $Output
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
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

  $originalReferences = @(Get-Reference-Texts $document)
  $originalFieldCount = $document.Fields.Count
  $originalFootnoteCount = $document.Footnotes.Count
  $originalEndnoteCount = $document.Endnotes.Count

  Set-Paragraph $document 'The system was developed using Flutter and Supabase' @'
The system was developed using Flutter and Supabase with Row Level Security, private Storage, Realtime, Edge Functions and scheduled server processing. Biometric session locking protects a locally restored signed-in session on supported devices. A skippable eight-step first-run guide and a replayable Settings area improve onboarding and accessibility. External SMS, email, weather and AI providers are accessed through controlled service boundaries, and 138 automated tests currently pass with 30.64 percent line coverage.
'@.Trim() $true

  Set-Paragraph $document 'Users register with email and password or a configured Google OAuth provider.' @'
Users register with email and password or a configured Google OAuth provider. Email sign-up and password recovery use Supabase confirmation flows. New users accept the Terms and Conditions, complete mandatory profile fields, verify the user phone by a six-digit SMS OTP and add a verified primary contact. After setup, a skippable eight-step guide introduces the main modules; it appears once per account and can be replayed from Profile or Settings. OAuth profile bootstrap ensures that the public user row uses the same authenticated UUID.
'@.Trim() $true

  Set-Paragraph $document 'Oren provides the explicit heartbeat action.' @'
Oren provides the explicit heartbeat action. A successful check-in is allowed when the configured rolling threshold has elapsed, resets the current inactivity cycle and updates history and rewards. Oren energy decays by one point for every complete hour, feeding restores energy, playing consumes energy, and owned toys and token state persist per user on the same device. Care and shop mutations are serialized so rapid or simultaneous taps cannot overwrite energy, token, ownership or selected-item changes.
'@.Trim() $true

  Set-Paragraph $document 'The inactivity threshold can be set from one to 168 hours.' @'
The inactivity threshold can be set from one to 168 hours. At one missed window the status becomes overdue and a local reminder is created. At two missed windows the cloud worker attempts an SMS to the verified user phone. At three missed windows it creates one inactivity alert and attempts one SMS to the verified primary contact. The server worker runs every 15 minutes and uses persisted state and idempotency to prevent duplicate escalation. SMS provider requests have a 12-second timeout, interrupted processing can be recovered after five minutes, and the emergency SMS endpoint accepts only verified recipients and approved EthernaCare message categories. Manual SOS can record location and send a contact alert; calling 999 always requires explicit user action.
'@.Trim() $true

  Set-Paragraph $document 'The interface shall provide readable text' @'
The interface shall provide readable text, clear status/action differentiation, scrollable forms, guidance controls, safe error messages and responsive layouts. Device settings include text-size choices and reduced-motion support, while important controls expose useful semantic labels. Threshold, escalation, contact verification and Legacy release states shall be explained in plain language. These choices follow Flutter guidance that release checks should cover screen readers, tappable targets, contrast and usability at large text/display scale factors (Flutter, 2026).
'@.Trim() $true

  Set-Paragraph $document 'The Profile page displays and edits the user' @'
The Profile page displays and edits the user's contact, address, blood type, rolling inactivity threshold and escalation preference. It shows phone verification state, provides a copyable Legacy UID, allows biometric session protection on supported devices, and links to the Terms and Conditions and Legacy Planning. The page also reopens the feature guide and provides Settings for local reminders, Oren sounds, text size, reduced motion, biometric controls and restore-defaults. Age and a public profile photograph are not required by the current data model.
'@.Trim() $true

  Set-Paragraph $document 'The application separates local continuity from cloud authority.' @'
The application separates local continuity from cloud authority. SharedPreferences stores user-scoped Oren care, weather, dashboard, reward, chat, reminder and first-run-guide state for responsive reopening on the same device; device preferences store reminder, sound, text-size and reduced-motion choices. Supabase remains the authority for authentication, profiles, contacts, check-ins, emergency alerts, reward catalogues, earned rewards, Legacy Planning records, private document metadata, OTPs, delivery outboxes and seven-day Legacy access windows.
'@.Trim() $true

  Set-Paragraph $document 'Reliability testing checks duplicate suppression' @'
Reliability testing checks duplicate suppression, one-time escalation, retry visibility, stale-processing recovery, provider timeouts, cache restoration, app-resume refresh, overlapping dashboard requests, serialized Oren actions and fallback behavior. Security testing checks RLS ownership, recent phone verification, private Storage paths, signed URLs, OTP expiry and attempts, Legacy audit events, admin authorization, verified SMS recipients, approved message categories and server-secret boundaries. Usability checks cover scrolling, safe areas, readable status text, semantic labels, guidance, Settings, large text, reduced motion, full-page forms and mobile viewport behavior. Maintainability is supported by repositories, services, typed models, idempotent migrations and separate Edge Functions.
'@.Trim() $true

  Set-Paragraph $document 'The current automated suite contains 135 passing tests.' @'
The current automated suite contains 138 passing tests. Line coverage is 2,515 of 8,208 lines, or 30.64 percent. The suite covers important domain and widget behaviour, including biometric prompt coordination, rolling inactivity logic, first-run guide persistence, device settings and concurrent Oren care actions. Line coverage remains modest for the full presentation and provider-integration surface, so it is reported as a limitation rather than complete assurance. Real carrier delivery, Android Doze/background execution, biometric hardware and GPS accuracy still require physical-device acceptance testing.
'@.Trim() $true

  Set-Paragraph $document 'This chapter documented the current EthernaCare implementation.' @'
This chapter documented the current EthernaCare implementation. The application combines a layered Flutter client with Supabase Auth, PostgreSQL, Row Level Security, private Storage, Realtime and Edge Functions. A 15-minute cloud worker applies the rolling inactivity stages, while a daily cloud worker manages the 90-day Legacy sequence. The key rules are explicit: check-in eligibility follows the selected threshold; server-side SMS attempts occur at missed windows two and three; Oren energy decays hourly and care mutations are serialized; badges and vouchers have distinct redemption behaviour; biometric prompts are asynchronously coordinated; dashboard loads ignore stale overlapping responses; and protected Legacy content follows a 90-day, 24-hour owner-protection and seven-day contact-access sequence. The first-run guide and Settings module provide persistent onboarding and accessibility choices.
'@.Trim() $true

  Set-Paragraph $document 'The 135-test suite and 30.89 percent line coverage' @'
The 138-test suite and 30.64 percent line coverage provide useful regression evidence for deterministic logic and key interfaces. The deployed workers and versioned migrations provide an auditable backend implementation. However, automated tests and desktop builds cannot prove SMS receipt, external email delivery, Android operating-system scheduling, physical biometric sensors or GPS accuracy. EthernaCare is suitable for a final-year project and controlled demonstration, while production use requires the physical acceptance tests, provider monitoring and operational controls identified in this chapter.
'@.Trim() $true

  Set-Paragraph $document 'The Flutter project can produce Android APK/app-bundle' @'
The Flutter project can produce Android APK/app-bundle, Windows and web builds from the same Dart source. The public Supabase URL and anonymous key can be supplied at build time through SUPABASE_URL and SUPABASE_ANON_KEY definitions. Secret provider credentials are never compiled into the client. Release builds hide safety-test controls unless ENABLE_SAFETY_TESTS is explicitly enabled. Android deployment also requires notification, location and biometric permissions and the registered WorkManager entry point.
'@.Trim() $true

  Set-Paragraph $document 'Edge Functions implement phone OTP, emergency SMS' @'
Edge Functions implement phone OTP, emergency SMS, AI guidance, threshold processing, Legacy access, cancellation and Legacy inactivity processing. Supabase encrypted function secrets store the Twilio, transactional-email, AI and OTP-signing credentials. SMS calls use bounded provider timeouts and persisted retry state; interrupted processing can be reclaimed after a short stale-job window, and the emergency endpoint verifies both recipient eligibility and approved message categories. Twilio handles SMS delivery and Brevo/SMTP handles email; each provider must be configured, funded or verified according to its own account rules before real delivery can be accepted.
'@.Trim() $true

  Set-Paragraph $document 'Major risks include provider outage' @'
Major risks include provider outage, invalid SMS/email credentials, carrier filtering, delayed Android background work, revoked location permission, migration mismatch, stale processing jobs and duplicate alerts. The implementation reduces these risks with server scheduling, persisted outboxes, idempotency keys, bounded provider timeouts, failed-state retries, five-minute stale-job recovery, verified-recipient and message-category checks, friendly status messages, local fallbacks and audit logs. It cannot guarantee that an external message is delivered or read.
'@.Trim() $true

  Set-Paragraph $document 'Training begins with account creation and consent' @'
Training begins with account creation and consent, followed by the skippable eight-step feature guide. It then demonstrates Oren check-in versus Feed/Play, the rolling threshold, reminder stages, contact verification, manual SOS, virtual rewards, profile controls and AI limitations. Users are shown how to replay the guide and use Settings for reminders, sounds, text size, reduced motion, biometrics and default restoration. A separate Legacy exercise covers the Legacy UID, funeral preferences, owner protection, the public contact flow and the fact that Notes/documents remain time-restricted. Administrators receive separate training for reward catalogue maintenance and provider/log monitoring.
'@.Trim() $true

  Set-Paragraph $document 'The project achieved its principal functional objectives.' @'
The project achieved its principal functional objectives. Check-ins now follow a one-to-168-hour rolling threshold instead of a fixed daily flag. A cloud worker evaluates every 15 minutes and persists the first, second and third missed-window stages. Contact phone verification, duplicate suppression, bounded SMS requests, stale-job recovery and server delivery state support safer escalation. Oren has hourly energy decay, user-scoped care state and serialized mutations that prevent lost rapid-tap updates. Dashboard refreshes reject stale overlapping responses and refresh on app resume. Rewards are fully virtual, with badge collection, voucher codes and a separate catalogue-admin route. Legacy Planning implements owner consent, funeral preferences, secret-aware notes, private documents, a 90-day trigger, a 24-hour owner-protection step and seven-day protected access. Supported sessions can be locked by asynchronously coordinated device biometrics, while the first-run guide and Settings module improve onboarding and accessibility.
'@.Trim() $true

  Set-Paragraph $document 'Quality evidence includes 135 passing automated tests' @'
Quality evidence includes 138 passing automated tests and 30.64 percent line coverage. The tests exercise important service, repository and widget paths, including threshold calculations, Oren decay and concurrency, OTP rules, Legacy timing, virtual rewards, guide/settings persistence and biometric prompt behaviour. This gives repeatable regression evidence, although it does not replace physical and provider acceptance testing.
'@.Trim() $true

  Set-Paragraph $document 'Future work should raise automated coverage' @'
Future work should raise automated coverage, add provider sandbox and delivery-status integration tests, complete a structured physical-device matrix, add accessibility testing with older adults, introduce operational dashboards and alerting, support secure cross-device synchronization for Oren state, and perform professional privacy, legal and security reviews. Before production release, sensitive offline profile or medical caches should be removed when unnecessary or moved from unencrypted preferences to protected platform storage (OWASP Foundation, n.d.). The Android application identifier should also be changed from the development identifier, and direct SEND_SMS permission should be retained only after confirming Google Play eligibility and declaration requirements; otherwise, server-side SMS should remain the primary path (Google Play, n.d.). A production release should also define data retention, incident response, account recovery and support procedures.
'@.Trim() $true

  Set-Paragraph $document 'A major issue was that phone-only background execution' @'
A major issue was that phone-only background execution could not guarantee threshold processing after the app was closed. This was addressed by moving authoritative evaluation to a 15-minute Supabase Cron worker while retaining WorkManager for local reminders. Duplicate SMS risk was reduced through persisted stages, idempotency keys and delivery outboxes; provider hangs and interrupted work were addressed with a 12-second timeout, retry states and five-minute stale-job recovery. Rapid Oren actions that could overwrite local state were serialized, and dashboard requests now discard stale overlapping results and refresh on app resume. OAuth users missing public profile rows were addressed with profile bootstrap logic. Private Legacy files were protected with RLS, private Storage and short-lived signed URLs. Repeated biometric prompts were addressed through asynchronous request coalescing and lifecycle-aware gating.
'@.Trim() $true

  Set-Paragraph $document 'Install or launch EthernaCare, create an account or continue with Google' @'
Install or launch EthernaCare, create an account or continue with Google, complete email confirmation where required, accept the Terms and Conditions, complete the profile, verify the user phone and add a verified primary trusted contact. The first completed setup opens an eight-step guide covering Home, History, Contacts, Rewards, AI Guidance, Legacy Planning, Profile and safety boundaries. The guide can be skipped and replayed later from Profile or Settings. No shared demonstration password is embedded in the application.
'@.Trim() $true

  Set-Paragraph $document 'Open Home and review Oren' @'
Open Home and review Oren's status and the Safety Monitor. Tap Oren when the rolling threshold allows a check-in. Feed and Play change Oren care state but do not count as a safety heartbeat. Use History to inspect successful timestamps, Contacts to manage the verified safety network, Rewards to collect virtual items and Profile to change threshold, escalation and biometric settings. Open Profile > Settings to control local reminders, Oren sounds, text size and reduced motion, replay the feature guide or restore defaults.
'@.Trim() $true

  Set-Paragraph $document 'Apply SQL migrations in supabase/migrations' @'
Apply SQL migrations in supabase/migrations in filename order. Deploy all functions in supabase/functions, configure encrypted Twilio, email, AI and OTP secrets, verify authentication redirect URLs and providers, confirm private Storage policies, and inspect the 15-minute threshold and midnight Legacy Cron jobs. Confirm that production builds omit ENABLE_SAFETY_TESTS, set the final Android application identifier and include only approved platform permissions. Do not commit secret values or include them in screenshots.
'@.Trim() $true

  Set-Paragraph $document 'Run flutter analyze, flutter test --coverage' @'
Run flutter analyze, flutter test --coverage and the required release builds. The latest recorded automated run contains 138 passing tests with 2,515 of 8,208 executable lines covered (30.64 percent). Confirm database migration parity and Edge Function health. Complete physical Android checks for notification permission, background/resume behaviour, biometric success/cancel/retry, GPS capture and real SMS/email receipt. Record provider message IDs and errors without exposing tokens.
'@.Trim() $true

  Set-Table-Cell $document 2 6 3 'Editable threshold, escalation target, phone verification state, copyable Legacy UID, biometrics, feature-guide replay, Settings, and Terms link'

  Add-Table-Row $document 3 @(
    'AUTH-06',
    'A first-time user has completed the required profile and primary-contact setup.',
    'Step through or skip the guide, reopen it from Profile/Settings, then change reminder, sound, text-size, or reduced-motion settings.',
    'The guide is offered once per account, remains replayable, and device settings persist and apply after navigation or restart.',
    'Guide/settings widget and persistence tests PASS.'
  )

  Add-Table-Row $document 6 @(
    'OREN-04',
    'Two Oren care or shop actions are initiated almost simultaneously.',
    'Start overlapping Feed/Play or purchase/select operations.',
    'Actions execute serially and both valid energy, token, ownership, and selection changes remain without a lost update.',
    'Automated concurrency regression tests PASS.'
  )

  Add-Table-Row $document 8 @(
    'NFR-04',
    'An SMS provider stalls or a worker stops while a delivery is marked as processing.',
    'Allow the provider call to exceed its limit or rerun the worker after the stale interval.',
    'The request fails within 12 seconds, records a retryable state, can be reclaimed after five minutes, and rejects unverified recipients or unapproved messages.',
    'Function logic/deployment PASS; live provider failure injection remains an acceptance test.'
  )

  $newReferences = @(
    'Flutter. (2026). Accessibility. Retrieved August 5, 2026, from https://docs.flutter.dev/ui/accessibility',
    'OWASP Foundation. (n.d.). MASWE-0006: Sensitive data stored unencrypted in private storage locations. Retrieved August 5, 2026, from https://mas.owasp.org/MASWE-0006/',
    'Google Play. (n.d.). Use of SMS or Call Log permission groups. Retrieved August 5, 2026, from https://support.google.com/googleplay/android-developer/answer/10208820?hl=en'
  )
  Insert-References-Before-Appendices $document $newReferences
  foreach ($reference in $newReferences) {
    $paragraph = (Find-Paragraph $document $reference).Paragraph
    $paragraph.Range.Style = -1
    $paragraph.Range.Font.Reset() | Out-Null
    $paragraph.Range.ParagraphFormat.Reset() | Out-Null
  }

  $updatedReferences = @(Get-Reference-Texts $document)
  foreach ($reference in $originalReferences) {
    if ($updatedReferences -notcontains $reference) {
      throw "An existing reference was not preserved: $reference"
    }
  }
  foreach ($reference in $newReferences) {
    if ($updatedReferences -notcontains $reference) {
      throw "A new reference was not inserted: $reference"
    }
  }
  if ($document.Fields.Count -ne $originalFieldCount) {
    throw "Field count changed from $originalFieldCount to $($document.Fields.Count)."
  }
  if ($document.Footnotes.Count -ne $originalFootnoteCount) {
    throw "Footnote count changed from $originalFootnoteCount to $($document.Footnotes.Count)."
  }
  if ($document.Endnotes.Count -ne $originalEndnoteCount) {
    throw "Endnote count changed from $originalEndnoteCount to $($document.Endnotes.Count)."
  }

  foreach ($toc in @($document.TablesOfContents)) {
    $toc.Update() | Out-Null
  }
  $document.Repaginate()
  $document.Save()

  "OUTPUT=$Output"
  "PAGES=$($document.ComputeStatistics(2))"
  "REFERENCES_BEFORE=$($originalReferences.Count)"
  "REFERENCES_AFTER=$($updatedReferences.Count)"
  "FIELDS=$($document.Fields.Count)"
  "FOOTNOTES=$($document.Footnotes.Count)"
  "ENDNOTES=$($document.Endnotes.Count)"
}
finally {
  if ($null -ne $document) { $document.Close($false) }
  $word.Quit()
  [System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($word) | Out-Null
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
}
