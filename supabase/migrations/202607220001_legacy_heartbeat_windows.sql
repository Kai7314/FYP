-- Server-owned Legacy Checking lifecycle.
-- A heartbeat is a successful check-in only. Emergency/SMS alerts do not reset it.

alter table public.contacts
  add column if not exists email text;

update public.contacts
set email = lower(btrim(email))
where email is not null;

alter table public.contacts
  drop constraint if exists contacts_email_format;
alter table public.contacts
  add constraint contacts_email_format
  check (
    email is null
    or (
      char_length(email) <= 254
      and email ~* '^[A-Z0-9.!#$%&''*+/=?^_`{|}~-]+@[A-Z0-9-]+(\.[A-Z0-9-]+)+$'
    )
  ) not valid;

create table if not exists public.legacy_access_windows (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  heartbeat_at timestamptz not null,
  primary_contact_id uuid references public.contacts(id) on delete set null,
  notice_email text,
  state text not null default 'pending'
    check (state in ('pending', 'sending', 'open', 'expired', 'revoked')),
  available_at timestamptz,
  expires_at timestamptz,
  notice_sent_at timestamptz,
  notice_attempt_count integer not null default 0,
  notice_last_error text,
  claimed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_user_id, heartbeat_at),
  check (
    (available_at is null and expires_at is null)
    or (available_at is not null and expires_at > available_at)
  )
);

create index if not exists legacy_access_windows_state_idx
on public.legacy_access_windows(state, created_at);

create index if not exists legacy_access_windows_owner_idx
on public.legacy_access_windows(owner_user_id, heartbeat_at desc);

create table if not exists public.legacy_heartbeat_status (
  owner_user_id uuid primary key references auth.users(id) on delete cascade,
  last_heartbeat_at timestamptz not null,
  no_heartbeat_days integer not null default 0 check (no_heartbeat_days >= 0),
  state text not null default 'waiting'
    check (state in (
      'disabled',
      'waiting',
      'notice_pending',
      'window_open',
      'window_expired',
      'revoked'
    )),
  access_window_id uuid references public.legacy_access_windows(id)
    on delete set null,
  updated_at timestamptz not null default now()
);

alter table public.legacy_access_windows enable row level security;
alter table public.legacy_heartbeat_status enable row level security;

revoke insert, update, delete on public.legacy_access_windows
from anon, authenticated;
revoke insert, update, delete on public.legacy_heartbeat_status
from anon, authenticated;

drop policy if exists "legacy_access_windows_select_own"
on public.legacy_access_windows;
create policy "legacy_access_windows_select_own"
on public.legacy_access_windows for select
to authenticated
using ((select auth.uid()) = owner_user_id);

drop policy if exists "legacy_heartbeat_status_select_own"
on public.legacy_heartbeat_status;
create policy "legacy_heartbeat_status_select_own"
on public.legacy_heartbeat_status for select
to authenticated
using ((select auth.uid()) = owner_user_id);

create or replace function public.legacy_latest_heartbeat(p_user_id uuid)
returns timestamptz
language sql
stable
security definer
set search_path = public
as $$
  select greatest(
    users.legacy_access_started_at,
    coalesce(max(checkins.checkin_time), users.legacy_access_started_at)
  )
  from public.users users
  left join public.checkins checkins on checkins.user_id = users.id
  where users.id = p_user_id
  group by users.legacy_access_started_at;
$$;

revoke all on function public.legacy_latest_heartbeat(uuid) from public;
grant execute on function public.legacy_latest_heartbeat(uuid) to service_role;

