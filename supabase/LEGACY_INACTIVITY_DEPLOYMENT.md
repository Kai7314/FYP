# Legacy Inactivity Server Deployment

The daily processor treats only a successful row in `public.checkins` as a
heartbeat. SOS and SMS alerts do not reset the inactivity clock.

At day 90, the processor warns the account owner first. A secure cancellation
page gives the owner 24 hours to stop the release. Only an uncancelled release
with no newer check-in can notify the primary contact and open seven-day
Legacy Checking access.

Legacy Checking has two server-enforced scopes:

- An SMS-verified primary contact can view funeral preferences whenever the
  owner has enabled Legacy Checking.
- Legacy Notes, document metadata, and signed document URLs are queried only
  while the protected seven-day release window is open.

## 1. Apply the database migration

```powershell
npx --yes supabase link --project-ref mekiduxpnrorkfphjgpc
npx --yes supabase db push
```

This applies the Legacy heartbeat migrations, including
`202607250001_owner_legacy_release_grace.sql`, which adds the owner warning,
one-time cancellation token, and 24-hour protection period, and
`202607250002_legacy_preference_access.sql`, which separately audits
preference-only access.

## 2. Add Edge Function secrets

Generate one private random value of at least 32 characters for
`LEGACY_CRON_SECRET`. Use the same value later in
`legacy_inactivity_cron_setup.sql`.

```powershell
npx --yes supabase secrets set LEGACY_CRON_SECRET="YOUR_RANDOM_SECRET" --project-ref mekiduxpnrorkfphjgpc
npx --yes supabase secrets set BREVO_API_KEY="YOUR_BREVO_API_KEY" --project-ref mekiduxpnrorkfphjgpc
npx --yes supabase secrets set LEGACY_NOTICE_FROM_EMAIL="YOUR_VERIFIED_BREVO_SENDER" --project-ref mekiduxpnrorkfphjgpc
npx --yes supabase secrets set LEGACY_NOTICE_FROM_NAME="EthernaCare" --project-ref mekiduxpnrorkfphjgpc
```

`LEGACY_CHECK_URL` is optional. Set it only when a public app/web link exists.

## 3. Deploy the server processor and updated access functions

```powershell
npx --yes supabase functions deploy process-legacy-inactivity --project-ref mekiduxpnrorkfphjgpc
npx --yes supabase functions deploy cancel-legacy-release --project-ref mekiduxpnrorkfphjgpc
npx --yes supabase functions deploy request-legacy-access --project-ref mekiduxpnrorkfphjgpc
npx --yes supabase functions deploy verify-legacy-access --project-ref mekiduxpnrorkfphjgpc
```

Deploy `process-legacy-inactivity` without `--no-verify-jwt` as well. Supabase
validates the project anon key first, and the processor then requires its own
`LEGACY_CRON_SECRET` header.

`cancel-legacy-release` has `verify_jwt = false` in `supabase/config.toml`
because the owner opens it from email. It never accepts a user ID alone: the
database requires the random one-time token, its unexpired hash, the matching
release window, and an explicit confirmation POST.

## 4. Schedule the noon job

Open `legacy_inactivity_cron_setup.sql`, replace both placeholders with the
same cron secret from step 2 and the project anon key, then run the file once
in Supabase SQL Editor. The schedule is `0 4 * * *`, which is 12:00 noon in
Malaysia (UTC+8).

## 5. Check server state

```sql
select jobid, jobname, schedule, active
from cron.job
where jobname = 'ethernacare-legacy-heartbeat-noon-myt';

select *
from public.legacy_heartbeat_status
order by updated_at desc;

select owner_user_id, state, owner_notice_sent_at, owner_cancel_deadline,
       owner_cancelled_at, available_at, expires_at,
       owner_notice_attempt_count, owner_notice_last_error,
       notice_attempt_count, notice_last_error
from public.legacy_access_windows
order by created_at desc;
```

One inactivity cycle can create only one access window. A cancellation or new
check-in denies that release. An expired or cancelled window is not reopened
unless a later check-in starts a new 90-day inactivity cycle.
