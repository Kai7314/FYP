param(
  [string]$Source = 'C:\Users\user\Downloads\RSW_OoKaiHeng(Reference lists added).docx',
  [string]$Output = 'C:\Users\user\StudioProjects\fyp\output\docs\EthernaCare_RSW_Aligned_2026.docx',
  [string]$PdfOutput = 'C:\Users\user\StudioProjects\fyp\output\docs\EthernaCare_RSW_Aligned_2026.pdf'
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

if (-not (Test-Path -LiteralPath $Source)) { throw "Source document not found: $Source" }
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
    Item 'Normal' 'Users can create, edit, read, and delete legacy notes; save funeral preferences; and upload or remove private PDF or image documents up to 10 MB. EthernaCare stores completed documents but does not draft, validate, or notarize legal wills.'
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
The current home page uses a responsive premium dashboard. Oren is the direct check-in target and changes pixel-art mood, energy, interaction, and weather background. The page also shows Malaysian region weather, streak and check-in totals, the next reward, real inactivity reminder progress, a separate three-step test button, emergency state, Oren status, shop controls, SOS, SMS testing, and sign-out. Scroll cues and safe-area spacing support small Android screens.
'@.Trim() $true
  Set-Paragraph $document 'Gemini said The Emergency Contacts page' @'
The Emergency Contacts page lists up to five owned contacts with name, relationship, verified international phone number, address, state, and region. A star action changes the primary contact through an atomic database function, while edit and delete operations refresh the interface immediately. Adding or changing a phone number requires SMS OTP verification.
'@.Trim() $true
  Set-Paragraph $document 'The Rewards page serves as the primary incentive hub' @'
The Rewards page combines server-backed streak rewards and locally cached reward catalogue data with Oren tokens and toys. The dashboard shows the next milestone reward, while the Oren shop allows owned toys to be purchased and used. Reward examples include virtual sponsor vouchers rather than guaranteed physical inventory.
'@.Trim() $true
  Set-Paragraph $document 'The My Profile page serves as a centralized hub' @'
The Profile page displays name, verified phone, home address, Malaysian state and region, blood type, inactivity threshold, and escalation target. Age has been removed. Editing uses a full-page responsive form, country calling-code selection, validation, blood-type selection, and OTP verification when the phone number changes. The page also links to AI Guidance and Legacy Planning.
'@.Trim() $true

  $chapter5 = @(
    Item 'H2' 'Implementation Overview'
    Item 'Normal' 'The application was implemented as a Flutter project using a layered structure: presentation screens and widgets, controllers, domain services, repositories, typed models, background components, and utility validation. Supabase provides the remote backend, while SharedPreferences provides lightweight device-local JSON caching. The repository contains SQL migrations and audits so the deployed schema can be checked against the application model.'
    Item 'H2' 'Authentication and Data Protection'
    Item 'Normal' 'Email registration, sign-in, resend verification, manual signup-code verification, and OAuth are encapsulated in AuthRepository. AuthGate checks session, profile completion, accepted terms, primary contact, and tutorial state. Supabase RLS protects each user-owned table, while private storage policies protect legal documents. Phone OTP request and verification logic is isolated in two Edge Functions.'
    Item 'Code' 'create policy "contacts_select_own" on public.contacts for select'
    Item 'Code' 'to authenticated using ((select auth.uid()) = user_id);'
    Item 'H2' 'Check-In, Rewards, and Local Caching'
    Item 'Normal' 'CheckinRepository prevents more than one record per local calendar day. CheckinService refreshes cached history and RewardService calculates unique consecutive dates. OrenCareService persists tokens, owned toys, energy, mood, and daily bonus dates locally. Dashboard, reward, weather, chat, and inactivity snapshots are read from cache first and refreshed from the server when needed.'
    Item 'H2' 'Inactivity Monitoring and Emergency SMS'
    Item 'Normal' 'A 15-minute Android WorkManager task initializes Supabase in a background isolate and calls InactivityService. The service derives the number of missed windows from elapsed time, stores reminder state locally, suppresses duplicate alerts for the same check-in, and escalates at three reminders. EmergencyService records the alert, obtains location when permitted, attempts direct Android SMS, creates an outbox row when needed, and invokes the Twilio worker. The outbox records attempts, provider IDs, errors, and completion state (Android Developers, n.d.; Twilio, n.d.).'
    Item 'Code' 'missedCheckIns = elapsedSeconds ~/ thresholdSeconds;'
    Item 'Code' 'if (missedCheckIns >= 3) triggerEmergencyDetailed(sendAutomatedSms: true);'
    Item 'H2' 'Weather, AI, and Legacy Planning'
    Item 'Normal' 'WeatherService queries the selected Malaysian region through data.gov.my and falls back to Open-Meteo coordinates. Forecast text maps to clear, cloudy, rain, or thunderstorm Oren scenes. AiService invokes a server-side Gemini Edge Function with limited conversation history and a safety-constrained prompt, then falls back to built-in guidance if unavailable. LegacyPlanningRepository provides CRUD for preferences, notes, document metadata, and private storage.'
    Item 'H2' 'Testing Approach'
    Item 'Normal' 'Automated Flutter logic and widget tests cover models, validation, responsive forms, Oren interactions, weather mapping, rewards, AI history, and inactivity boundaries. The current suite contains 26 passing tests. Provider-dependent OAuth, SMS, OTP, AI, weather, location, and background execution additionally require device and deployed-environment integration tests.'
    Item 'Normal' 'TEST CASE MATRIX PLACEHOLDER'
    Item 'H2' 'Implementation Evaluation'
    Item 'Normal' 'The implementation satisfies the principal requirements while keeping high-risk actions explicit. Raw provider errors are converted into user-facing dialogs, local caching reduces repeated requests, test alerts are separated from real alerts, and 999 cannot be contacted automatically. Remaining operational reliability depends on correct Supabase migrations, Edge Function deployment, provider secrets, Android permissions, network availability, and operating-system scheduling.'
  )
  Replace-Section-Body $document 'Implementation and Testing' 'Chapter Summary and Evaluation' $chapter5 'Heading 1'
  Set-Paragraph $document 'At the end of each chapter, evaluate the contents stated or discussed in the relevant sub-sections.' 'This chapter described the implemented Flutter layers, Supabase security, cached data strategy, background inactivity monitoring, emergency delivery, weather, AI, legacy planning, and automated tests. The completed modules demonstrate that the design has been translated into working, testable components while external-provider dependencies remain clearly identified.'

  $document.Save()
  $document.Close($false)
  $document = $word.Documents.Open($Output)

  $tokenRange = $document.Content.Duplicate
  $tokenRange.Find.ClearFormatting()
  $markerFound = $tokenRange.Find.Execute('TEST CASE MATRIX PLACEHOLDER')
  if (-not $markerFound) { throw 'Test table insertion point was not found.' }
  $tokenRange.Text = ''
  $tokenRange.Collapse(1)
  $tests = @(
    @('TC01','Email/OAuth authentication UI and validation','Valid input creates or restores a session and profile route','Pass'),
    @('TC02','First-login profile, terms, and phone verification','Incomplete setup is blocked; verified setup continues','Pass'),
    @('TC03','Tap Oren daily check-in','One daily record, refreshed history, token and streak update','Pass'),
    @('TC04','Contact CRUD and primary selection','Validated contact updates immediately; one primary contact','Pass'),
    @('TC05','Reward and local cache serialization','Streak, catalogue, tokens, toys, and snapshots restore','Pass'),
    @('TC06','Malaysia weather mapping','Clear, rain, thunderstorm, and night scenes map correctly','Pass'),
    @('TC07','Legacy planning models and CRUD UI','Preferences, notes, and documents serialize correctly','Pass'),
    @('TC08','AI history and offline guidance','Recent history restores and safe fallback answers are available','Pass'),
    @('TC09','Three-stage inactivity policy','24/48/72-hour boundaries calculate 1/2/3 misses','Pass'),
    @('TC10','Reminder test cycle','Third safe test trigger starts labelled test SMS flow','Pass'),
    @('TC11','External provider delivery','OAuth, OTP, Twilio, Gemini, weather, and location','Integration setup required')
  )
  $table = $document.Tables.Add($tokenRange, $tests.Count + 1, 4)
  $headers = @('ID','Test case','Expected result','Status')
  for ($c=1; $c -le 4; $c++) { $table.Cell(1,$c).Range.Text = $headers[$c-1] }
  for ($r=0; $r -lt $tests.Count; $r++) {
    for ($c=0; $c -lt 4; $c++) { $table.Cell($r+2,$c+1).Range.Text = $tests[$r][$c] }
  }
  $table.Style = 'Table Grid'
  $table.Rows.Item(1).Range.Bold = 1
  $table.Rows.Item(1).HeadingFormat = -1
  $table.Range.Font.Name = 'Times New Roman'
  $table.Range.Font.Size = 9
  $table.AllowAutoFit = $false
  $table.Columns.Item(1).PreferredWidth = 42
  $table.Columns.Item(2).PreferredWidth = 135
  $table.Columns.Item(3).PreferredWidth = 210
  $table.Columns.Item(4).PreferredWidth = 78

  $chapter6 = @(
    Item 'H2' 'Deployment Scope and Requirements'
    Item 'Normal' 'EthernaCare is deployed as a Flutter Android application with optional web testing. Development requires Flutter/Dart, Android Studio or the Android SDK, and a Supabase project. Android devices require internet, notification and location permissions; direct-device SMS additionally requires SEND_SMS permission. Production SMS should use the server-side Twilio worker.'
    Item 'H2' 'Backend and API Setup'
    Item 'Normal' 'The deployment process runs the schema repair or migration scripts, validation constraints, primary-contact RPC, RLS policies, legacy-planning/storage setup, SMS outbox setup, OAuth profile bootstrap, and phone OTP verification SQL. Edge Functions for AI guidance, emergency SMS, OTP request, and OTP verification are deployed with the Supabase CLI. Gemini, Twilio, OTP, and worker credentials are stored as project secrets rather than committed to source control.'
    Item 'H2' 'Android Build and Installation'
    Item 'Normal' 'Dependencies are restored with flutter pub get. Automated tests are run before flutter build apk or an Android Studio release build. OAuth redirect URIs and Android signing fingerprints must match provider configuration. The APK or Play release is installed, permissions are granted, and email/OAuth, check-in, contact, weather, AI, location, OTP, and SMS flows are tested on a physical device.'
    Item 'H2' 'Backup and Risk Management'
    Item 'Normal' 'Source code and SQL migrations are version-controlled. Supabase database and Storage backups should follow the selected project plan. Secrets must be rotated if exposed. External-provider quotas and failures are mitigated with offline AI guidance, cached weather and dashboard data, SMS outbox retries, clear error dialogs, and safe manual 999 guidance. WorkManager timing is best-effort and should not be described as exact-time emergency dispatch.'
    Item 'H2' 'Training and Follow-Up'
    Item 'Normal' 'First-login onboarding and the in-app tutorial explain Oren check-in, contacts, rewards, SOS, and profile settings. Deployment verification should include a supervised three-reminder test using a consented primary contact. Logs, failed outbox rows, user feedback, crash reports, API quotas, and schema audits should be reviewed after release.'
  )
  Replace-Section-Body $document 'System Deployment' 'Chapter Summary and Evaluation' $chapter6 'Heading 1'
  Set-Paragraph $document 'At the end of each chapter, evaluate the contents stated or discussed in the relevant sub-sections. For example,' 'This chapter defined the practical deployment sequence, permissions, backend migrations, Edge Functions, secrets, backup controls, training, and follow-up checks. It also distinguishes tested application behavior from external-provider and operating-system guarantees.'
  Replace-Section-Body $document 'This chapter defined the practical deployment sequence, permissions, backend migrations, Edge Functions, secrets, backup controls, training, and follow-up checks. It also distinguishes tested application behavior from external-provider and operating-system guarantees.' 'Discussions and Conclusion' @() ''
  Set-Paragraph $document 'Chapter 6 (if applicable)' 'Chapter 6'
  $chapter6Title = Find-Paragraph $document 'System Deployment'
  $chapter6Title.Paragraph.Range.Font.Color = 0

  $chapter7 = @(
    Item 'H2' 'Summary'
    Item 'Normal' 'EthernaCare addresses delayed awareness of prolonged inactivity through a low-effort daily Oren interaction. Flutter provides a responsive interface, Supabase provides authenticated and RLS-protected cloud data, SharedPreferences improves perceived performance, and external APIs add weather, AI, location, and SMS capabilities. Agile iteration was appropriate because the project evolved through authentication, schema, contact, onboarding, responsiveness, and emergency-flow refinements.'
    Item 'H2' 'Achievements'
    Item 'Normal' 'The project implements all principal modules: email and OAuth authentication, first-login consent and verified profile setup, Oren check-ins and interactions, check-in history, trusted-contact CRUD and primary selection, rewards and Oren shop, Malaysian weather backgrounds, emergency location records, three-stage inactivity escalation, safe SMS testing, AI guidance with history and offline fallback, and legacy-planning CRUD. The automated Flutter suite reports 26 passing tests.'
    Item 'H2' 'Contributions'
    Item 'Normal' 'The main contribution is the combination of a friendly virtual-pet habit with an explicit safety signal and measured escalation. Oren makes a repetitive check-in less clinical, while the dashboard keeps safety status visible. Local-first reads, test-only emergency paths, verified contact numbers, and separation between trusted-contact SMS and manual 999 calling improve usability and reduce avoidable risk.'
    Item 'H2' 'Limitations and Future Improvements'
    Item 'Normal' 'Android background execution is best-effort and can be delayed by battery policy or force-stop behavior; web has no periodic background scheduler. SMS, OTP, OAuth, Gemini, and weather depend on external configuration, availability, quotas, and billing. Local cache is device-specific. EthernaCare is not a medical monitor and does not detect falls or vital signs. Future work should add server-scheduled monitoring, push notifications, delivery receipts, stronger integration tests, accessibility and elderly-user studies, multilingual content, and an authorized caregiver portal.'
    Item 'H2' 'Issues and Solutions'
    Item 'Normal' 'OAuth accounts initially lacked matching public profiles, so an authentication trigger and backfill were added. Database schema-cache errors were addressed with auditable idempotent SQL migrations. Primary-contact conflicts were resolved through a unique partial index and atomic RPC. Contact forms were moved from small dialogs to responsive pages. Blank post-login routing was isolated from the tutorial and guarded by explicit setup states. Weather false-rain behavior was corrected by prioritizing the selected Malaysia region and mapping official forecast summaries. Raw asynchronous and provider exceptions were replaced with friendly error dialogs, while automated tests protect the repaired flows.'
  )
  Replace-Section-Body $document 'Discussions and Conclusion' 'References' $chapter7 'Heading 1'

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
    Item 'Normal' 'Edit state, region, blood type, threshold, and escalation target from Profile. AI Guidance provides general information only. Legacy Planning stores preferences, notes, and completed private documents; it does not create legal documents.'
  )
  Replace-Section-Body $document 'APPENDIX A User Guide' 'APPENDIX B Developer Guide' $userGuide ''

  $developerGuide = @(
    Item 'H2' 'Development Requirements'
    Item 'Normal' 'Install Flutter/Dart, Android Studio or Android SDK tools, Git, and Node.js for npx-based Supabase CLI commands. Restore packages with flutter pub get and verify with flutter test.'
    Item 'H2' 'Supabase Setup'
    Item 'Normal' 'Create the Supabase project, configure the app URL and anon key, run the SQL migration and RLS files, create the private legacy-documents bucket, configure OAuth redirect URLs, deploy Edge Functions, and set Gemini, Twilio, OTP, and worker secrets. Never commit service-role or provider secrets.'
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
}

Get-Item -LiteralPath $Output, $PdfOutput | Select-Object FullName, Length, LastWriteTime
