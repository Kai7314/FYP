-- Reset threshold monitoring as part of the check-in transaction and prevent
-- reminders for an older heartbeat from being delivered after a new check-in.

alter table public.emergency_delivery_outbox
  drop constraint if exists emergency_delivery_outbox_status_check;

alter table public.emergency_delivery_outbox
  add constraint emergency_delivery_outbox_status_check
  check (status in ('pending', 'processing', 'sent', 'failed', 'cancelled'));

create or replace function public.reset_inactivity_monitor_on_checkin()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  configured_threshold integer;
begin
  select greatest(1, least(168, coalesce(users.inactivity_threshold, 24)))
    into configured_threshold
  from public.users users
  where users.id = new.user_id;

  configured_threshold := coalesce(configured_threshold, 24);

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
  values (
    new.user_id,
    new.checkin_time,
    configured_threshold,
    0,
    'not_due',
    null,
    null,
    now()
  )
  on conflict (user_id) do update set
    last_checkin_at = excluded.last_checkin_at,
    threshold_hours = excluded.threshold_hours,
    missed_windows = 0,
    user_sms_status = 'not_due',
    user_sms_error = null,
    escalated_at = null,
    updated_at = excluded.updated_at;

  update public.emergency_delivery_outbox
  set
    status = 'cancelled',
    processed_at = now(),
    last_error = 'Cancelled because the user completed a newer check-in.'
  where user_id = new.user_id
    and delivery_key like 'inactivity-%'
    and status in ('pending', 'processing', 'failed');

  return new;
end;
$$;

drop trigger if exists checkins_reset_inactivity_monitor on public.checkins;
create trigger checkins_reset_inactivity_monitor
after insert on public.checkins
for each row execute function public.reset_inactivity_monitor_on_checkin();

-- Bring existing monitor rows in line immediately when this migration runs.
select public.refresh_inactivity_threshold_status(now());
