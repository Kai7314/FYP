# EthernaCare Python Legacy Server

This FastAPI server is the Python equivalent of the Supabase
`process-legacy-inactivity` Edge Function. It does not depend on the phone and
can be hosted on any HTTPS Python platform.

## What it does

1. Authenticates the scheduled request with `LEGACY_CRON_SECRET`.
2. Calls `refresh_legacy_heartbeat_status` in Supabase.
3. Sends the day-90 account-owner warning without duplicates.
4. Gives the owner 24 hours to check in or confirm cancellation.
5. Claims the primary-contact notice only after an uncancelled grace period.
6. Sends notices through the Brevo transactional email API.
7. Opens Legacy Checking for exactly seven days after contact delivery.
8. Records failed deliveries for retry during the next scheduled run.

SOS and SMS alarm records are not read. Only the newest `checkins.checkin_time`
is a heartbeat.

## Database attributes

No additional user attribute is required. The deployed database already has:

- `legacy_heartbeat_status.no_heartbeat_days`: current consecutive inactivity.
- `legacy_heartbeat_status.last_heartbeat_at`: latest successful heartbeat.
- `legacy_heartbeat_status.state`: waiting, notice pending, open, or expired.
- `legacy_access_windows.owner_notice_sent_at`: owner warning delivery time.
- `legacy_access_windows.owner_cancel_deadline`: end of the 24-hour protection.
- `legacy_access_windows.owner_cancelled_at`: confirmed owner cancellation.
- `legacy_access_windows.available_at` and `expires_at`: seven-day access period.

Cancellation tokens are not stored on the user or window row. Only a SHA-256
hash is kept in the RLS-locked `legacy_release_cancel_tokens` table.

Keeping `no_heartbeat_days` outside `users` prevents clients from editing a
security-sensitive derived value.

## Run locally

```powershell
cd server\python_legacy_server
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8080
```

Copy the names from `.env.example` into your host's environment settings. Do
not commit real keys.

## Test

```powershell
cd server\python_legacy_server
python -m unittest discover -s tests -v
```

## Schedule

After deployment, replace `YOUR-PYTHON-SERVER` in `supabase_cron.sql` and run
that SQL once. The schedule `0 16 * * *` means 12:00 AM Malaysia time.

Run either the Python Cron target or the TypeScript Edge Function target, not
both. Database claim locking prevents duplicate work, but one configured
worker is easier to operate and explain.
