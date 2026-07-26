-- Run once in Supabase Dashboard > SQL Editor when migrations are unavailable.
-- Active EthernaCare rewards are automatic virtual badges and vouchers.

create table if not exists public.reward_catalog (
  code text primary key,
  title text not null,
  sponsor text not null,
  description text not null default '',
  milestone_days integer not null check (milestone_days > 0),
  reward_kind text not null default 'virtual',
  voucher_value text,
  catalog_version integer not null default 1,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.reward_catalog
  drop constraint if exists reward_catalog_reward_kind_check;

alter table public.reward_catalog
  add constraint reward_catalog_reward_kind_check
  check (reward_kind in ('physical', 'voucher', 'virtual'));

alter table public.rewards
  add column if not exists reward_code text
    references public.reward_catalog(code);
alter table public.rewards
  add column if not exists status text not null default 'earned'
    check (status in ('earned', 'claimed', 'redeemed', 'expired'));
alter table public.rewards
  add column if not exists earned_at timestamptz not null default now();
alter table public.rewards
  add column if not exists redeemed_at timestamptz;
alter table public.rewards
  add column if not exists claimed_at timestamptz;

create unique index if not exists rewards_user_reward_code_unique
on public.rewards (user_id, reward_code)
where reward_code is not null;

update public.reward_catalog
set
  active = false,
  updated_at = now()
where active;

insert into public.reward_catalog (
  code,
  title,
  sponsor,
  description,
  milestone_days,
  reward_kind,
  voucher_value,
  catalog_version,
  active
)
values
  (
    'oren_sprout_badge',
    'Oren Sprout Badge',
    'EthernaCare',
    'A fresh start badge for building your check-in habit.',
    3,
    'virtual',
    null,
    2,
    true
  ),
  (
    'oren_companion_badge',
    'Caring Companion Badge',
    'EthernaCare',
    'A virtual badge celebrating one week with Oren.',
    7,
    'virtual',
    null,
    2,
    true
  ),
  (
    'oren_safety_star_badge',
    'Safety Star Badge',
    'EthernaCare',
    'A virtual star for ten consistent safety check-ins.',
    10,
    'virtual',
    null,
    2,
    true
  ),
  (
    'oren_guardian_badge',
    'Trusted Guardian Badge',
    'EthernaCare',
    'A virtual badge for two dependable check-in weeks.',
    14,
    'virtual',
    null,
    2,
    true
  ),
  (
    'oren_golden_badge',
    'Golden Oren Badge',
    'EthernaCare',
    'The highest virtual badge for a 30-day check-in streak.',
    30,
    'virtual',
    null,
    2,
    true
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
using (active = true);

grant select on public.reward_catalog to authenticated;

-- Clients compare catalog_version with their local cache and refresh when it
-- increases. New virtual rewards should use a later version.

create or replace function public.claim_current_user_badge(
  p_reward_code text
)
returns table (
  reward_code text,
  status text,
  claimed_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  normalized_code text := btrim(p_reward_code);
begin
  if current_user_id is null then
    raise exception 'You must be signed in';
  end if;

  if normalized_code is null or normalized_code = '' then
    raise exception 'Select a badge to collect';
  end if;

  perform *
  from public.sync_current_user_rewards();

  return query
  update public.rewards earned
  set
    status = 'claimed',
    claimed_at = coalesce(earned.claimed_at, now())
  from public.reward_catalog catalog
  where earned.user_id = current_user_id
    and earned.reward_code = normalized_code
    and earned.status in ('earned', 'claimed')
    and catalog.code = earned.reward_code
    and catalog.reward_kind = 'virtual'
  returning
    earned.reward_code,
    earned.status,
    earned.claimed_at;

  if not found then
    if exists (
      select 1
      from public.reward_catalog catalog
      where catalog.code = normalized_code
        and catalog.reward_kind = 'voucher'
    ) then
      raise exception 'Vouchers do not belong in the badge list';
    end if;

    raise exception
      'This badge is not available yet. Complete its check-in goal first';
  end if;
end;
$$;

revoke all on function public.claim_current_user_badge(text)
from public, anon, authenticated;
grant execute on function public.claim_current_user_badge(text)
to authenticated;

notify pgrst, 'reload schema';
