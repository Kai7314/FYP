# EthernaCare Completion Audit

## Implemented report requirements

- Supabase email/password authentication and verification.
- Three-tier flow: Presentation -> Service -> Repository -> Supabase/API.
- Daily Oren check-in with duplicate-day protection.
- Check-in history and streak calculation.
- Emergency contacts with validation and limits.
- SOS alert, GPS capture, retries, and delivery outbox.
- Inactivity threshold checks.
- Reward catalog, earned rewards, versioned local synchronization.
- Weather-adaptive Oren backgrounds.
- Profile and medical information.
- Funeral preferences and private will-document storage.
- AI guidance UI through a Supabase Edge Function with offline fallback.
- Daily local check-in reminders.
- User-scoped local caches and state-preserving tab navigation.

## External deployment work

- Run every SQL file under `supabase/`.
- Deploy the `ai-guidance` Edge Function and set `AI_API_URL` / `AI_API_KEY`.
- Connect `emergency_delivery_outbox` to an SMS or push provider worker.
- Configure production SMTP and authentication redirect URLs.
- Complete physical-device scenario testing for background restrictions,
  notification delivery, GPS permission denial, and device reboot.

## Explicitly out of scope in the report

- Medical diagnosis, vital-sign measurement, and fall detection.
- Automatic ambulance/police dispatch.
- Funeral marketplace, payments, legal will drafting, and notarization.
- Real-time messaging with lawyers or funeral providers.
