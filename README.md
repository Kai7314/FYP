# EthernaCare

EthernaCare is a Flutter well-being and safety application built around rolling
check-in windows, trusted contacts, an Oren virtual companion, virtual rewards,
and controlled legacy-planning access.

## Current architecture

- Flutter supports Android, Windows, and web from one application codebase.
- Supabase Auth provides email/password and Google authentication.
- Supabase Postgres stores profiles, check-ins, contacts, rewards, alerts, and
  legacy-planning metadata with row-level security.
- Supabase Storage keeps legacy documents in a private bucket.
- Supabase Edge Functions handle OTP, SMS delivery, legacy access, and scheduled
  inactivity processing.
- Supabase Cron invokes the server workers even when the phone is closed.
- Android WorkManager performs supplemental local checks and notifications; it
  is not the source of truth for server escalation.

The Python service in `server/python_legacy_server` is an understandable
alternative implementation of the 90-day legacy worker. Production currently
uses the equivalent Supabase Edge Function, so the Python server should not be
scheduled at the same time.

## Main behavior

### Rolling check-ins

The user's inactivity threshold can be 1 to 168 hours. A successful check-in
starts a new rolling window. At two missed windows, EthernaCare queues an SMS to
the user's verified phone. At three missed windows, the configured primary
contact escalation is queued. Server-side processing is authoritative and does
not require the app to remain open.

### Legacy access

Funeral preferences can be checked by the verified primary contact after
identity verification. Legacy notes and secure documents require 90 days
without a check-in, followed by a 24-hour owner warning. If the owner does not
cancel or check in, the primary contact receives a notice and access opens for
seven days. A new check-in resets the inactivity period.

### Oren and rewards

Oren energy decays over time and is restored through care actions. Daily login
and check-in rewards are idempotent. Tokens, owned items, selected items, badge
claims, vouchers, and reward redemptions are stored per user. Admin mode manages
the virtual reward catalog separately from the user interface.

## Local setup

1. Install Flutter and run `flutter doctor`.
2. From this directory, run `flutter pub get`.
3. Start the app with `flutter run`.

The checked-in public Supabase URL and anonymous key target the development
project. A different environment can be selected without editing source code:

```powershell
flutter run --dart-define=SUPABASE_URL=https://PROJECT.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=PUBLIC_ANON_KEY
```

Developer safety controls are visible in debug builds. To enable them
explicitly in another build, use `--dart-define=ENABLE_SAFETY_TESTS=true`.

Admin catalog mode is intentionally separate:

```powershell
cd C:\Users\user\StudioProjects\fyp
flutter run -d windows --dart-define=ADMIN_MODE=true
```

## Supabase deployment

Apply migrations in `supabase/migrations` in filename order. Deploy these Edge
Functions after changing their source:

- `request-phone-otp`
- `verify-phone-otp`
- `send-emergency-sms`
- `process-inactivity-thresholds`
- `request-legacy-access`
- `verify-legacy-access`
- `process-legacy-inactivity`
- `cancel-legacy-release`
- `legacy-server-test`
- `ai-guidance`

Required hosted secrets include the Twilio account SID, auth token and sender
number, `PHONE_OTP_SECRET`, `LEGACY_CRON_SECRET`, and the configured Brevo email
credentials. Never place service-role, Twilio, or email credentials in Flutter
source code.

## Verification

```powershell
flutter test
flutter test --coverage
flutter analyze
flutter build apk --debug
```

SMS, biometrics, background execution, location permissions, and direct calling
must also be tested on a physical Android device. Edge Function logs and Cron
run history should be checked in the Supabase Dashboard after each deployment.

## Release checklist

- Replace the placeholder Android application ID `com.example.fyp` before a
  store release, then update Google OAuth and signing configuration together.
- Move sensitive offline profile and medical caches from SharedPreferences to
  encrypted platform storage before handling production health information.
- Decide whether direct Android SMS permission is required for distribution;
  Google Play restricts this permission. The Supabase SMS worker remains the
  server fallback.
- Configure verified production email and SMS senders, budgets, rate limits,
  monitoring, and retention policies.
- Complete physical-device acceptance testing and accessibility testing with
  large text, screen readers, denied permissions, and intermittent networks.
