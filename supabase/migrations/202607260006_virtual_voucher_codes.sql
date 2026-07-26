-- Virtual rewards may be badges or vouchers. Each user receives a unique,
-- server-generated code when a voucher is earned.

alter table public.rewards
  add column if not exists redeem_code text;

create unique index if not exists rewards_redeem_code_unique
on public.rewards(redeem_code)
where redeem_code is not null;

create or replace function public.generate_reward_redeem_code()
returns text
language plpgsql
volatile
security definer
set search_path = public, extensions
as $$
declare
  candidate text;
begin
  loop
    candidate := 'EC-' ||
      upper(substr(encode(extensions.gen_random_bytes(8), 'hex'), 1, 8)) ||
      '-' ||
      upper(substr(encode(extensions.gen_random_bytes(8), 'hex'), 1, 8));

    exit when not exists (
      select 1
      from public.rewards rewards
      where rewards.redeem_code = candidate
    );
  end loop;

  return candidate;
end;
$$;

revoke all on function public.generate_reward_redeem_code()
from public, anon, authenticated;

update public.rewards rewards
set redeem_code = public.generate_reward_redeem_code()
from public.reward_catalog catalog
where catalog.code = rewards.reward_code
  and catalog.reward_kind = 'voucher'
  and rewards.redeem_code is null;

alter table public.rewards
  drop constraint if exists rewards_redeem_code_format_check;

alter table public.rewards
  add constraint rewards_redeem_code_format_check
  check (
    redeem_code is null
    or redeem_code ~ '^EC-[A-F0-9]{8}-[A-F0-9]{8}$'
  );

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
  where catalog.reward_kind in ('virtual', 'voucher')
  order by catalog.active desc, catalog.milestone_days, catalog.code;
end;
$$;

create or replace function public.upsert_virtual_reward_admin(
  p_code text,
  p_title text,
  p_description text,
  p_milestone_days integer,
  p_active boolean,
  p_reward_kind text,
  p_voucher_value text default null
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
  normalized_kind text := lower(btrim(p_reward_kind));
  normalized_voucher_value text := nullif(btrim(p_voucher_value), '');
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

  if normalized_kind not in ('virtual', 'voucher') then
    raise exception 'Reward type must be Badge or Voucher';
  end if;

  if normalized_kind = 'voucher'
     and (
       normalized_voucher_value is null
       or char_length(normalized_voucher_value) not between 2 and 80
     ) then
    raise exception 'Voucher value must contain 2 to 80 characters';
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
    normalized_kind,
    case
      when normalized_kind = 'voucher' then normalized_voucher_value
      else null
    end,
    next_version,
    coalesce(p_active, true),
    now()
  )
  on conflict (code) do update set
    title = excluded.title,
    sponsor = 'EthernaCare',
    description = excluded.description,
    milestone_days = excluded.milestone_days,
    reward_kind = excluded.reward_kind,
    voucher_value = excluded.voucher_value,
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
  boolean,
  text,
  text
) from public, anon, authenticated;
grant execute on function public.upsert_virtual_reward_admin(
  text,
  text,
  text,
  integer,
  boolean,
  text,
  text
) to authenticated;

create or replace function public.delete_virtual_rewards_admin(
  p_codes text[]
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_codes text[];
  deleted_count integer := 0;
begin
  if not public.is_current_user_reward_admin() then
    raise exception 'Reward administrator access is required';
  end if;

  select coalesce(
    array_agg(distinct lower(btrim(input_code))),
    array[]::text[]
  )
    into normalized_codes
  from unnest(coalesce(p_codes, array[]::text[])) input_code
  where input_code is not null
    and btrim(input_code) <> '';

  if cardinality(normalized_codes) = 0 then
    raise exception 'Select at least one virtual reward';
  end if;

  if exists (
    select 1
    from public.rewards earned
    where earned.reward_code = any(normalized_codes)
  ) then
    raise exception
      'One or more selected rewards have already been earned; deactivate them instead';
  end if;

  delete from public.reward_catalog catalog
  where catalog.code = any(normalized_codes)
    and catalog.reward_kind in ('virtual', 'voucher');

  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;

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
    earned_at,
    redeem_code
  )
  select
    current_user_id,
    catalog.milestone_days,
    catalog.title,
    catalog.code,
    'earned',
    now(),
    case
      when catalog.reward_kind = 'voucher'
        then public.generate_reward_redeem_code()
      else null
    end
  from public.reward_catalog catalog
  where catalog.active
    and catalog.reward_kind in ('virtual', 'voucher')
    and catalog.milestone_days <= streak_value
  on conflict (user_id, reward_code)
    where reward_code is not null
  do nothing;

  get diagnostics inserted_count = row_count;

  update public.rewards rewards
  set redeem_code = public.generate_reward_redeem_code()
  from public.reward_catalog catalog
  where rewards.user_id = current_user_id
    and catalog.code = rewards.reward_code
    and catalog.reward_kind = 'voucher'
    and rewards.redeem_code is null;

  return query
  select streak_value, inserted_count;
end;
$$;

revoke all on function public.sync_current_user_rewards()
from public, anon, authenticated;
grant execute on function public.sync_current_user_rewards()
to authenticated;

notify pgrst, 'reload schema';
