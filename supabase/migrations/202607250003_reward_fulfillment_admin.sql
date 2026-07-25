-- Reward fulfillment workflow:
-- 1. The server validates streak-based reward eligibility.
-- 2. Users can submit one request for each earned reward.
-- 3. Only fixed accounts in reward_admins can review fulfillment requests.

create table if not exists public.reward_catalog (
  code text primary key,
  title text not null,
  sponsor text not null,
  description text not null default '',
  milestone_days integer not null check (milestone_days > 0),
  reward_kind text not null default 'physical'
    check (reward_kind in ('physical', 'voucher')),
  voucher_value text,
  catalog_version integer not null default 1,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.reward_catalog (
  code,
  title,
  sponsor,
  description,
  milestone_days,
  reward_kind,
  voucher_value,
  catalog_version
)
values
  (
    'tealive_bogo',
    'Tealive Buy 1 Free 1',
    'Tealive',
    'A virtual buy-one-free-one beverage voucher.',
    3,
    'voucher',
    'Buy 1 Free 1',
    1
  ),
  (
    'milo_400g',
    'Milo Chocolate Drink',
    'Nestle',
    'One Milo 400g tin.',
    7,
    'physical',
    null,
    1
  ),
  (
    'shopee_rm5',
    'Shopee RM5 Voucher',
    'Shopee',
    'A virtual RM5 shopping voucher.',
    10,
    'voucher',
    'RM5',
    1
  ),
  (
    'tissue_bundle',
    'Premium Tissue Bundle',
    'Kleenex',
    'Three premium soft tissue boxes.',
    14,
    'physical',
    null,
    1
  ),
  (
    'green_tea',
    'Green Tea Collection',
    'TWG Tea',
    'A calming premium tea collection.',
    30,
    'physical',
    null,
    1
  )
on conflict (code) do update set
  title = excluded.title,
  sponsor = excluded.sponsor,
  description = excluded.description,
  milestone_days = excluded.milestone_days,
  reward_kind = excluded.reward_kind,
  voucher_value = excluded.voucher_value,
  catalog_version = excluded.catalog_version,
  active = true,
  updated_at = now();

alter table public.reward_catalog enable row level security;

drop policy if exists "reward_catalog_read_active" on public.reward_catalog;
create policy "reward_catalog_read_active"
on public.reward_catalog for select
to authenticated
using (active);

grant select on public.reward_catalog to authenticated;

alter table public.rewards
  add column if not exists reward_code text,
  add column if not exists status text not null default 'earned',
  add column if not exists earned_at timestamptz not null default now(),
  add column if not exists redeemed_at timestamptz;

create unique index if not exists rewards_user_reward_code_unique
on public.rewards(user_id, reward_code)
where reward_code is not null;

create table if not exists public.reward_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  label text not null default 'Reward administrator'
    check (char_length(btrim(label)) between 2 and 80),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null
);

alter table public.reward_admins enable row level security;
revoke all on public.reward_admins from anon, authenticated;

create table if not exists public.reward_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  reward_code text not null references public.reward_catalog(code),
  reward_title text not null check (char_length(btrim(reward_title)) between 2 and 120),
  reward_sponsor text not null check (char_length(btrim(reward_sponsor)) between 2 and 120),
  reward_kind text not null check (reward_kind in ('physical', 'voucher')),
  recipient_name text not null
    check (char_length(btrim(recipient_name)) between 2 and 80),
  contact_phone text not null
    check (contact_phone ~ '^\+[0-9]{8,15}$'),
  delivery_address text not null
    check (char_length(btrim(delivery_address)) between 2 and 200),
  delivery_state text not null
    check (char_length(btrim(delivery_state)) between 2 and 80),
  delivery_region text not null
    check (char_length(btrim(delivery_region)) between 2 and 100),
  status text not null default 'pending'
    check (status in ('pending', 'preparing', 'shipped', 'delivered', 'rejected')),
  requested_at timestamptz not null default now(),
  status_updated_at timestamptz not null default now(),
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  fulfilled_at timestamptz,
  tracking_reference text
    check (
      tracking_reference is null
      or char_length(btrim(tracking_reference)) between 2 and 120
    ),
  admin_notes text
    check (
      admin_notes is null
      or char_length(btrim(admin_notes)) <= 500
    ),
  unique (user_id, reward_code)
);

create index if not exists reward_requests_user_requested_idx
on public.reward_requests(user_id, requested_at desc);

create index if not exists reward_requests_status_requested_idx
on public.reward_requests(status, requested_at desc);

alter table public.reward_requests enable row level security;

revoke all on public.reward_requests from anon, authenticated;
grant select on public.reward_requests to authenticated;

create or replace function public.is_current_user_reward_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.reward_admins admins
    where admins.user_id = auth.uid()
      and admins.active
  );
$$;

revoke all on function public.is_current_user_reward_admin() from public;
grant execute on function public.is_current_user_reward_admin()
to authenticated;

