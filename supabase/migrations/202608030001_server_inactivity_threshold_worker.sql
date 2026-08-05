-- Make threshold-based inactivity monitoring independent of the phone process.

create table if not exists public.inactivity_monitor_status (
  user_id uuid primary key references auth.users(id) on delete cascade,
  last_checkin_at timestamptz not null,
  threshold_hours integer not null default 24
    check (threshold_hours between 1 and 168),
  missed_windows integer not null default 0 check (missed_windows >= 0),
  user_sms_status text not null default 'not_due'
    check (user_sms_status in ('not_due', 'queued', 'sent', 'failed')),
  user_sms_error text,
  escalated_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.inactivity_monitor_status enable row level security;

drop policy if exists "inactivity_status_select_own"
on public.inactivity_monitor_status;
create policy "inactivity_status_select_own"
on public.inactivity_monitor_status for select
to authenticated
using ((select auth.uid()) = user_id);

create index if not exists inactivity_monitor_status_due_idx
on public.inactivity_monitor_status(missed_windows, updated_at);

create or replace function public.refresh_inactivity_threshold_status(
  p_now timestamptz default now()
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  refreshed_count integer := 0;
  user_sms_queued integer := 0;
  contact_sms_queued integer := 0;
  alerts_created integer := 0;
begin
  perform pg_advisory_xact_lock(
    hashtextextended('ethernacare-inactivity-threshold-worker', 0)
  );

  with latest_checkins as (
    select distinct on (checkins.user_id)
      checkins.user_id,
      checkins.checkin_time
    from public.checkins checkins
    order by checkins.user_id, checkins.checkin_time desc
  ), calculated as (
    select
      users.id as user_id,
      latest_checkins.checkin_time as last_checkin_at,
      greatest(1, least(168, coalesce(users.inactivity_threshold, 24)))::integer
        as threshold_hours,
      greatest(
        0,
        floor(
          extract(epoch from (p_now - latest_checkins.checkin_time)) /
          (
            greatest(1, least(168, coalesce(users.inactivity_threshold, 24))) *
            3600
          )
        )
      )::integer as missed_windows
    from public.users users
    join latest_checkins on latest_checkins.user_id = users.id
  )
  insert into public.inactivity_monitor_status (
    user_id,
    last_checkin_at,
    threshold_hours,
    missed_windows,
    user_sms_status,
    user_sms_error,
    escalated_at,
    updated_at
  )
  select
    calculated.user_id,
    calculated.last_checkin_at,
    calculated.threshold_hours,
    calculated.missed_windows,
    'not_due',
    null,
    null,
    p_now
  from calculated
  on conflict (user_id) do update set
    last_checkin_at = excluded.last_checkin_at,
    threshold_hours = excluded.threshold_hours,
    missed_windows = excluded.missed_windows,
    user_sms_status = case
      when public.inactivity_monitor_status.last_checkin_at is distinct from
           excluded.last_checkin_at then 'not_due'
      when excluded.missed_windows < 2 then 'not_due'
      else public.inactivity_monitor_status.user_sms_status
    end,
    user_sms_error = case
      when public.inactivity_monitor_status.last_checkin_at is distinct from
           excluded.last_checkin_at then null
      when excluded.missed_windows < 2 then null
      else public.inactivity_monitor_status.user_sms_error
    end,
    escalated_at = case
      when public.inactivity_monitor_status.last_checkin_at is distinct from
           excluded.last_checkin_at then null
      when excluded.missed_windows < 3 then null
      else public.inactivity_monitor_status.escalated_at
    end,
    updated_at = p_now;

  get diagnostics refreshed_count = row_count;

  insert into public.emergency_delivery_outbox (
    alert_id,
    user_id,
    contact_name,
    contact_phone,
    message_body,
    delivery_key,
    status,
    attempt_count
  )
  select
    'inactivity-user-' || status.user_id::text || '-' ||
      extract(epoch from status.last_checkin_at)::bigint::text,
    status.user_id,
    coalesce(nullif(btrim(users.name), ''), 'EthernaCare user'),
    users.phone,
    'EthernaCare check-in reminder: you have missed two ' ||
      status.threshold_hours::text || '-' ||
      case when status.threshold_hours = 1 then 'hour' else 'hours' end ||
      ' check-in windows. Open EthernaCare and tap Oren now. If inactivity ' ||
      'continues, your configured emergency escalation may notify your ' ||
      'primary trusted contact.',
    'inactivity-user:' || status.user_id::text || ':' ||
      extract(epoch from status.last_checkin_at)::bigint::text,
    'pending',
    0
  from public.inactivity_monitor_status status
  join public.users users on users.id = status.user_id
  where status.missed_windows >= 2
    and users.phone is not null
    and btrim(users.phone) <> ''
    and users.phone_verified_at is not null
  on conflict (delivery_key) where delivery_key is not null do nothing;

  get diagnostics user_sms_queued = row_count;

  update public.inactivity_monitor_status status
  set
    user_sms_status = case
      when outbox.status = 'sent' then 'sent'
      when outbox.status = 'failed' and outbox.attempt_count >= 3 then 'failed'
      else 'queued'
    end,
    user_sms_error = case
      when outbox.status = 'failed' then outbox.last_error
      else null
    end,
    updated_at = p_now
  from public.emergency_delivery_outbox outbox
  where outbox.delivery_key =
    'inactivity-user:' || status.user_id::text || ':' ||
    extract(epoch from status.last_checkin_at)::bigint::text
    and status.missed_windows >= 2;

  update public.inactivity_monitor_status status
  set
    user_sms_status = 'failed',
    user_sms_error =
      'Add and verify your phone number before SMS reminders can be sent.',
    updated_at = p_now
  from public.users users
  where users.id = status.user_id
    and status.missed_windows >= 2
    and status.user_sms_status <> 'sent'
    and (
      users.phone is null or btrim(users.phone) = '' or
      users.phone_verified_at is null
    );

  insert into public.emergency_delivery_outbox (
    alert_id,
    user_id,
    contact_name,
    contact_phone,
    message_body,
    delivery_key,
    status,
    attempt_count
  )
  select
    'inactivity-contact-' || status.user_id::text || '-' ||
      extract(epoch from status.last_checkin_at)::bigint::text,
    status.user_id,
    contacts.name,
    contacts.phone,
    'Emergency alert from EthernaCare. The user may need help after missing ' ||
      status.missed_windows::text || ' check-in windows. Please contact them immediately.',
    'inactivity-contact:' || status.user_id::text || ':' ||
      extract(epoch from status.last_checkin_at)::bigint::text,
    'pending',
    0
  from public.inactivity_monitor_status status
  join public.users users on users.id = status.user_id
  join lateral (
    select contacts.name, contacts.phone
    from public.contacts contacts
    where contacts.user_id = status.user_id
      and contacts.is_primary
      and contacts.phone_verified_at is not null
      and contacts.phone is not null
      and btrim(contacts.phone) <> ''
    order by contacts.name
    limit 1
  ) contacts on true
  where status.missed_windows >= 3
    and coalesce(users.emergency_escalation_target, 'primary_contact') =
      'primary_contact'
  on conflict (delivery_key) where delivery_key is not null do nothing;

  get diagnostics contact_sms_queued = row_count;

  insert into public.emergency_alerts (user_id, triggered_time, status)
  select status.user_id, p_now, 'inactivity_triggered'
  from public.inactivity_monitor_status status
  where status.missed_windows >= 3
    and not exists (
      select 1
      from public.emergency_alerts alerts
      where alerts.user_id = status.user_id
        and alerts.status = 'inactivity_triggered'
        and alerts.triggered_time >= status.last_checkin_at
    );

  get diagnostics alerts_created = row_count;

  update public.inactivity_monitor_status status
  set
    escalated_at = (
      select max(alerts.triggered_time)
      from public.emergency_alerts alerts
      where alerts.user_id = status.user_id
        and alerts.status = 'inactivity_triggered'
        and alerts.triggered_time >= status.last_checkin_at
    ),
    updated_at = p_now
  where status.missed_windows >= 3
    and exists (
      select 1
      from public.emergency_alerts alerts
      where alerts.user_id = status.user_id
        and alerts.status = 'inactivity_triggered'
        and alerts.triggered_time >= status.last_checkin_at
    );

  return jsonb_build_object(
    'processed_at', p_now,
    'users_refreshed', refreshed_count,
    'user_sms_queued', user_sms_queued,
    'contact_sms_queued', contact_sms_queued,
    'alerts_created', alerts_created
  );
end;
$$;

revoke all on function public.refresh_inactivity_threshold_status(timestamptz)
from public;
grant execute on function public.refresh_inactivity_threshold_status(timestamptz)
to service_role;

select cron.unschedule(jobid)
from cron.job
where jobname = 'ethernacare-inactivity-threshold-15m';

select cron.schedule(
  'ethernacare-inactivity-threshold-15m',
  '*/15 * * * *',
  $cron$
    select net.http_post(
      url := 'https://mekiduxpnrorkfphjgpc.supabase.co/functions/v1/process-inactivity-thresholds',
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
      body := jsonb_build_object('source', 'pg_cron', 'scheduledAt', now()),
      timeout_milliseconds := 30000
    );
  $cron$
);
