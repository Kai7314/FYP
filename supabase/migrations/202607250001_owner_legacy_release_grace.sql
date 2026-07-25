-- Give the account owner 24 hours to stop a Legacy Planning release.
-- The primary contact is notified only after the warning was delivered,
-- the grace period elapsed, no cancellation occurred, and no new check-in exists.

create extension if not exists pgcrypto with schema extensions;

alter table public.legacy_access_windows
  add column if not exists owner_notice_email text,
  add column if not exists owner_notice_sent_at timestamptz,
  add column if not exists owner_cancel_deadline timestamptz,
  add column if not exists owner_cancelled_at timestamptz,
  add column if not exists owner_notice_attempt_count integer not null default 0,
  add column if not exists owner_notice_last_error text;

create table if not exists public.legacy_release_cancel_tokens (
  window_id uuid primary key
    references public.legacy_access_windows(id) on delete cascade,
  token_hash text not null check (char_length(token_hash) = 64),
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

alter table public.legacy_release_cancel_tokens enable row level security;
revoke all on public.legacy_release_cancel_tokens from anon, authenticated;

alter table public.legacy_access_windows
  drop constraint if exists legacy_access_windows_state_check;
alter table public.legacy_heartbeat_status
  drop constraint if exists legacy_heartbeat_status_state_check;

-- Existing unsent contact notices must pass through the new owner warning.
update public.legacy_access_windows
set
  state = 'owner_notice_pending',
  claimed_at = null,
  notice_last_error = null,
  updated_at = now()
where state in ('pending', 'sending')
  and notice_sent_at is null;

update public.legacy_heartbeat_status status
set
  state = 'owner_notice_pending',
  updated_at = now()
from public.legacy_access_windows windows
where status.access_window_id = windows.id
  and windows.state = 'owner_notice_pending';

alter table public.legacy_access_windows
  add constraint legacy_access_windows_state_check
  check (state in (
    'owner_notice_pending',
    'owner_notice_sending',
    'owner_grace_period',
    'pending',
    'sending',
    'open',
    'expired',
    'revoked'
  ));

alter table public.legacy_heartbeat_status
  add constraint legacy_heartbeat_status_state_check
  check (state in (
    'disabled',
    'waiting',
    'owner_notice_pending',
    'owner_grace_period',
    'notice_pending',
    'window_open',
    'window_expired',
    'revoked'
  ));

alter table public.legacy_server_test_events
  drop constraint if exists legacy_server_test_events_action_check;
alter table public.legacy_server_test_events
  add constraint legacy_server_test_events_action_check
  check (action in (
    'live_status',
    'day_89',
    'day_90',
    'day_91',
    'day_97',
    'day_98',
    'test_email'
  ));

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
  owner_pending_count integer;
  grace_count integer;
  contact_pending_count integer;
  open_count integer;
begin
  -- A new check-in or disabled owner stops every unfinished release.
  update public.legacy_access_windows windows
  set
    state = 'revoked',
    claimed_at = null,
    updated_at = p_now,
    notice_last_error = coalesce(
      windows.notice_last_error,
      'Eligibility changed before access completed.'
    )
  where windows.state in (
      'owner_notice_pending',
      'owner_notice_sending',
      'owner_grace_period',
      'pending',
      'sending',
      'open'
    )
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

  -- Recover either email stage if a worker stopped while sending.
  update public.legacy_access_windows
  set
    state = 'owner_notice_pending',
    claimed_at = null,
    updated_at = p_now,
    owner_notice_last_error =
      'The previous owner warning attempt did not finish and will be retried.'
  where state = 'owner_notice_sending'
    and claimed_at < p_now - interval '30 minutes';

  update public.legacy_access_windows
  set
    state = 'pending',
    claimed_at = null,
    updated_at = p_now,
    notice_last_error =
      'The previous contact email attempt did not finish and will be retried.'
  where state = 'sending'
    and claimed_at < p_now - interval '30 minutes';

  -- An uncancelled owner warning becomes contact-notice eligible after 24 hours.
  update public.legacy_access_windows windows
  set
    state = 'pending',
    claimed_at = null,
    notice_last_error = null,
    updated_at = p_now
  where windows.state = 'owner_grace_period'
    and windows.owner_cancelled_at is null
    and windows.owner_cancel_deadline <= p_now
    and exists (
      select 1
      from public.users users
      where users.id = windows.owner_user_id
        and users.legacy_access_enabled
        and public.legacy_latest_heartbeat(users.id) = windows.heartbeat_at
    );

  -- Cancellation is no longer possible after the grace stage ends.
  delete from public.legacy_release_cancel_tokens tokens
  using public.legacy_access_windows windows
  where windows.id = tokens.window_id
    and windows.state not in ('owner_notice_sending', 'owner_grace_period');

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
      lower(btrim(contacts.email)) as notice_email,
      lower(btrim(auth_users.email)) as owner_notice_email
    from public.users users
    join auth.users auth_users on auth_users.id = users.id
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
    owner_notice_email,
    state,
    created_at,
    updated_at
  )
  select
    snapshots.owner_user_id,
    snapshots.heartbeat_at,
    snapshots.primary_contact_id,
    snapshots.notice_email,
    snapshots.owner_notice_email,
    'owner_notice_pending',
    p_now,
    p_now
  from snapshots
  where snapshots.no_heartbeat_days >= 90
  on conflict (owner_user_id, heartbeat_at) do nothing;

  -- Follow the current account email until the warning is sent.
  update public.legacy_access_windows windows
  set
    owner_notice_email = lower(btrim(auth_users.email)),
    owner_notice_last_error = case
      when auth_users.email is null or btrim(auth_users.email) = ''
        then 'The account owner email is missing.'
      else null
    end,
    updated_at = p_now
  from auth.users auth_users
  where auth_users.id = windows.owner_user_id
    and windows.state = 'owner_notice_pending';

  -- Follow the current primary contact until the contact email is delivered.
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
    where windows.state in (
      'owner_notice_pending',
      'owner_grace_period',
      'pending'
    )
  )
  update public.legacy_access_windows windows
  set
    primary_contact_id = current_contacts.primary_contact_id,
    notice_email = current_contacts.notice_email,
    notice_last_error = case
      when windows.state <> 'pending' then windows.notice_last_error
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
        then 'owner_notice_pending'
      when current_windows.state in (
        'owner_notice_pending',
        'owner_notice_sending'
      ) then 'owner_notice_pending'
      when current_windows.state = 'owner_grace_period'
        then 'owner_grace_period'
      when current_windows.state in ('pending', 'sending')
        then 'notice_pending'
      when current_windows.state = 'open' then 'window_open'
      when current_windows.state = 'expired' then 'window_expired'
      when current_windows.state = 'revoked' then 'revoked'
      else 'owner_notice_pending'
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

  select count(*) into owner_pending_count
  from public.legacy_access_windows
  where state = 'owner_notice_pending';

  select count(*) into grace_count
  from public.legacy_access_windows
  where state = 'owner_grace_period';

  select count(*) into contact_pending_count
  from public.legacy_access_windows
  where state = 'pending';

  select count(*) into open_count
  from public.legacy_access_windows
  where state = 'open';

  return jsonb_build_object(
    'processed', processed_count,
    'ownerWarningsPending', owner_pending_count,
    'ownerGracePeriods', grace_count,
    'contactNoticesPending', contact_pending_count,
    'openWindows', open_count,
    'refreshedAt', p_now
  );