drop policy if exists "reward_requests_select_own_or_admin"
on public.reward_requests;
create policy "reward_requests_select_own_or_admin"
on public.reward_requests for select
to authenticated
using (
  (select auth.uid()) = user_id
  or public.is_current_user_reward_admin()
);

create or replace function public.set_reward_admin_by_email(
  p_email text,
  p_label text default 'Reward administrator',
  p_active boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  target_user_id uuid;
begin
  select users.id
    into target_user_id
  from auth.users users
  where lower(users.email) = lower(btrim(p_email))
  limit 1;

  if target_user_id is null then
    raise exception 'No Supabase Auth user exists for this admin email';
  end if;

  insert into public.reward_admins (
    user_id,
    label,
    active,
    created_by
  )
  values (
    target_user_id,
    btrim(p_label),
    p_active,
    auth.uid()
  )
  on conflict (user_id) do update set
    label = excluded.label,
    active = excluded.active;

  return target_user_id;
end;
$$;

revoke all on function public.set_reward_admin_by_email(
  text,
  text,
  boolean
) from public, anon, authenticated;
grant execute on function public.set_reward_admin_by_email(
  text,
  text,
  boolean
) to service_role;

create or replace function public.current_checkin_streak(
  p_user_id uuid,
  p_now timestamptz default now()
)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  cursor_day date;
  streak integer := 0;
begin
  cursor_day := (p_now at time zone 'Asia/Kuala_Lumpur')::date;

  if not exists (
    select 1
    from public.checkins checkins
    where checkins.user_id = p_user_id
      and (checkins.checkin_time at time zone 'Asia/Kuala_Lumpur')::date =
        cursor_day
  ) then
    cursor_day := cursor_day - 1;
  end if;

  loop
    exit when not exists (
      select 1
      from public.checkins checkins
      where checkins.user_id = p_user_id
        and (checkins.checkin_time at time zone 'Asia/Kuala_Lumpur')::date =
          cursor_day
    );

    streak := streak + 1;
    cursor_day := cursor_day - 1;
  end loop;

  return streak;
end;
$$;

revoke all on function public.current_checkin_streak(
  uuid,
  timestamptz
) from public, anon, authenticated;

create or replace function public.sync_current_user_rewards()
returns table (
  current_streak integer,
  newly_earned integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  streak_value integer;
  inserted_count integer;
begin
  if current_user_id is null then
    raise exception 'You must be signed in';
  end if;

  streak_value := public.current_checkin_streak(current_user_id, now());

  insert into public.rewards (
    user_id,
    streak_days,
    reward_type,
    reward_code,
    status,
    earned_at
  )
  select
    current_user_id,
    catalog.milestone_days,
    catalog.title,
    catalog.code,
    'earned',
    now()
  from public.reward_catalog catalog
  where catalog.active
    and catalog.milestone_days <= streak_value
  on conflict (user_id, reward_code)
    where reward_code is not null
  do nothing;

  get diagnostics inserted_count = row_count;

  return query
  select streak_value, inserted_count;
end;
$$;

revoke all on function public.sync_current_user_rewards() from public;
grant execute on function public.sync_current_user_rewards()
to authenticated;

create or replace function public.request_current_user_reward(
  p_reward_code text,
  p_recipient_name text,
  p_contact_phone text,
  p_delivery_address text,
  p_delivery_state text,
  p_delivery_region text
)
returns setof public.reward_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  catalog_item public.reward_catalog%rowtype;
begin
  if current_user_id is null then
    raise exception 'You must be signed in';
  end if;

  select catalog.*
    into catalog_item
  from public.reward_catalog catalog
  where catalog.code = btrim(p_reward_code)
    and catalog.active;

  if catalog_item.code is null then
    raise exception 'This reward is not available';
  end if;

  if char_length(btrim(p_recipient_name)) not between 2 and 80 then
    raise exception 'Recipient name must contain 2 to 80 characters';
  end if;

  if btrim(p_contact_phone) !~ '^\+[0-9]{8,15}$' then
    raise exception 'Enter a valid delivery phone number with country code';
  end if;

  if char_length(btrim(p_delivery_address)) not between 2 and 200
     or char_length(btrim(p_delivery_state)) not between 2 and 80
     or char_length(btrim(p_delivery_region)) not between 2 and 100 then
    raise exception 'A complete delivery address is required';
  end if;

  perform public.sync_current_user_rewards();

  if not exists (
    select 1
    from public.rewards rewards
    where rewards.user_id = current_user_id
      and rewards.reward_code = catalog_item.code
      and rewards.status in ('earned', 'claimed')
  ) then
    raise exception 'Complete the reward goal before requesting this item';
  end if;

  if exists (
    select 1
    from public.reward_requests requests
    where requests.user_id = current_user_id
      and requests.reward_code = catalog_item.code
  ) then
    raise exception 'This reward has already been requested';
  end if;

  update public.rewards rewards
  set
    status = 'claimed',
    redeemed_at = null
  where rewards.user_id = current_user_id
    and rewards.reward_code = catalog_item.code;

  return query
  insert into public.reward_requests (
    user_id,
    reward_code,
    reward_title,
    reward_sponsor,
    reward_kind,
    recipient_name,
    contact_phone,
    delivery_address,
    delivery_state,
    delivery_region
  )
  values (
    current_user_id,
    catalog_item.code,
    catalog_item.title,
    catalog_item.sponsor,
    catalog_item.reward_kind,
    btrim(p_recipient_name),
    btrim(p_contact_phone),
    btrim(p_delivery_address),
    btrim(p_delivery_state),
    btrim(p_delivery_region)
  )
  returning *;
end;
$$;

revoke all on function public.request_current_user_reward(
  text,
  text,
  text,
  text,
  text,
  text
) from public;
grant execute on function public.request_current_user_reward(
  text,
  text,
  text,
  text,
  text,
  text
) to authenticated;

create or replace function public.list_reward_requests_admin()
returns table (
  id uuid,
  user_id uuid,
  user_name text,
  user_email text,
  reward_code text,
  reward_title text,
  reward_sponsor text,
  reward_kind text,
  recipient_name text,
  contact_phone text,
  delivery_address text,
  delivery_state text,
  delivery_region text,
  status text,
  requested_at timestamptz,
  status_updated_at timestamptz,
  reviewed_by uuid,
  reviewed_at timestamptz,
  fulfilled_at timestamptz,
  tracking_reference text,
  admin_notes text
)
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.is_current_user_reward_admin() then
    raise exception 'Reward administrator access is required';
  end if;

  return query
  select
    requests.id,
    requests.user_id,
    coalesce(profiles.name, 'EthernaCare User'),
    auth_users.email::text,
    requests.reward_code,
    requests.reward_title,
    requests.reward_sponsor,
    requests.reward_kind,
    requests.recipient_name,
    requests.contact_phone,
    requests.delivery_address,
    requests.delivery_state,
    requests.delivery_region,
    requests.status,
    requests.requested_at,
    requests.status_updated_at,
    requests.reviewed_by,
    requests.reviewed_at,
    requests.fulfilled_at,
    requests.tracking_reference,
    requests.admin_notes
  from public.reward_requests requests
  left join public.users profiles on profiles.id = requests.user_id
  left join auth.users auth_users on auth_users.id = requests.user_id
  order by requests.requested_at desc;
end;
$$;

revoke all on function public.list_reward_requests_admin() from public;
grant execute on function public.list_reward_requests_admin()
to authenticated;

create or replace function public.update_reward_request_admin(
  p_request_id uuid,
  p_status text,
  p_tracking_reference text default null,
  p_admin_notes text default null
)
returns setof public.reward_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  current_admin_id uuid := auth.uid();
  request_user_id uuid;
  request_reward_code text;
begin
  if not public.is_current_user_reward_admin() then
    raise exception 'Reward administrator access is required';
  end if;

  if p_status not in ('pending', 'preparing', 'shipped', 'delivered', 'rejected') then
    raise exception 'Invalid fulfillment status';
  end if;

  if p_tracking_reference is not null
     and char_length(btrim(p_tracking_reference)) not between 2 and 120 then
    raise exception 'Tracking reference must contain 2 to 120 characters';
  end if;

  if p_admin_notes is not null
     and char_length(btrim(p_admin_notes)) > 500 then
    raise exception 'Admin notes must not exceed 500 characters';
  end if;

  select requests.user_id, requests.reward_code
    into request_user_id, request_reward_code
  from public.reward_requests requests
  where requests.id = p_request_id
  for update;

  if request_user_id is null then
    raise exception 'Reward request was not found';
  end if;

  update public.rewards rewards
  set
    status = case
      when p_status = 'delivered' then 'redeemed'
      when p_status = 'rejected' then 'expired'
      else 'claimed'
    end,
    redeemed_at = case
      when p_status = 'delivered' then now()
      else null
    end
  where rewards.user_id = request_user_id
    and rewards.reward_code = request_reward_code;

  return query
  update public.reward_requests requests
  set
    status = p_status,
    status_updated_at = now(),
    reviewed_by = current_admin_id,
    reviewed_at = coalesce(requests.reviewed_at, now()),
    fulfilled_at = case
      when p_status = 'delivered' then coalesce(requests.fulfilled_at, now())
      else null
    end,
    tracking_reference = nullif(btrim(p_tracking_reference), ''),
    admin_notes = nullif(btrim(p_admin_notes), '')
  where requests.id = p_request_id
  returning requests.*;
end;
$$;

revoke all on function public.update_reward_request_admin(
  uuid,
  text,
  text,
  text
) from public;
grant execute on function public.update_reward_request_admin(
  uuid,
  text,
  text,
  text
) to authenticated;

-- Reward ownership is now granted only by sync_current_user_rewards().
drop policy if exists "rewards_insert_own" on public.rewards;
drop policy if exists "rewards_update_own" on public.rewards;
revoke insert, update, delete on public.rewards from authenticated;

notify pgrst, 'reload schema';
