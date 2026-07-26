-- Use this only after the Python server has a public HTTPS URL.
-- Store LEGACY_CRON_SECRET in Supabase Vault as legacy_cron_secret first.
-- Do not run both this job and the Edge Function job at the same time.

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

select cron.unschedule(jobid)
from cron.job
where jobname in (
  'ethernacare-python-legacy-heartbeat-noon-myt',
  'ethernacare-python-legacy-heartbeat-midnight-myt'
);

select cron.schedule(
  'ethernacare-python-legacy-heartbeat-midnight-myt',
  '0 16 * * *',
  $cron$
    select net.http_post(
      url := 'https://YOUR-PYTHON-SERVER/jobs/legacy-inactivity',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-legacy-cron-secret', (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'legacy_cron_secret'
          order by created_at desc
          limit 1
        )
      ),
      body := jsonb_build_object('source', 'supabase_cron', 'time', now()),
      timeout_milliseconds := 30000
    );
  $cron$
);
