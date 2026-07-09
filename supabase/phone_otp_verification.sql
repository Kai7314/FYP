-- Run this in Supabase Dashboard > SQL Editor to enable SMS OTP verification
-- for profile phone numbers and trusted contact phone numbers.

create table if not exists public.phone_verification_otps (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  purpose text not null check (purpose in ('user_phone', 'contact_phone')),
  phone text not null,
  code_hash text not null,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  attempt_count integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists phone_verification_otps_lookup_idx
on public.phone_verification_otps(user_id, purpose, phone, created_at desc);

create table if not exists public.phone_verifications (
  user_id uuid not null references auth.users(id) on delete cascade,
  purpose text not null check (purpose in ('user_phone', 'contact_phone')),
  phone text not null,
  verified_at timestamptz not null default now(),
  primary key (user_id, purpose, phone)
);

alter table public.phone_verification_otps enable row level security;
alter table public.phone_verifications enable row level security;

drop policy if exists "phone_verifications_select_own" on public.phone_verifications;
create policy "phone_verifications_select_own"
on public.phone_verifications for select
to authenticated
using ((select auth.uid()) = user_id);

alter table public.users
  add column if not exists phone_verified_at timestamptz;

alter table public.contacts
  add column if not exists phone_verified_at timestamptz;

create or replace function public.etherna_normalized_phone(value text)
returns text
language sql
immutable
as $$
  select case
    when value is null or btrim(value) = '' then ''
    when left(btrim(value), 1) = '+'
      then '+' || regexp_replace(value, '[^0-9]', '', 'g')
    else regexp_replace(value, '[^0-9]', '', 'g')
  end;
$$;

create or replace function public.enforce_user_phone_verified()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_new text;
  normalized_old text;
  verified_time timestamptz;
begin
  normalized_new := public.etherna_normalized_phone(new.phone);

  if normalized_new = '' then
    new.phone_verified_at := null;
    return new;
  end if;

  if TG_OP = 'UPDATE' then
    normalized_old := public.etherna_normalized_phone(old.phone);
    if normalized_new = normalized_old then
      new.phone_verified_at := old.phone_verified_at;
      return new;
    end if;
  end if;

  select verified_at
    into verified_time
  from public.phone_verifications
  where user_id = new.id
    and purpose = 'user_phone'
    and phone = normalized_new
    and verified_at > now() - interval '180 days'
  order by verified_at desc
  limit 1;

  if verified_time is null then
    raise exception 'Verify your phone number before saving profile';
  end if;

  new.phone_verified_at := verified_time;
  return new;
end;
$$;

drop trigger if exists users_phone_verified_before_write on public.users;
create trigger users_phone_verified_before_write
before insert or update of phone on public.users
for each row execute function public.enforce_user_phone_verified();

create or replace function public.enforce_contact_phone_verified()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_new text;
  normalized_old text;
  verified_time timestamptz;
begin
  normalized_new := public.etherna_normalized_phone(new.phone);

  if normalized_new = '' then
    raise exception 'Contact phone is required';
  end if;

  if TG_OP = 'UPDATE' then
    normalized_old := public.etherna_normalized_phone(old.phone);
    if normalized_new = normalized_old then
      new.phone_verified_at := old.phone_verified_at;
      return new;
    end if;
  end if;

  select verified_at
    into verified_time
  from public.phone_verifications
  where user_id = new.user_id
    and purpose = 'contact_phone'
    and phone = normalized_new
    and verified_at > now() - interval '180 days'
  order by verified_at desc
  limit 1;

  if verified_time is null then
    raise exception 'Verify this contact phone number before saving contact';
  end if;

  new.phone_verified_at := verified_time;
  return new;
end;
$$;

drop trigger if exists contacts_phone_verified_before_write on public.contacts;
create trigger contacts_phone_verified_before_write
before insert or update of phone on public.contacts
for each row execute function public.enforce_contact_phone_verified();

select
  table_name,
  column_name,
  data_type
from information_schema.columns
where table_schema = 'public'
  and (
    (table_name in ('users', 'contacts') and column_name = 'phone_verified_at')
    or table_name in ('phone_verification_otps', 'phone_verifications')
  )
order by table_name, ordinal_position;