end;
$$;

revoke all on function public.refresh_legacy_heartbeat_status(timestamptz)
from public;
grant execute on function public.refresh_legacy_heartbeat_status(timestamptz)
to service_role;

create or replace function public.claim_legacy_owner_notice_candidates(
  p_limit integer default 25,
  p_now timestamptz default now()
)
returns table (
  window_id uuid,
  owner_user_id uuid,
  owner_name text,
  owner_email text,
  heartbeat_at timestamptz,
  no_heartbeat_days integer,
  cancel_token text,
  cancel_deadline timestamptz
)
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  return query
  with candidates as (
    select
      windows.id,
      lower(btrim(auth_users.email)) as owner_email,
      encode(extensions.gen_random_bytes(32), 'hex') as raw_cancel_token
    from public.legacy_access_windows windows
    join public.users users on users.id = windows.owner_user_id
    join auth.users auth_users on auth_users.id = windows.owner_user_id
    where windows.state = 'owner_notice_pending'
      and users.legacy_access_enabled
      and public.legacy_latest_heartbeat(users.id) = windows.heartbeat_at
      and auth_users.email is not null
      and btrim(auth_users.email) <> ''
    order by windows.created_at
    limit greatest(1, least(p_limit, 100))
    for update of windows skip locked
  ), saved_tokens as (
    insert into public.legacy_release_cancel_tokens (
      window_id,
      token_hash,
      expires_at,
      created_at
    )
    select
      candidates.id,
      encode(
        extensions.digest(candidates.raw_cancel_token, 'sha256'),
        'hex'
      ),
      p_now + interval '1 day',
      p_now
    from candidates
    on conflict (window_id) do update set
      token_hash = excluded.token_hash,
      expires_at = excluded.expires_at,
      created_at = excluded.created_at
    returning legacy_release_cancel_tokens.window_id
  ), claimed as (
    update public.legacy_access_windows windows
    set
      state = 'owner_notice_sending',
      owner_notice_email = candidates.owner_email,
      owner_cancel_deadline = p_now + interval '1 day',
      claimed_at = p_now,
      owner_notice_attempt_count = windows.owner_notice_attempt_count + 1,
      owner_notice_last_error = null,
      updated_at = p_now
    from candidates
    join saved_tokens on saved_tokens.window_id = candidates.id
    where windows.id = candidates.id
    returning windows.*, candidates.raw_cancel_token
  )
  select
    claimed.id,
    claimed.owner_user_id,
    users.name,
    claimed.owner_notice_email,
    claimed.heartbeat_at,
    greatest(
      0,
      floor(extract(epoch from (p_now - claimed.heartbeat_at)) / 86400)::integer
    ),
    claimed.raw_cancel_token,
    claimed.owner_cancel_deadline
  from claimed
  join public.users users on users.id = claimed.owner_user_id;
