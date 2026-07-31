# EthernaCare Overall Quality Assurance Report

**Test date:** 31 July 2026  
**Environment:** Windows 11, Flutter 3.38.5, Dart 3.10.4  
**Project:** `C:\Users\user\StudioProjects\fyp`  
**Supabase project:** `mekiduxpnrorkfphjgpc`  
**Assessment type:** Static analysis, automated tests, build verification, UI smoke testing, live backend configuration checks, and safety workflow review

## 1. Executive Summary

**Release recommendation: CONDITIONAL FAIL / NOT READY FOR A SAFETY-CRITICAL PRODUCTION RELEASE.**

The application compiles on its primary targets, all existing Flutter automated tests pass, the linked Supabase migrations are synchronized, and the tested authentication and row-level security boundaries behave correctly. The desktop login page and separate administrator route also render successfully.

One high-priority release blocker was confirmed: the Flutter application invokes the `send-emergency-sms` Edge Function, but that function is not deployed in the linked Supabase project. Android may still send through the device SIM when native SMS permission is granted, but the server fallback and non-Android emergency SMS path will fail.

The mobile web login also clips content horizontally at a 390-pixel viewport. Additional medium-priority risks include a race condition that can create duplicate daily check-ins, a production-accessible Legacy testing bypass, no local inactivity reminder for an account that has never checked in, and low automated line coverage.

## 2. Test Result Summary

| Area | Result | Evidence |
|---|---:|---|
| Flutter static analysis | PASS WITH FINDINGS | 0 errors, 1 warning, 8 informational issues |
| Flutter automated tests | PASS | 63 of 63 tests passed |
| Flutter line coverage | WEAK | 1,620 of 7,705 lines, 21.03% |
| Android debug build | PASS | `build/app/outputs/flutter-apk/app-debug.apk` |
| Windows debug build | PASS | `build/windows/x64/runner/Debug/EthernaCare.exe` |
| Windows startup smoke test | PASS | Process remained running for 12 seconds without immediate exit |
| Web debug build | PASS | `build/web` generated successfully; Wasm dry-run also passed |
| Android release build | INCONCLUSIVE | Build command did not begin producing output and was stopped after waiting; debug build remains verified |
| Supabase migration synchronization | PASS | All 17 dated local migrations matched the linked project |
| Supabase Edge Function deployment | FAIL | 8 application functions active; `send-emergency-sms` missing |
| Supabase Auth health | PASS | Live `/auth/v1/health` returned HTTP 200 |
| Anonymous data isolation | PASS | Anonymous `users` query returned no rows under RLS |
| Desktop login rendering | PASS | 1440 x 1000 web smoke screenshot rendered correctly |
| Mobile login rendering | FAIL | Right-side content clipping at 390 x 844 |
| Separate admin route | PASS | `/admin/rewards` rendered the allowlisted Reward Admin login |
| Real SMS/email delivery | NOT EXECUTED | Avoided sending production communications during the audit |
| Android biometrics/background/location | NOT EXECUTED | No Android device was connected |
| Python worker tests | NOT EXECUTED | Python is not installed in the test environment |
| Edge Function unit tests | NOT AVAILABLE | Deno is not installed and no Deno test suite was found |

## 3. Confirmed Defects and Risks

### EC-QA-001: Emergency SMS fallback function is not deployed

**Severity:** P1 / High  
**Status:** Confirmed release blocker

The application invokes `send-emergency-sms` from `EmergencyRepository.processPendingSms()`. A live OPTIONS request to the linked Supabase project returned HTTP 404 `NOT_FOUND`, and the function was absent from the deployed function list.

**Impact:**

- Android direct SMS can work only when device SMS permission and native sending succeed.
- If native sending fails or permission is denied, the server fallback cannot process the queued alert.
- Windows and web do not have the Android direct-SIM path, so their emergency SMS processing depends on the missing function.
- This can cause a trusted contact not to receive a safety alert.

**Required action:** Deploy and smoke-test `supabase/functions/send-emergency-sms` against a controlled test contact. Confirm Twilio credentials, retry handling, outbox status transitions, and duplicate-send protection.

