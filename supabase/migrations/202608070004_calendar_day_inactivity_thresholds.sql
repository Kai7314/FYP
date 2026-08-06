-- Use complete Malaysia calendar days for check-in windows. The existing
-- integer columns continue to store 24-hour multiples for backward-compatible
-- clients, while all expiry calculations occur at 12:00 AM MYT.

alter table public.users
  alter column inactivity_threshold set default 24;

update public.users
set inactivity_threshold = greatest(
  1,
  least(
    7,
    ceil(coalesce(inactivity_threshold, 24)::numeric / 24)::integer
  )
) * 24;

alter table public.users
  drop constraint if exists users_inactivity_threshold_range;

alter table public.users
  add constraint users_inactivity_threshold_range check (
    inactivity_threshold between 24 and 168
    and inactivity_threshold % 24 = 0
  ) not valid;

alter table public.users
  validate constraint users_inactivity_threshold_range;

update public.inactivity_monitor_status
set threshold_hours = greatest(
  1,
  least(7, ceil(coalesce(threshold_hours, 24)::numeric / 24)::integer)
) * 24;

alter table public.inactivity_monitor_status
  drop constraint if exists inactivity_monitor_status_threshold_hours_check;

alter table public.inactivity_monitor_status
  add constraint inactivity_monitor_status_threshold_hours_check check (
    threshold_hours between 24 and 168
    and threshold_hours % 24 = 0
  ) not valid;

alter table public.inactivity_monitor_status
  validate constraint inactivity_monitor_status_threshold_hours_check;

create or replace function public.record_threshold_checkin()
returns table (
  created boolean,
  checkin_time timestamptz,
  next_due_at timestamptz,
  threshold_hours integer
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  current_user_id uuid := auth.uid();
  configured_threshold integer;
  configured_days integer;
  latest_checkin timestamptz;
  recorded_checkin timestamptz;
  calculated_next_due timestamptz;
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(current_user_id::text, 0));

  select greatest(
    24,
    least(168, coalesce(users.inactivity_threshold, 24))
  )::integer
    into configured_threshold
  from public.users users
  where users.id = current_user_id;

  configured_threshold := coalesce(configured_threshold, 24);
  configured_days := greatest(1, least(7, configured_threshold / 24));

  select max(checkins.checkin_time)
    into latest_checkin
  from public.checkins checkins
  where checkins.user_id = current_user_id;

  if latest_checkin is not null then
    calculated_next_due := (
      (
        (latest_checkin at time zone 'Asia/Kuala_Lumpur')::date +
        configured_days
      )::timestamp at time zone 'Asia/Kuala_Lumpur'
    );

    if now() < calculated_next_due then
      return query
      select false, latest_checkin, calculated_next_due, configured_threshold;
      return;
    end if;
  end if;

  insert into public.checkins (user_id, checkin_time, status)
  values (current_user_id, now(), 'active')
  returning public.checkins.checkin_time into recorded_checkin;

  calculated_next_due := (
    (
      (recorded_checkin at time zone 'Asia/Kuala_Lumpur')::date +
      configured_days
    )::timestamp at time zone 'Asia/Kuala_Lumpur'
  );

  return query
  select true, recorded_checkin, calculated_next_due, configured_threshold;
end;
$$;

revoke all on function public.record_threshold_checkin()
from public, anon, authenticated;
grant execute on function public.record_threshold_checkin()
to authenticated;

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
      greatest(
        24,
        least(168, coalesce(users.inactivity_threshold, 24))
      )::integer as threshold_hours,
      greatest(
        0,
        (
          (p_now at time zone 'Asia/Kuala_Lumpur')::date -
          (latest_checkins.checkin_time at time zone 'Asia/Kuala_Lumpur')::date
        ) / greatest(
          1,
          least(7, coalesce(users.inactivity_threshold, 24) / 24)
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
      (status.threshold_hours / 24)::text || '-' ||
      case when status.threshold_hours = 24 then 'day' else 'days' end ||
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
from public, anon, authenticated;
grant execute on function public.refresh_inactivity_threshold_status(timestamptz)
to service_role;

create or replace function public.queue_current_user_inactivity_sms(
  p_last_checkin timestamptz,
  p_test_mode boolean default false
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  profile public.users%rowtype;
  monitor public.inactivity_monitor_status%rowtype;
  minute_key bigint := floor(extract(epoch from now()) / 60)::bigint;
  heartbeat_key bigint := extract(epoch from p_last_checkin)::bigint;
  threshold_days integer;
  message_body text;
begin
  if current_user_id is null then raise exception 'Authentication required'; end if;
  select users.* into profile from public.users users where users.id = current_user_id;
  if profile.phone_verified_at is null or btrim(coalesce(profile.phone, '')) = '' then
    raise exception 'Add and verify your phone number before SMS reminders can be sent';
  end if;

  if not p_test_mode then
    select status.* into monitor
    from public.inactivity_monitor_status status
    where status.user_id = current_user_id;
    if not found or monitor.missed_windows < 2
       or abs(extract(epoch from (monitor.last_checkin_at - p_last_checkin))) >= 1 then
      raise exception 'The inactivity reminder is not due';
    end if;
  end if;

  threshold_days := greatest(
    1,
    least(7, coalesce(profile.inactivity_threshold, 24) / 24)
  );
  message_body := case when p_test_mode then 'TEST - ' else '' end ||
    'EthernaCare check-in reminder: you have missed two ' ||
    threshold_days::text || '-' ||
    case when threshold_days = 1 then 'day' else 'days' end ||
    ' check-in windows. Open EthernaCare and tap Oren now. If inactivity continues, your configured emergency escalation may notify your primary trusted contact.';

  insert into public.emergency_delivery_outbox (
    alert_id, user_id, contact_name, contact_phone, message_body,
    delivery_key, status, attempt_count
  ) values (
    'inactivity-user-' || current_user_id::text || '-' || heartbeat_key::text,
    current_user_id, coalesce(nullif(btrim(profile.name), ''), 'EthernaCare user'),
    profile.phone, message_body,
    case when p_test_mode
      then 'test-user-sms:' || current_user_id::text || ':' || minute_key::text
      else 'inactivity-user:' || current_user_id::text || ':' || heartbeat_key::text
    end,
    'pending', 0
  ) on conflict (delivery_key) where delivery_key is not null do nothing;
  return true;
end;
$$;

revoke all on function public.queue_current_user_inactivity_sms(timestamptz, boolean)
from public, anon, authenticated;
grant execute on function public.queue_current_user_inactivity_sms(timestamptz, boolean)
to authenticated;

delete from public.emergency_delivery_outbox
where delivery_key like 'inactivity-%'
  and status <> 'sent';

select public.refresh_inactivity_threshold_status(now());

select cron.unschedule(jobid)
from cron.job
where jobname in (
  'ethernacare-inactivity-threshold-15m',
  'ethernacare-inactivity-threshold-midnight-myt'
);

select cron.schedule(
  'ethernacare-inactivity-threshold-midnight-myt',
  '0 16 * * *',
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