end;
$$;

revoke all on function public.claim_legacy_owner_notice_candidates(
  integer,
  timestamptz
) from public;
grant execute on function public.claim_legacy_owner_notice_candidates(
  integer,
  timestamptz
) to service_role;

create or replace function public.complete_legacy_owner_notice(
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

  if not found or target.state <> 'owner_notice_sending' then
    return false;
  end if;

  if not p_success then
    update public.legacy_access_windows
    set
      state = 'owner_notice_pending',
      owner_cancel_deadline = null,
      claimed_at = null,
      owner_notice_last_error = left(
        coalesce(p_error, 'Owner warning email delivery failed.'),
        1000
      ),
      updated_at = p_now
    where id = p_window_id;

    delete from public.legacy_release_cancel_tokens
    where window_id = p_window_id;
    return false;
  end if;

  select exists (
    select 1
    from public.users users
    join auth.users auth_users on auth_users.id = users.id
    where users.id = target.owner_user_id
      and users.legacy_access_enabled
      and public.legacy_latest_heartbeat(users.id) = target.heartbeat_at
      and lower(btrim(auth_users.email)) =
        lower(btrim(target.owner_notice_email))
  ) into still_eligible;

  if not still_eligible then
    update public.legacy_access_windows
    set
      state = 'revoked',
      claimed_at = null,
      owner_notice_last_error =
        'Eligibility changed while the owner warning was being sent.',
      updated_at = p_now
    where id = p_window_id;
    return false;
  end if;

  update public.legacy_access_windows
  set
    state = 'owner_grace_period',
    owner_notice_sent_at = p_now,
    owner_cancel_deadline = p_now + interval '1 day',
    claimed_at = null,
    owner_notice_last_error = null,
    updated_at = p_now
  where id = p_window_id;

  update public.legacy_release_cancel_tokens
  set expires_at = p_now + interval '1 day'
  where window_id = p_window_id;

  update public.legacy_heartbeat_status
  set
    state = 'owner_grace_period',
    access_window_id = p_window_id,
    updated_at = p_now
  where owner_user_id = target.owner_user_id
    and last_heartbeat_at = target.heartbeat_at;

  return true;
end;
$$;

revoke all on function public.complete_legacy_owner_notice(
  uuid,
  boolean,
  text,
  timestamptz
) from public;
grant execute on function public.complete_legacy_owner_notice(
  uuid,
  boolean,
  text,
  timestamptz
) to service_role;

create or replace function public.cancel_legacy_release_with_token(
  p_window_id uuid,
  p_token text,
  p_now timestamptz default now()
)
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  target_owner_user_id uuid;
  target_heartbeat_at timestamptz;
  target_state text;
  target_cancel_deadline timestamptz;
  stored_hash text;
  token_expires_at timestamptz;
begin
  if p_token is null or p_token !~ '^[0-9a-f]{64}$' then
    return 'invalid';
  end if;

  select
    windows.owner_user_id,
    windows.heartbeat_at,
    windows.state,
    windows.owner_cancel_deadline,
    tokens.token_hash,
    tokens.expires_at
  into
    target_owner_user_id,
    target_heartbeat_at,
    target_state,
    target_cancel_deadline,
    stored_hash,
    token_expires_at
  from public.legacy_access_windows windows
  join public.legacy_release_cancel_tokens tokens
    on tokens.window_id = windows.id
  where windows.id = p_window_id
  for update of windows, tokens;

  if not found then
    return 'invalid';
  end if;

  if stored_hash <> encode(extensions.digest(p_token, 'sha256'), 'hex') then
    return 'invalid';
  end if;

  if token_expires_at <= p_now
     or target_cancel_deadline <= p_now
     or target_state not in ('owner_notice_sending', 'owner_grace_period') then
    return 'expired';
  end if;

  update public.legacy_access_windows
  set
    state = 'revoked',
    owner_cancelled_at = p_now,
    claimed_at = null,
    owner_notice_last_error = 'The account owner cancelled the Legacy release.',
    updated_at = p_now
  where id = p_window_id;

  delete from public.legacy_release_cancel_tokens
  where window_id = p_window_id;

  update public.legacy_heartbeat_status
  set
    state = 'revoked',
    access_window_id = p_window_id,
    updated_at = p_now
  where owner_user_id = target_owner_user_id
    and last_heartbeat_at = target_heartbeat_at;

  return 'cancelled';
end;
$$;

revoke all on function public.cancel_legacy_release_with_token(
  uuid,
  text,
  timestamptz
) from public;
grant execute on function public.cancel_legacy_release_with_token(
  uuid,
  text,
  timestamptz
) to service_role;

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
      and target.owner_cancelled_at is null
      and target.owner_notice_sent_at is not null
      and target.owner_cancel_deadline <= p_now
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
      and state in (
        'owner_notice_pending',
        'owner_notice_sending',
        'owner_grace_period',
        'pending',
        'sending',
        'open'
      );
  end if;
end;
$$;

revoke all on function public.set_legacy_access_enabled(boolean) from public;
grant execute on function public.set_legacy_access_enabled(boolean)
to authenticated;

notify pgrst, 'reload schema';
