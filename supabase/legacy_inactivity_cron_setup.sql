-- Run after deploying process-legacy-inactivity.
-- Schedule: every day at 12:00 AM Malaysia time (16:00 UTC).
-- Replace both placeholders. LEGACY_CRON_SECRET must match the Edge Function
-- secret. The anon key is public, but keeping it in Vault avoids duplicating
-- configuration inside the scheduled command. Never commit the real values.

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

do $$
declare
  configured_secret constant text := 'REPLACE_WITH_LEGACY_CRON_SECRET';
  configured_anon_key constant text := 'REPLACE_WITH_SUPABASE_ANON_KEY';
  existing_secret_id uuid;
begin
  if configured_secret = 'REPLACE_WITH_LEGACY_CRON_SECRET'
     or char_length(configured_secret) < 32 then
    raise exception 'Replace LEGACY_CRON_SECRET with a random value of at least 32 characters';
  end if;
  if configured_anon_key = 'REPLACE_WITH_SUPABASE_ANON_KEY'
     or char_length(configured_anon_key) < 20 then
    raise exception 'Replace SUPABASE_ANON_KEY with the project anon key';
  end if;

  select id into existing_secret_id
  from vault.decrypted_secrets
  where name = 'legacy_cron_secret'
  order by created_at desc
  limit 1;

  if existing_secret_id is null then
    perform vault.create_secret(
      configured_secret,
      'legacy_cron_secret',
      'Authorizes the daily EthernaCare Legacy heartbeat processor'
    );
  else
    perform vault.update_secret(
      existing_secret_id,
      configured_secret,
      'legacy_cron_secret',
      'Authorizes the daily EthernaCare Legacy heartbeat processor'
    );
  end if;

  select id into existing_secret_id
  from vault.decrypted_secrets
  where name = 'legacy_cron_anon_key'
  order by created_at desc
  limit 1;

  if existing_secret_id is null then
    perform vault.create_secret(
      configured_anon_key,
      'legacy_cron_anon_key',
      'Supabase gateway key for the daily Legacy heartbeat processor'
    );
  else
    perform vault.update_secret(
      existing_secret_id,
      configured_anon_key,
      'legacy_cron_anon_key',
      'Supabase gateway key for the daily Legacy heartbeat processor'
    );
  end if;
end;
$$;

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

select jobid, jobname, schedule, active
from cron.job
where jobname = 'ethernacare-legacy-heartbeat-midnight-myt';
