-- A separate administrator entry can manage virtual reward catalog records.
-- User reward ownership remains server-calculated from check-in streaks.

create table if not exists public.reward_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  label text not null default 'Reward administrator'
    check (char_length(btrim(label)) between 2 and 80),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null
);

alter table public.reward_admins enable row level security;
revoke all on table public.reward_admins from anon, authenticated;

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

revoke all on function public.is_current_user_reward_admin()
from public, anon, authenticated;
grant execute on function public.is_current_user_reward_admin()
to authenticated;

create or replace function public.list_virtual_rewards_admin()
returns table (
  code text,
  title text,
  sponsor text,
  description text,
  milestone_days integer,
  reward_kind text,
  voucher_value text,
  catalog_version integer,
  active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_current_user_reward_admin() then
    raise exception 'Reward administrator access is required';
  end if;

  return query
  select
    catalog.code,
    catalog.title,
    catalog.sponsor,
    catalog.description,
    catalog.milestone_days,
    catalog.reward_kind,
    catalog.voucher_value,
    catalog.catalog_version,
    catalog.active,
    catalog.created_at,
    catalog.updated_at
  from public.reward_catalog catalog
  where catalog.reward_kind = 'virtual'
  order by catalog.active desc, catalog.milestone_days, catalog.code;
end;
$$;

revoke all on function public.list_virtual_rewards_admin()
from public, anon, authenticated;
grant execute on function public.list_virtual_rewards_admin()
to authenticated;

create or replace function public.upsert_virtual_reward_admin(
  p_code text,
  p_title text,
  p_description text,
  p_milestone_days integer,
  p_active boolean default true
)
returns setof public.reward_catalog
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_code text := lower(btrim(p_code));
  normalized_title text := btrim(p_title);
  normalized_description text := btrim(p_description);
  next_version integer;
begin
  if not public.is_current_user_reward_admin() then
    raise exception 'Reward administrator access is required';
  end if;

  if normalized_code !~ '^[a-z][a-z0-9_]{2,49}$' then
    raise exception
      'Reward code must contain 3 to 50 lowercase letters, numbers, or underscores';
  end if;

  if char_length(normalized_title) not between 2 and 80 then
    raise exception 'Reward title must contain 2 to 80 characters';
  end if;

  if char_length(normalized_description) not between 5 and 240 then
    raise exception 'Reward description must contain 5 to 240 characters';
  end if;

  if p_milestone_days not between 1 and 365 then
    raise exception 'Reward milestone must be between 1 and 365 days';
  end if;

  perform pg_advisory_xact_lock(
    hashtext('etherna_virtual_reward_catalog_version')::bigint
  );

  select coalesce(max(catalog.catalog_version), 0) + 1
    into next_version
  from public.reward_catalog catalog;

  insert into public.reward_catalog (
    code,
    title,
    sponsor,
    description,
    milestone_days,
    reward_kind,
    voucher_value,
    catalog_version,
    active,
    updated_at
  )
  values (
    normalized_code,
    normalized_title,
    'EthernaCare',
    normalized_description,
    p_milestone_days,
    'virtual',
    null,
    next_version,
    coalesce(p_active, true),
    now()
  )
  on conflict (code) do update set
    title = excluded.title,
    sponsor = 'EthernaCare',
    description = excluded.description,
    milestone_days = excluded.milestone_days,
    reward_kind = 'virtual',
    voucher_value = null,
    catalog_version = excluded.catalog_version,
    active = excluded.active,
    updated_at = now();

  return query
  select catalog.*
  from public.reward_catalog catalog
  where catalog.code = normalized_code;
end;
$$;

revoke all on function public.upsert_virtual_reward_admin(
  text,
  text,
  text,
  integer,
  boolean
) from public, anon, authenticated;
grant execute on function public.upsert_virtual_reward_admin(
  text,
  text,
  text,
  integer,
  boolean
) to authenticated;

-- Catalog rows cannot be changed directly from the client.
revoke insert, update, delete on table public.reward_catalog
from anon, authenticated;

notify pgrst, 'reload schema';