### EC-QA-002: Mobile web login is horizontally clipped

**Severity:** P2 / Medium  
**Status:** Confirmed

At a 390 x 844 browser viewport, the login content extends past the right edge. The source `web/index.html` has no viewport meta declaration, which is the likely root cause for mobile browser scaling. Its description metadata also still says `A new Flutter project.`

**Impact:** Mobile web users can see truncated text and controls, reducing usability and potentially making actions inaccessible.

**Required action:** Add an appropriate mobile viewport declaration, replace the placeholder description, rebuild the web application, and repeat screenshots at 320, 360, 390, 412, and 768 pixel widths.

### EC-QA-003: Daily check-in creation is vulnerable to duplicates

**Severity:** P2 / Medium  
**Status:** Confirmed code-level data-integrity risk

`CheckinRepository.addDailyCheckin()` first queries whether a daily check-in exists and then performs a separate insert. The database scripts contain a non-unique time index but no database uniqueness rule for one user check-in per Malaysia calendar day.

**Impact:** Two devices or nearly simultaneous requests can both pass the existence check and create duplicate daily records, rewards, or inconsistent history.

**Required action:** Enforce the rule in PostgreSQL using a Malaysia-day key or an atomic RPC, then change the client to use the atomic operation and handle conflict results.

### EC-QA-004: Legacy testing mode bypasses OTP

**Severity:** P2 / Medium security/configuration risk  
**Status:** Confirmed by code review

When `testingMode` is true, the owner has `legacy_access_test_enabled`, and a simulated legacy event exists, `verify-legacy-access` does not require the six-digit OTP. The Legacy UID and verified primary phone must still match, but this remains an intentional authentication bypass.

**Impact:** If a user leaves testing mode enabled in production, a person who knows the Legacy UID and primary phone can bypass SMS verification for the simulated access path.

**Required action:** Disable testing mode for production data, restrict it to allowlisted test users or a non-production Supabase project, and add an automatic expiration timestamp plus audit alerting.

### EC-QA-005: Accounts with no check-in do not receive local inactivity reminders

**Severity:** P2 / Medium behavior gap  
**Status:** Confirmed by code review

`InactivityService.checkInactivity()` returns immediately when no latest check-in exists. Therefore, an account that completes setup but never checks in does not enter the local three-reminder escalation flow.

**Impact:** The user may never receive the expected inactivity reminders unless at least one check-in has already been created.

**Required action:** Define the initial heartbeat baseline, such as account setup time or `legacy_access_started_at`, and test the no-first-check-in lifecycle explicitly.

### EC-QA-006: Automated coverage is insufficient for safety workflows

**Severity:** P2 / Medium quality risk  
**Status:** Confirmed

All 63 Flutter tests pass, but measured line coverage is only 21.03%. No automated end-to-end tests cover real SMS, email, OAuth, RLS success paths, scheduled inactivity processing, legacy release/cancellation, document signed URLs, or concurrent check-ins. Five Python domain tests exist but could not run because Python is absent. No Deno Edge Function test suite was found.

**Required action:** Add repository, Edge Function, SQL/RPC, and integration tests. Prioritize emergency escalation, duplicate prevention, 90-day plus 24-hour plus 7-day windows, owner cancellation, OTP limits, and provider failure/retry paths.

### EC-QA-007: Static analysis is not fully clean

**Severity:** P3 / Low  
**Status:** Confirmed

Static analysis reports one warning and eight informational issues. The warning is an unused optional parameter named `trailingText` in `home_screen.dart`. Informational findings include deprecated APIs and style recommendations.

**Required action:** Remove or use the parameter, replace deprecated APIs, and keep `flutter analyze` at zero issues before release.

## 4. Areas That Passed Review

