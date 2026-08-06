# Context-Based Test Plan and Test Cases

The cases below describe functions that exist in the current EthernaCare codebase. They do not treat mocked providers, source-code inspection, or planned manual tests as completed end-to-end verification.

For manual context-based runs, the tester should record the values used, device, operating system, time, account, network condition, and provider result. Synthetic data should be used where possible.

## Evidence Status

- **PASS**: The stated behaviour is directly exercised by a currently passing automated test.
- **PARTIAL**: The feature exists and some local behaviour is tested, but the complete Supabase, provider, Realtime, background, or device path has not been verified automatically.
- **PENDING PHYSICAL**: A real device, operating-system permission, GPS signal, dialler, or carrier is required.
- **PENDING INTEGRATION**: A deployed Supabase project, RLS session, Storage operation, Edge Function, cron execution, or external provider must be exercised.

The current Flutter suite was run on 7 August 2026. All **158 tests passed**. The generated `coverage/lcov.info` contains **8,507 executable lines**, of which **2,654 were hit**, giving **31.20% line coverage**.

## Table 5.3.1: Check-In, Inactivity, and Emergency

| ID | Context and precondition | Action / data | Expected outcome based on the current app | Evidence / status |
|---|---|---|---|---|
| SAFE-01 | A signed-in user has no current check-in or the configured rolling threshold has elapsed. | Use an allowed threshold and request a check-in before, at, and after the threshold boundary. | The Flutter service calls the authenticated `record_threshold_checkin` RPC. The server response determines whether a new check-in was created. The local cache is updated only when the RPC reports `created: true`. | **PASS for deterministic service boundaries and authenticated RPC usage. PENDING INTEGRATION for a live Supabase boundary run.** |
| SAFE-02 | A user has a recorded check-in and a configured inactivity threshold. | Evaluate elapsed time before and after one, two, and three complete threshold windows. Re-run selected stages. | The current calculation produces the corresponding missed-window count. The SQL worker uses unique delivery keys and existing-alert checks intended to suppress duplicate work for the same heartbeat. | **PASS for Dart threshold calculations. PARTIAL for idempotency because the SQL/Edge worker is not executed by the Flutter test suite.** |
| SAFE-03 | The user phone and primary-contact phone have been verified. | Exercise service paths with mocked successful and failed SMS results. | The app queues automatic production SMS work through the Supabase backend. The Edge Function contains recipient and approved-message checks and records provider status in the outbox. | **PASS for mocked Flutter service paths and static server-authority contracts. PENDING INTEGRATION for the deployed Edge Function and PENDING PHYSICAL for carrier receipt.** |
| SAFE-04 | A signed-in user taps **SOS emergency** on Home. | Select **Cancel**, **Send Emergency Alert**, or **Open 999 Dialer**. For Send Emergency Alert, allow or deny the operating-system location request. | Cancel closes the dialog before the emergency service is called. Send Emergency Alert checks the configured escalation target, attempts to obtain location, records an alert when its prerequisites and backend call succeed, and queues contact delivery for primary-contact mode. Open 999 Dialer opens the external dialler; EthernaCare does not place the call. In the current `official_999` profile mode, the Send Emergency Alert service call is also permitted to open the dialler. | **PASS for service tests covering available/unavailable contacts, location, outbox fallback, and non-dialling 999 mode. No SOS dialog widget test exists. PENDING PHYSICAL for permission, GPS, SMS, and dialler behaviour.** |
| SAFE-05 | The application is foregrounded, backgrounded, resumed, or closed. | Vary elapsed time and inspect the local app and the next scheduled cloud-worker execution. | When the Flutter process evaluates inactivity, it can show a local reminder. The SQL migration configures the server inactivity worker to run every 15 minutes independently of the phone process. Local notification timing while the app is closed remains platform-dependent. | **PASS for local orchestration unit tests. PENDING INTEGRATION for live cron execution and PENDING PHYSICAL for Android background and notification timing.** |

## Table 5.3.1.2: Trusted Contact and Phone Verification

