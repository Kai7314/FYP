-- Make the configured inactivity threshold the authoritative check-in window.
-- The advisory lock keeps simultaneous devices from creating two heartbeats.

create or replace function public.record_threshold_checkin()
returns table (
  created boolean,
  checkin_time timestamptz,
  next_due_at timestamptz,
  threshold_hours integer
)
language plpgsql
security invoker
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  configured_threshold integer;
  latest_checkin timestamptz;
  recorded_checkin timestamptz;
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(current_user_id::text, 0));

  select greatest(1, least(168, coalesce(users.inactivity_threshold, 24)))
    into configured_threshold
  from public.users users
  where users.id = current_user_id;

  configured_threshold := coalesce(configured_threshold, 24);

  select max(checkins.checkin_time)
    into latest_checkin
  from public.checkins checkins
  where checkins.user_id = current_user_id;

  if latest_checkin is not null
     and now() < latest_checkin + make_interval(hours => configured_threshold) then
    return query
    select
      false,
      latest_checkin,
      latest_checkin + make_interval(hours => configured_threshold),
      configured_threshold;
    return;
  end if;

  insert into public.checkins (user_id, checkin_time, status)
  values (current_user_id, now(), 'active')
  returning public.checkins.checkin_time into recorded_checkin;

  return query
  select
    true,
    recorded_checkin,
    recorded_checkin + make_interval(hours => configured_threshold),
    configured_threshold;
end;
$$;

revoke all on function public.record_threshold_checkin() from public;
grant execute on function public.record_threshold_checkin() to authenticated;

-- The SMS outbox already stores emergency deliveries. A nullable delivery key
-- lets threshold reminders share it while remaining idempotent per heartbeat.
create table if not exists public.emergency_delivery_outbox (
  id bigint generated always as identity primary key,
  alert_id text not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  contact_name text,
  contact_phone text not null,
  message_body text,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'sent', 'failed')),
  attempt_count integer not null default 0,
  provider text,
  provider_message_id text,
  last_error text,
  created_at timestamptz not null default now(),
  processed_at timestamptz
);

alter table public.emergency_delivery_outbox
  add column if not exists message_body text,
  add column if not exists provider text,
  add column if not exists provider_message_id text,
  add column if not exists last_error text,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists processed_at timestamptz,
  add column if not exists delivery_key text;

create unique index if not exists emergency_delivery_outbox_delivery_key_uidx
on public.emergency_delivery_outbox(delivery_key)
where delivery_key is not null;

create index if not exists emergency_delivery_outbox_pending_idx
on public.emergency_delivery_outbox(status, created_at)
where status = 'pending';

alter table public.emergency_delivery_outbox enable row level security;

drop policy if exists "outbox_select_own" on public.emergency_delivery_outbox;
create policy "outbox_select_own"
on public.emergency_delivery_outbox for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "outbox_insert_own" on public.emergency_delivery_outbox;
create policy "outbox_insert_own"
on public.emergency_delivery_outbox for insert
to authenticated
with check ((select auth.uid()) = user_id);
