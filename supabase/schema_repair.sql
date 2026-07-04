-- Run in Supabase Dashboard > SQL Editor before app testing.
-- This is additive: it creates missing tables/columns used by the Flutter app.

create extension if not exists pgcrypto;

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default 'EthernaCare User',
  phone text,
  address text,
  address_state text,
  address_region text,
  blood_type text,
  inactivity_threshold integer not null default 24,
  emergency_escalation_target text not null default 'primary_contact',
  terms_version text,
  terms_accepted_at timestamptz,
  profile_completed_at timestamptz
);

alter table public.users
  add column if not exists name text not null default 'EthernaCare User',
  add column if not exists phone text,
  add column if not exists address text,
  add column if not exists address_state text,
  add column if not exists address_region text,
  add column if not exists blood_type text,
  add column if not exists inactivity_threshold integer not null default 24,
  add column if not exists emergency_escalation_target text not null default 'primary_contact',
  add column if not exists terms_version text,
  add column if not exists terms_accepted_at timestamptz,
  add column if not exists profile_completed_at timestamptz;

update public.users
set emergency_escalation_target = 'primary_contact'
where emergency_escalation_target = 'trusted_contacts';

create table if not exists public.checkins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  checkin_time timestamptz not null default now(),
  status text not null default 'active'
);

alter table public.checkins
  add column if not exists user_id uuid references auth.users(id) on delete cascade,
  add column if not exists checkin_time timestamptz not null default now(),
  add column if not exists status text not null default 'active';

create table if not exists public.contacts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  relationship text not null default 'Trusted contact',
  phone text not null,
  address text not null default '',
  is_primary boolean not null default false
);

alter table public.contacts
  add column if not exists user_id uuid references auth.users(id) on delete cascade,
  add column if not exists name text,
  add column if not exists relationship text not null default 'Trusted contact',
  add column if not exists phone text,
  add column if not exists address text not null default '',
  add column if not exists is_primary boolean not null default false;

create table if not exists public.rewards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  streak_days integer not null default 0,
  reward_type text not null default '',
  reward_code text,
  status text not null default 'earned',
  earned_at timestamptz not null default now(),
  redeemed_at timestamptz
);

alter table public.rewards
  add column if not exists user_id uuid references auth.users(id) on delete cascade,
  add column if not exists streak_days integer not null default 0,
  add column if not exists reward_type text not null default '',
  add column if not exists reward_code text,
  add column if not exists status text not null default 'earned',
  add column if not exists earned_at timestamptz not null default now(),
  add column if not exists redeemed_at timestamptz;

create table if not exists public.emergency_alerts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  triggered_time timestamptz not null default now(),
  status text not null default 'triggered'
);

alter table public.emergency_alerts
  add column if not exists user_id uuid references auth.users(id) on delete cascade,
  add column if not exists triggered_time timestamptz not null default now(),
  add column if not exists status text not null default 'triggered';

create table if not exists public.locations (
  id uuid primary key default gen_random_uuid(),
  alert_id text not null,
  latitude double precision not null,
  longitude double precision not null,
  timestamp timestamptz not null default now()
);

alter table public.locations
  add column if not exists alert_id text,
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists timestamp timestamptz not null default now();

create index if not exists checkins_user_time_idx
on public.checkins(user_id, checkin_time desc);

create index if not exists contacts_user_idx
on public.contacts(user_id);

create unique index if not exists contacts_one_primary_per_user
on public.contacts(user_id)
where is_primary;

create index if not exists rewards_user_idx
on public.rewards(user_id);

create index if not exists alerts_user_time_idx
on public.emergency_alerts(user_id, triggered_time desc);

create index if not exists locations_alert_idx
on public.locations(alert_id);