| ID | Context and precondition | Action / data | Expected outcome based on the current app | Evidence / status |
|---|---|---|---|---|
| CONTACT-01 | A signed-in user opens Contacts and has fewer than five contacts. | Enter a valid name, relationship, international phone, email, Malaysian address, state, and region. Complete phone verification when required and save. | The contact service submits the entered values for the signed-in user and refreshes the local contact cache. Email and address are required in the current implementation. | **PASS for form validation and mocked service/cache behaviour. PENDING INTEGRATION for live database persistence and reload.** |
| CONTACT-02 | A user adds or changes a contact phone number. | Request a six-digit OTP, then submit a valid, malformed, expired, or incorrect code. | The deployed request and verify functions are intended to accept only a current code tied to the authenticated user, purpose, and normalized phone. The contact cannot be saved with the new phone through the UI until verification succeeds. | **PASS for phone-format UI validation and safe error presentation. PENDING INTEGRATION and PENDING PHYSICAL for OTP expiry, incorrect-code handling, Twilio delivery, and live verification persistence.** |
| CONTACT-03 | The signed-in user has an existing set of owned contacts. | Add contacts up to the five-contact limit, attempt a duplicate number, and select a different primary contact. | The app checks the maximum count and duplicate normalized phone numbers. The repository and database logic are designed to retain at most one primary contact. | **PASS for validator, widget, and mocked contact-service behaviour. PENDING INTEGRATION for live unique-primary and limit enforcement.** |
| CONTACT-04 | Two Supabase accounts exist. | Attempt to read or modify one account's contact while authenticated as the other account. | Existing RLS policies are intended to deny cross-user access. | **PENDING INTEGRATION. No automated two-session RLS test currently proves this case.** |

## Table 5.3.1.3: Oren, Rewards, and Administrator

| ID | Context and precondition | Action / data | Expected outcome based on the current app | Evidence / status |
|---|---|---|---|---|
| OREN-01 | Oren has a saved energy value and update time. | Evaluate whole-hour, partial-hour, future-time, and zero-boundary cases. | Energy decreases by one for each complete elapsed hour, does not fall below zero, preserves the unused partial hour, and changes mood when tired. | **PASS with deterministic unit tests.** |
| OREN-02 | The user owns a selected toy and Oren's energy is around the Play boundary. | Attempt Play below, at, and above the required energy. | Play succeeds only when the current rule permits it. Refused attempts do not consume energy. | **PASS with service tests.** |
| OREN-03 | The user has a token balance and owned or unowned shop items. | Buy an affordable item, attempt an unaffordable purchase, select an owned item, play, and reload state. | A valid purchase deducts tokens and adds the item once. Unaffordable purchases and unowned selections are rejected. Production actions use authenticated Supabase RPCs; local cache supports display and recovery. | **PASS for service behaviour, cache serialization, and static server-authority contracts. PENDING INTEGRATION for live multi-device persistence.** |
| REWARD-01 | The user's real check-in progress reaches a configured badge milestone. | Open the reward, collect it, and repeat the collection action. | An eligible badge moves into Reward Collection and should not be collected more than once. | **PASS for reward service/model behaviour with mocked backend data. PENDING INTEGRATION for live database uniqueness.** |
| REWARD-02 | The user's progress reaches an active voucher milestone. | Open **Check Reward**, refresh, and sign in again. | An earned voucher appears in Reward Collection with its assigned redeem code. The service preserves the backend code in cached snapshots. | **PASS for service/model and reward-detail widget tests. PENDING INTEGRATION for live code generation and cross-session persistence.** |
| ADMIN-01 | An authorised administrator opens the separate reward-admin route. | Create or edit a badge or voucher using valid and invalid values; use manual refresh. | The editor validates required fields and saves valid values through the repository. The screen contains Realtime subscription and manual-refresh behaviour. | **PASS for editor validation and save widget tests. PENDING INTEGRATION for authorisation, Realtime propagation, and manual refresh against Supabase.** |
| ADMIN-02 | The catalogue contains active rewards. | Select a reward and request deletion. | The current admin UI and repository contain reward deletion behaviour. The live database determines whether a referenced reward can be deleted or must be retained. | **PARTIAL: implemented but no automated admin deletion test currently exists. PENDING INTEGRATION for database-reference behaviour.** |

## Table 5.3.1.4: Legacy Planning and Legacy Checking

