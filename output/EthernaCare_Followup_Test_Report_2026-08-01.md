# EthernaCare Follow-up Test Report

**Test date:** 1 August 2026  
**Environment:** Windows 11, Flutter 3.38.5, Dart 3.10.4  
**Supabase project:** `mekiduxpnrorkfphjgpc`

## Scope

This pass resolved the outstanding SMS worker, database migration, mobile-web
viewport, static-analysis, and coverage findings. It also rechecked Android
build integration for WorkManager, SMS, biometrics, notifications, and location.
No real SMS was sent because no controlled recipient was authorized for this
test.

## Final Results

| Test | Result | Evidence |
|---|---:|---|
| Flutter automated suite | PASS | 132 of 132 tests passed |
| Line coverage | PASS | 2,422 of 7,873 lines, 30.76% |
| Static analysis | PASS | No issues found |
| Supabase SMS worker | PASS | `send-emergency-sms` ACTIVE, version 2 |
| SMS endpoint health | PASS | Live `OPTIONS` request returned HTTP 200 |
| Threshold migration | PASS | `202608010001` matches local and remote histories |
| Web release build | PASS | `build/web`; WebAssembly dry run passed |
| Mobile viewport | PASS | Actual Chrome DevTools viewport 390 x 844, DPR 1 |
| Android debug build | PASS | `build/app/outputs/flutter-apk/app-debug.apk` |
| Android plugin manifest | PASS | SMS, location, biometrics, notifications, boot, and WorkManager present |

The verified mobile-web screenshot is
`output/web-mobile-cdp-390x844.png`. The generated web artifact contains
`width=device-width, initial-scale=1.0, viewport-fit=cover` and the EthernaCare
description.

## Implemented Fixes

- Deployed `send-emergency-sms` and applied migration `202608010001`.
- Added atomic outbox claiming to prevent concurrent duplicate SMS sends.
- Added retry visibility for failed and exhausted SMS deliveries.
- Fixed the client result so a failed outbox insert is never shown as queued.
- Added the missing mobile viewport declaration and rebuilt the web release.
- Removed deprecated and unused API usage; static analysis is clean.
- Corrected Malaysia weather-region ordering so Pahang, Terengganu, and
  Kelantan are reachable instead of being swallowed by broader regions.
- Expanded automated testing from 78 to 132 tests.

## Coverage Detail

| Area | Coverage |
|---|---:|
| Admin reward editor | 94.8% |
| Weather service | 89.4% |
| User service | 83.6% |
| Contact service | 82.2% |
| Scheduler | 80.0% |
| Oren care service | 78.6% |
| Check-in service | 70.5% |
| Reward service | 67.4% |
| Legacy document service | 66.7% |
| Inactivity monitor | 66.7% |
| Background service | 62.5% |
| Emergency service | 61.3% |
| Inactivity service | 60.8% |

## Physical Acceptance Tests

The code, manifest, builds, and plugin-facing services pass. These final tests
still require a physical Android device and cannot be truthfully replaced by a
desktop test:

- send one controlled Twilio SMS and confirm carrier delivery;
- grant and deny Android SMS, notification, and location permissions;
- confirm WorkManager execution after Doze, reboot, and battery optimization;
- authenticate with a real fingerprint or face sensor;
- verify GPS accuracy and the Maps location included in an emergency SMS.

The configured Pixel 8a AVD was started headlessly but did not register with
ADB, so no emulator runtime result is claimed. The final APK is ready for the
physical-device acceptance pass.

## Release Position

The original software blockers are resolved and the automated release gate is
green. Production SMS configuration is present and the worker is live. Actual
carrier delivery and hardware behavior remain acceptance evidence to collect on
a controlled physical device, not unresolved application code defects.
