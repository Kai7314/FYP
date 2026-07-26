-- Run the Legacy heartbeat processor daily at 12:00 AM Malaysia time.
-- Supabase Cron uses UTC, so midnight in Malaysia (UTC+8) is 16:00 UTC.

select cron.unschedule(jobid)
from cron.job
where jobname in (
  'ethernacare-legacy-heartbeat-noon-myt',
  'ethernacare-legacy-heartbeat-midnight-myt'
);

select cron.schedule(
  'ethernacare-legacy-heartbeat-midnight-myt',
  '0 16 * * *',
  $cron$
    select net.http_post(
      url := 'https://mekiduxpnrorkfphjgpc.supabase.co/functions/v1/process-legacy-inactivity',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'apikey', (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'legacy_cron_anon_key'
          order by created_at desc
          limit 1
        ),
        'Authorization', 'Bearer ' || (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'legacy_cron_anon_key'
          order by created_at desc
          limit 1
        ),
        'x-legacy-cron-secret', (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'legacy_cron_secret'
          order by created_at desc
          limit 1
        )
      ),
      body := jsonb_build_object(
        'source', 'pg_cron',
        'scheduledAt', now()
      ),
      timeout_milliseconds := 30000
    );
  $cron$
);
