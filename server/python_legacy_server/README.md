# EthernaCare Python Legacy Server

This FastAPI server is the Python equivalent of the Supabase
`process-legacy-inactivity` Edge Function. It does not depend on the phone and
can be hosted on any HTTPS Python platform.

## What it does

1. Authenticates the scheduled request with `LEGACY_CRON_SECRET`.
2. Calls `refresh_legacy_heartbeat_status` in Supabase.
3. Claims day-90 email notices without duplicates.
4. Sends the notice through the Brevo transactional email API.
5. Opens Legacy Checking for exactly seven days after successful delivery.
6. Records a failed delivery for retry during the next scheduled run.

SOS and SMS alarm records are not read. Only the newest `checkins.checkin_time`
is a heartbeat.

## Database attributes

No additional user attribute is required. The deployed database already has:

- `legacy_heartbeat_status.no_heartbeat_days`: current consecutive inactivity.
- `legacy_heartbeat_status.last_heartbeat_at`: latest successful heartbeat.
- `legacy_heartbeat_status.state`: waiting, notice pending, open, or expired.
- `legacy_access_windows.available_at` and `expires_at`: seven-day access period.

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
that SQL once. The schedule `0 4 * * *` means 12:00 noon Malaysia time.

Run either the Python Cron target or the TypeScript Edge Function target, not
both. Database claim locking prevents duplicate work, but one configured
worker is easier to operate and explain.