| ID | Context and precondition | Action / data | Expected outcome based on the current app | Evidence / status |
|---|---|---|---|---|
| LEGACY-01 | A signed-in owner has configured Legacy Planning and a verified primary contact. | Save funeral preferences, save a non-sensitive Legacy Note, and upload a supported PDF, JPEG, or PNG file no larger than 10 MB. | The app saves planning data through the repository. Document upload validates extension, size, signature, owner folder, and server finalization. The Storage bucket is private in the supplied SQL. | **PASS for service behaviour, input/file validation, and static server-finalization contracts. PENDING INTEGRATION for real Storage upload, private access, and RLS.** |
| LEGACY-02 | The owner enters Legacy Note content. | Enter ordinary text and password-, PIN-, OTP-, token-, key-, or recovery-secret-like content. | Ordinary content can be saved. Recognized credential-like content is rejected before repository persistence. | **PASS with service and validation tests.** |
| LEGACY-03 | An owner has a server heartbeat and Legacy Checking is enabled. | Evaluate timestamps around 90 days, the 24-hour owner-protection period, cancellation, the seven-day contact window, and expiry. | SQL and Edge Function code implement the warning, cancellation, release, and expiry states. Flutter models parse the returned access state. | **PASS only for Flutter result parsing. PENDING INTEGRATION for the deployed cron/Edge state machine, email delivery, cancellation link, repeated worker runs, and expiry.** |
| LEGACY-04 | A person enters a Legacy UID and primary-contact phone on Legacy Check. | Submit valid and invalid identifiers, request the six-digit SMS code, and submit a valid or invalid code. | The request function normalizes the phone, validates the UID shape, checks the verified primary contact, and avoids returning protected content before successful code verification. | **PASS for Flutter response parsing and UI state tests. PENDING INTEGRATION and PENDING PHYSICAL for the deployed request/verify functions and SMS code delivery.** |
| LEGACY-05 | The primary contact has successfully verified Legacy Checking. | View funeral preferences before protected release, then test notes and documents inside and outside an active release window. | Funeral preferences may be returned in preference-only verified access. Notes and documents require the server-authorized protected-content state. Secure documents use signed URLs rather than public Storage paths. | **PASS for Flutter access-result parsing. PENDING INTEGRATION for live RLS, signed-URL expiry, protected-window enforcement, and document download.** |

## Chapter Summary and Evaluation

This chapter describes the current EthernaCare implementation and distinguishes automated evidence from work that still requires integration or physical-device testing. EthernaCare uses a Flutter client with Supabase authentication, PostgreSQL, RLS policies, private Storage, Realtime subscriptions, Edge Functions, and SQL cron configuration.

The current business rules use a configurable rolling check-in threshold. When the app evaluates the first missed window, it can show a local reminder. The scheduled server code calculates later stages, queues a user SMS at the second missed window, and queues primary-contact escalation at the third. These delivery paths remain dependent on the deployed cron job, Edge Function secrets, Twilio account, carrier rules, verified contact information, and network availability.

Oren energy decay, care actions, token handling, owned items, virtual badge collection, voucher details, Legacy Note filtering, local settings, biometrics coordination, and several UI boundaries are covered by automated Flutter tests. Live provider delivery, real RLS isolation, deployed worker timing, Android background behaviour, GPS, the 999 dialler, Storage upload/download, and cross-device synchronization still require separate evidence.

## Chapter 6: Discussions and Conclusion

### Summary

EthernaCare combines a configurable Oren safety check-in, staged inactivity monitoring, verified trusted contacts, manual SOS support, location-assisted alerts, virtual rewards, weather information, AI guidance, and consent-controlled Legacy Planning. Flutter provides the client interface, while Supabase provides authentication, relational storage, policies, private-file infrastructure, server functions, and scheduled SQL execution.

### Achieved Functions

The current code implements one-to-168-hour rolling check-in thresholds, server-authoritative check-in RPC usage, three inactivity stages, contact phone verification functions, primary-contact selection, manual SOS, optional current-location capture, backend SMS outbox processing, Oren energy decay and server actions, virtual badges and vouchers, a separate reward-admin route, Legacy preferences, filtered Legacy Notes, private-document infrastructure, owner protection, a seven-day protected-content window, biometric session locking, a first-use feature guide, and user settings.

The current Flutter test run contains **158 passing tests and 31.20% line coverage**. This is repeatable local regression evidence. It is not evidence that Twilio or Brevo delivered a message, that a carrier accepted it, that cron executed in the deployed project, that RLS blocked a real second account, or that GPS, biometrics, background execution, Storage, and the dialler worked on every supported physical device.

### Contributions

The implemented design combines a virtual companion with a configurable safety heartbeat. Oren care actions are separated from the safety check-in. Automatic inactivity processing is represented as server-owned work rather than relying on the mobile application remaining open. Legacy Planning uses a staged release design in which the owner has a protection opportunity before protected content becomes available to the verified primary contact for a limited period.

### Current Limitations and Future Verification

EthernaCare is not a medical device. It does not detect falls, unconsciousness, vital signs, death, or the reason for inactivity. It does not dispatch emergency services and cannot place a `999` call automatically. SMS and email depend on provider configuration, recipient data, regulatory filtering, account limits, and connectivity. Android local notifications are best-effort, while GPS and biometrics depend on device hardware, operating-system settings, and permission.

The project still needs live Supabase integration tests for RLS and database constraints, deployed Edge Function tests, cron-log verification over multiple runs, Twilio and Brevo provider evidence, a structured Android physical-device matrix, real Storage upload/download tests, admin Realtime and deletion tests, SOS dialog widget tests, accessibility testing with older users, and professional privacy, security, and legal review. The existing Android `SEND_SMS` permission should also be reviewed because production SOS and automatic inactivity delivery currently use the server path.

