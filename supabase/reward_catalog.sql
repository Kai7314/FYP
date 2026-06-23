-- Run once in Supabase Dashboard > SQL Editor.
-- Supabase remains authoritative; Flutter caches these rows for fast/offline UI.

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

create unique index if not exists rewards_user_reward_code_unique
on public.rewards (user_id, reward_code)
where reward_code is not null;

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
    'A virtual shopping voucher.',
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
using (active = true);

-- When introducing a new reward, give it a higher catalog_version.
-- Clients compare the newest server version with their cached version and
-- download the catalog only when the version increases.