- Supabase Auth health endpoint responded normally.
- Anonymous database access did not expose user profile rows.
- Protected Edge Functions rejected missing or invalid authentication/secrets.
- Legacy access uses six-digit OTPs, a ten-minute expiry, a five-attempt limit, audit records, and short-lived document links.
- The core Legacy schedule implements the 90-day inactivity threshold, 24-hour owner warning period, seven-day trusted-contact access window, and owner cancellation flow.
- Funeral preferences can be exposed separately from protected notes and documents when the configured primary-contact verification conditions are met.
- Legacy documents are restricted to PDF/JPEG/PNG, capped at 10 MB, stored in a private bucket, and exposed by signed URLs rather than public paths.
- Legacy notes have both client-side sensitive-credential detection and a database trigger safeguard.
- Emergency alerts include a Google Maps link when location is available, while still allowing an alert to be created if location acquisition fails.
- Reward catalog and virtual voucher migrations are synchronized with the linked project.
- Email registration and recovery use eight-digit email codes in the Flutter implementation.
- The optional biometric gate has service tests and does not replace the underlying Supabase session.
- Desktop login and the direct admin route rendered correctly in the web build.

## 5. Live Backend Checks Performed

The following non-destructive checks were run against the linked Supabase project:

- Auth health returned HTTP 200.
- `ai-guidance` rejected an empty question with HTTP 400.
- `request-phone-otp` rejected an anonymous request with HTTP 401.
- `legacy-server-test` rejected an anonymous request with HTTP 401.
- `process-legacy-inactivity` rejected a request without its shared secret with HTTP 401.
- Invalid legacy access input was rejected or returned a generic unavailable result without sending an SMS.
- `cancel-legacy-release` rejected an invalid token with a branded HTTP 400 page.
- `send-emergency-sms` returned HTTP 404 because it is not deployed.

No production records were intentionally created or changed, and no real SMS or email was sent during this audit.

## 6. Required Device and User-Acceptance Tests

These tests require a dedicated test account, verified provider recipients, or a physical Android device:

1. Fresh email registration, eight-digit verification, duplicate email, resend limits, forgot password, and password change.
2. Google/Facebook/GitHub OAuth first login, profile bootstrap, logout, relogin, and data synchronization.
3. Phone OTP to user and primary contact using valid and invalid Malaysia numbers.
4. SOS SMS delivery with location, without location, with Android SMS permission denied, and with Twilio unavailable.
5. Three inactivity reminders followed by exactly one primary-contact escalation SMS.
6. Daily midnight cron processing, 90-day threshold, owner warning email, cancel link, 24-hour release, and seven-day expiry.
7. Legacy preference-only access before 90 days and protected notes/documents during the active release window.
8. Android notification permission, background execution, reboot persistence, battery optimization, and delayed WorkManager execution.
9. Fingerprint/face unlock success, cancellation, lockout, unavailable hardware, and session expiration.
10. Reward creation by admin, realtime refresh, deletion, user claim, voucher generation, and badge persistence across relogin.
11. Legacy document upload, view, signed-link expiry, deletion, size/type rejection, and malicious file-signature rejection.
12. Accessibility checks including text scaling, screen reader labels, keyboard navigation, contrast, and narrow screens.

## 7. Release Gate

Do not approve a production safety release until all of the following are complete:

- [ ] Deploy and validate `send-emergency-sms`.
- [ ] Fix and retest the mobile web viewport.
- [ ] Add database-level daily check-in uniqueness.
- [ ] Disable or strongly isolate Legacy testing mode in production.
- [ ] Decide and implement the no-first-check-in inactivity baseline.
- [ ] Complete physical Android SMS, notification, background, location, and biometric tests.
- [ ] Complete controlled email/SMS end-to-end tests.
- [ ] Raise automated coverage for critical repositories and server workflows.
- [ ] Resolve all static-analysis findings.
- [ ] Complete a release APK build and installation smoke test.

## 8. Final Assessment

EthernaCare has a solid functional base and a substantial amount of backend protection. The present build is suitable for continued development and controlled demonstration after the emergency SMS deployment issue is made explicit. It should not yet be represented as production-ready for unattended safety monitoring because the server SMS fallback is absent and several high-impact workflows have not been validated on a real device with real provider delivery.
