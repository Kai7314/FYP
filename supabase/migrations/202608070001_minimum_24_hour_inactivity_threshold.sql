-- Require at least one full day for each inactivity check-in window.

alter table public.users
  alter column inactivity_threshold set default 24;

update public.users
set inactivity_threshold = 24
where inactivity_threshold is null
   or inactivity_threshold < 24;

alter table public.users
  drop constraint if exists users_inactivity_threshold_range;

alter table public.users
  add constraint users_inactivity_threshold_range
  check (inactivity_threshold between 24 and 168) not valid;

alter table public.users
  validate constraint users_inactivity_threshold_range;

with recalculated as (
  select
    status.user_id,
    greatest(
      24,
      least(168, coalesce(users.inactivity_threshold, 24))
    )::integer as threshold_hours,
    greatest(
      0,
      floor(
        extract(epoch from (now() - status.last_checkin_at)) /
        (
          greatest(
            24,
            least(168, coalesce(users.inactivity_threshold, 24))
          ) * 3600
        )
      )
    )::integer as missed_windows
  from public.inactivity_monitor_status status
  join public.users users on users.id = status.user_id
)
update public.inactivity_monitor_status status
set
  threshold_hours = recalculated.threshold_hours,
  missed_windows = recalculated.missed_windows,
  user_sms_status = case
    when recalculated.missed_windows < 2 then 'not_due'
    else status.user_sms_status
  end,
  user_sms_error = case
    when recalculated.missed_windows < 2 then null
    else status.user_sms_error
  end,
  escalated_at = case
    when recalculated.missed_windows < 3 then null
    else status.escalated_at
  end,
  updated_at = now()
from recalculated
where recalculated.user_id = status.user_id;

update public.emergency_delivery_outbox outbox
set
  status = 'cancelled',
  processed_at = now(),
  last_error = 'Cancelled because the minimum inactivity threshold is now 24 hours.'
from public.inactivity_monitor_status status
where status.user_id = outbox.user_id
  and outbox.status in ('pending', 'processing', 'failed')
  and (
    (
      outbox.delivery_key like 'inactivity-user:%'
      and status.missed_windows < 2
    )
    or (
      outbox.delivery_key like 'inactivity-contact:%'
      and status.missed_windows < 3
    )
  );

alter table public.inactivity_monitor_status
  drop constraint if exists inactivity_monitor_status_threshold_hours_check;

alter table public.inactivity_monitor_status
  add constraint inactivity_monitor_status_threshold_hours_check
  check (threshold_hours between 24 and 168) not valid;

alter table public.inactivity_monitor_status
  validate constraint inactivity_monitor_status_threshold_hours_check;