create or replace function public.refresh_legacy_heartbeat_status(
  p_now timestamptz default now()
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  processed_count integer;
  pending_count integer;
  open_count integer;
begin
  -- A new check-in, disabled owner, or changed primary contact revokes access.
  update public.legacy_access_windows windows
  set
    state = 'revoked',
    claimed_at = null,
    updated_at = p_now,
    notice_last_error = case
      when notice_last_error is null then 'Eligibility changed before access completed.'
      else notice_last_error
    end
  where windows.state in ('pending', 'sending', 'open')
    and (
      not exists (
        select 1
        from public.users users
        where users.id = windows.owner_user_id
          and users.legacy_access_enabled
          and public.legacy_latest_heartbeat(users.id) = windows.heartbeat_at
      )
      or (
        windows.state in ('sending', 'open')
        and not exists (
          select 1
          from public.contacts contacts
          where contacts.id = windows.primary_contact_id
            and contacts.user_id = windows.owner_user_id
            and contacts.is_primary
            and contacts.phone_verified_at is not null
        )
      )
    );

  update public.legacy_access_windows
  set
    state = 'expired',
    claimed_at = null,
    updated_at = p_now
  where state = 'open'
    and expires_at <= p_now;

  -- Recover a delivery claim if an Edge Function stopped unexpectedly.
  update public.legacy_access_windows
  set
    state = 'pending',
    claimed_at = null,
    updated_at = p_now,
    notice_last_error = 'The previous email attempt did not finish and will be retried.'
  where state = 'sending'
    and claimed_at < p_now - interval '30 minutes';

  with snapshots as (
    select
      users.id as owner_user_id,
      public.legacy_latest_heartbeat(users.id) as heartbeat_at,
      greatest(
        0,
        floor(extract(epoch from (
          p_now - public.legacy_latest_heartbeat(users.id)
        )) / 86400)::integer
      ) as no_heartbeat_days,
      contacts.id as primary_contact_id,
      lower(btrim(contacts.email)) as notice_email
    from public.users users
    left join lateral (
      select contacts.id, contacts.email
      from public.contacts contacts
      where contacts.user_id = users.id
        and contacts.is_primary
      limit 1
    ) contacts on true
    where users.legacy_access_enabled
  )
  insert into public.legacy_access_windows (
    owner_user_id,
    heartbeat_at,
    primary_contact_id,
    notice_email,
    state,
    created_at,
    updated_at
  )
  select
    snapshots.owner_user_id,
    snapshots.heartbeat_at,
    snapshots.primary_contact_id,
    snapshots.notice_email,
    'pending',
    p_now,
    p_now
  from snapshots
  where snapshots.no_heartbeat_days >= 90
  on conflict (owner_user_id, heartbeat_at) do nothing;

  -- A pending notice follows the current primary contact until delivery.
  with current_contacts as (
    select
      windows.id as window_id,
      contacts.id as primary_contact_id,
      lower(btrim(contacts.email)) as notice_email,
      contacts.phone_verified_at
    from public.legacy_access_windows windows
    left join lateral (
      select contacts.id, contacts.email, contacts.phone_verified_at
      from public.contacts contacts
      where contacts.user_id = windows.owner_user_id
        and contacts.is_primary
      limit 1
    ) contacts on true
    where windows.state = 'pending'
  )
  update public.legacy_access_windows windows
  set
    primary_contact_id = current_contacts.primary_contact_id,
    notice_email = current_contacts.notice_email,
    notice_last_error = case
      when current_contacts.primary_contact_id is null
        then 'A primary trusted contact is required.'
      when current_contacts.phone_verified_at is null
        then 'The primary trusted contact phone must be verified.'
      when current_contacts.notice_email is null
        or current_contacts.notice_email = ''
        then 'The primary trusted contact email is missing.'
      else null
    end,
    updated_at = p_now
  from current_contacts
  where windows.id = current_contacts.window_id;

  with snapshots as (
    select
      users.id as owner_user_id,
      users.legacy_access_enabled,
      public.legacy_latest_heartbeat(users.id) as heartbeat_at,
      greatest(
        0,
        floor(extract(epoch from (
          p_now - public.legacy_latest_heartbeat(users.id)
        )) / 86400)::integer
      ) as no_heartbeat_days
    from public.users users
  ), current_windows as (
    select distinct on (windows.owner_user_id)
      windows.owner_user_id,
      windows.id,
      windows.heartbeat_at,
      windows.state
    from public.legacy_access_windows windows
    order by windows.owner_user_id, windows.created_at desc
  )
  insert into public.legacy_heartbeat_status (
    owner_user_id,
    last_heartbeat_at,
    no_heartbeat_days,
    state,
    access_window_id,
    updated_at
  )
  select
    snapshots.owner_user_id,
    snapshots.heartbeat_at,
    snapshots.no_heartbeat_days,
    case
      when not snapshots.legacy_access_enabled then 'disabled'
      when snapshots.no_heartbeat_days < 90 then 'waiting'
      when current_windows.heartbeat_at is distinct from snapshots.heartbeat_at
        then 'notice_pending'
      when current_windows.state = 'open' then 'window_open'
      when current_windows.state = 'expired' then 'window_expired'
      when current_windows.state = 'revoked' then 'revoked'
      else 'notice_pending'
    end,
    case
      when current_windows.heartbeat_at = snapshots.heartbeat_at
        then current_windows.id
      else null
    end,
    p_now
  from snapshots
  left join current_windows
    on current_windows.owner_user_id = snapshots.owner_user_id
  on conflict (owner_user_id) do update set
    last_heartbeat_at = excluded.last_heartbeat_at,
    no_heartbeat_days = excluded.no_heartbeat_days,
    state = excluded.state,
    access_window_id = excluded.access_window_id,
    updated_at = excluded.updated_at;

  select count(*) into processed_count
  from public.legacy_heartbeat_status;

  select count(*) into pending_count
  from public.legacy_access_windows
  where state = 'pending';

  select count(*) into open_count
  from public.legacy_access_windows
  where state = 'open';

  return jsonb_build_object(
    'processed', processed_count,
    'pendingNotices', pending_count,
    'openWindows', open_count,
    'refreshedAt', p_now
  );
end;
$$;

revoke all on function public.refresh_legacy_heartbeat_status(timestamptz)
from public;
grant execute on function public.refresh_legacy_heartbeat_status(timestamptz)
to service_role;

create or replace function public.claim_legacy_notice_candidates(
  p_limit integer default 25,
  p_now timestamptz default now()
)
returns table (
  window_id uuid,
  owner_user_id uuid,
  owner_name text,
  heartbeat_at timestamptz,
  no_heartbeat_days integer,
  contact_id uuid,
  contact_name text,
  contact_email text,
  proposed_expires_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  with candidates as (
    select windows.id
    from public.legacy_access_windows windows
    join public.users users on users.id = windows.owner_user_id
    join public.contacts contacts
      on contacts.id = windows.primary_contact_id
      and contacts.user_id = windows.owner_user_id
      and contacts.is_primary
      and contacts.phone_verified_at is not null
    where windows.state = 'pending'
      and users.legacy_access_enabled
      and public.legacy_latest_heartbeat(users.id) = windows.heartbeat_at
      and contacts.email is not null
      and btrim(contacts.email) <> ''
    order by windows.created_at
    limit greatest(1, least(p_limit, 100))
    for update of windows skip locked
  ), claimed as (
    update public.legacy_access_windows windows
    set
      state = 'sending',
      claimed_at = p_now,
      notice_attempt_count = windows.notice_attempt_count + 1,
      notice_last_error = null,
      updated_at = p_now
    from candidates
    where windows.id = candidates.id
    returning windows.*
  )
  select
    claimed.id,
    claimed.owner_user_id,
    users.name,
    claimed.heartbeat_at,
    greatest(
      0,
      floor(extract(epoch from (p_now - claimed.heartbeat_at)) / 86400)::integer
    ),
    contacts.id,
    contacts.name,
    lower(btrim(contacts.email)),
    p_now + interval '7 days'
  from claimed
  join public.users users on users.id = claimed.owner_user_id
  join public.contacts contacts on contacts.id = claimed.primary_contact_id;
end;
$$;

revoke all on function public.claim_legacy_notice_candidates(integer, timestamptz)
from public;
grant execute on function public.claim_legacy_notice_candidates(integer, timestamptz)
to service_role;

create or replace function public.complete_legacy_notice(
  p_window_id uuid,
  p_success boolean,
  p_error text default null,
  p_now timestamptz default now()
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  target public.legacy_access_windows%rowtype;
  still_eligible boolean;
begin
  select * into target
  from public.legacy_access_windows
  where id = p_window_id
  for update;

  if not found or target.state <> 'sending' then
    return false;
  end if;

  if not p_success then
    update public.legacy_access_windows
    set
      state = 'pending',
      claimed_at = null,
      notice_last_error = left(coalesce(p_error, 'Email delivery failed.'), 1000),
      updated_at = p_now
    where id = p_window_id;
    return false;
  end if;

  select exists (
    select 1
    from public.users users
    join public.contacts contacts
      on contacts.id = target.primary_contact_id
      and contacts.user_id = users.id
      and contacts.is_primary
      and contacts.phone_verified_at is not null
      and lower(btrim(contacts.email)) = lower(btrim(target.notice_email))
    where users.id = target.owner_user_id
      and users.legacy_access_enabled
      and public.legacy_latest_heartbeat(users.id) = target.heartbeat_at
  ) into still_eligible;

  if not still_eligible then
    update public.legacy_access_windows
    set
      state = 'revoked',
      claimed_at = null,
      notice_last_error = 'Eligibility changed while the notice was being sent.',
      updated_at = p_now
    where id = p_window_id;
    return false;
  end if;

  update public.legacy_access_windows
  set
    state = 'open',
    available_at = p_now,
    expires_at = p_now + interval '7 days',
    notice_sent_at = p_now,
    claimed_at = null,
    notice_last_error = null,
    updated_at = p_now
  where id = p_window_id;

  update public.legacy_heartbeat_status
  set
    state = 'window_open',
    access_window_id = p_window_id,
    updated_at = p_now
  where owner_user_id = target.owner_user_id
    and last_heartbeat_at = target.heartbeat_at;

  return true;
end;
$$;

revoke all on function public.complete_legacy_notice(
  uuid,
  boolean,
  text,
  timestamptz
) from public;
grant execute on function public.complete_legacy_notice(
  uuid,
  boolean,
  text,
  timestamptz
) to service_role;

create or replace function public.set_legacy_access_enabled(enabled boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'You must be signed in';
  end if;

  if enabled and not exists (
    select 1
    from public.contacts contacts
    where contacts.user_id = auth.uid()
      and contacts.is_primary
      and contacts.phone_verified_at is not null
      and contacts.email is not null
      and btrim(contacts.email) <> ''
  ) then
    raise exception 'Add a valid email and verify the primary contact phone before enabling Legacy Checking';
  end if;

  perform set_config('app.legacy_access_update', 'allowed', true);

  update public.users
  set
    legacy_access_enabled = enabled,
    legacy_access_test_enabled = case
      when enabled then legacy_access_test_enabled
      else false
    end,
    legacy_access_started_at = case
      when enabled then now()
      else legacy_access_started_at
    end
  where id = auth.uid();

  if not found then
    raise exception 'User profile was not found';
  end if;

  if not enabled then
    update public.legacy_access_windows
    set
      state = 'revoked',
      claimed_at = null,
      notice_last_error = 'Legacy Checking was disabled by the account owner.',
      updated_at = now()
    where owner_user_id = auth.uid()
      and state in ('pending', 'sending', 'open');
  end if;
end;
$$;

revoke all on function public.set_legacy_access_enabled(boolean) from public;
grant execute on function public.set_legacy_access_enabled(boolean)
to authenticated;

create or replace function public.set_legacy_access_test_enabled(enabled boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'You must be signed in';
  end if;

  if enabled and not exists (
    select 1
    from public.contacts contacts
    where contacts.user_id = auth.uid()
      and contacts.is_primary
      and contacts.phone_verified_at is not null
      and contacts.email is not null
      and btrim(contacts.email) <> ''
  ) then
    raise exception 'Add a valid email and verify the primary contact phone before enabling testing access';
  end if;

  perform set_config('app.legacy_access_update', 'allowed', true);

  update public.users
  set legacy_access_test_enabled = enabled
  where id = auth.uid()
    and (not enabled or legacy_access_enabled);

  if not found then
    raise exception 'Enable Legacy Checking before testing access';
  end if;
end;
$$;

revoke all on function public.set_legacy_access_test_enabled(boolean)
from public;
grant execute on function public.set_legacy_access_test_enabled(boolean)
to authenticated;

notify pgrst, 'reload schema';
