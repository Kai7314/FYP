-- Run once in Supabase Dashboard > SQL Editor.
-- These rules mirror Flutter validation and protect writes from other clients.

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default 'EthernaCare User'
);

alter table public.users
  add column if not exists name text not null default 'EthernaCare User',
  add column if not exists phone text,
  add column if not exists address text,
  add column if not exists age integer,
  add column if not exists blood_type text,
  add column if not exists inactivity_threshold integer not null default 24,
  add column if not exists terms_version text,
  add column if not exists terms_accepted_at timestamptz,
  add column if not exists profile_completed_at timestamptz;

alter table public.users
  drop constraint if exists users_name_format;
alter table public.users
  add constraint users_name_format
  check (
    char_length(btrim(name)) between 2 and 50
    and btrim(name) ~ '^[A-Za-z][A-Za-z .''-]*$'
  ) not valid;

alter table public.users
  drop constraint if exists users_age_range;
alter table public.users
  add constraint users_age_range
  check (age is null or age between 18 and 120) not valid;

alter table public.users
  drop constraint if exists users_blood_type;
alter table public.users
  add constraint users_blood_type
  check (
    blood_type is null
    or blood_type = ''
    or upper(blood_type) in ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-')
  ) not valid;

alter table public.users
  drop constraint if exists users_inactivity_threshold_range;
alter table public.users
  add constraint users_inactivity_threshold_range
  check (inactivity_threshold between 1 and 168) not valid;

alter table public.users
  drop constraint if exists users_phone_format;
alter table public.users
  add constraint users_phone_format
  check (
    phone is null
    or char_length(regexp_replace(phone, '[^0-9]', '', 'g')) between 8 and 15
  ) not valid;

alter table public.users
  drop constraint if exists users_address_length;
alter table public.users
  add constraint users_address_length
  check (address is null or char_length(btrim(address)) <= 200) not valid;

alter table public.users
  drop constraint if exists users_terms_version_length;
alter table public.users
  add constraint users_terms_version_length
  check (terms_version is null or char_length(btrim(terms_version)) between 4 and 30) not valid;

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
  add column if not exists id uuid default gen_random_uuid(),
  add column if not exists user_id uuid references auth.users(id) on delete cascade,
  add column if not exists name text,
  add column if not exists relationship text not null default 'Trusted contact',
  add column if not exists phone text,
  add column if not exists address text not null default '',
  add column if not exists is_primary boolean not null default false;

alter table public.contacts
  drop constraint if exists contacts_relationship_required;
alter table public.contacts
  add constraint contacts_relationship_required
  check (char_length(btrim(coalesce(relationship, ''))) between 2 and 30) not valid;

alter table public.contacts
  drop constraint if exists contacts_address_required;
alter table public.contacts
  add constraint contacts_address_required
  check (
    char_length(btrim(coalesce(address, ''))) between 1 and 200
  ) not valid;

create unique index if not exists contacts_one_primary_per_user
on public.contacts(user_id)
where is_primary;

create or replace function public.enforce_contact_rules()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  normalized_phone text;
begin
  normalized_phone := regexp_replace(new.phone, '[^0-9]', '', 'g');

  if char_length(btrim(new.name)) < 2
     or char_length(btrim(new.name)) > 50 then
    raise exception 'Contact name must contain 2 to 50 characters';
  end if;

  if char_length(normalized_phone) < 8
     or char_length(normalized_phone) > 15 then
    raise exception 'Contact phone must contain 8 to 15 digits';
  end if;

  if char_length(btrim(coalesce(new.relationship, ''))) < 2
     or char_length(btrim(coalesce(new.relationship, ''))) > 30 then
    raise exception 'Contact relationship must contain 2 to 30 characters';
  end if;

  if char_length(btrim(coalesce(new.address, ''))) < 1
     or char_length(btrim(coalesce(new.address, ''))) > 200 then
    raise exception 'Contact address is required and must not exceed 200 characters';
  end if;

  if exists (
    select 1
    from public.contacts
    where user_id = new.user_id
      and regexp_replace(phone, '[^0-9]', '', 'g') = normalized_phone
  ) then
    raise exception 'This phone number is already an emergency contact';
  end if;

  if (
    select count(*)
    from public.contacts
    where user_id = new.user_id
  ) >= 5 then
    raise exception 'A user can have at most 5 emergency contacts';
  end if;

  if new.is_primary then
    update public.contacts
    set is_primary = false
    where user_id = new.user_id
      and is_primary;
  elsif not exists (
    select 1 from public.contacts where user_id = new.user_id
  ) then
    new.is_primary := true;
  end if;

  return new;
end;
$$;

drop trigger if exists contacts_validate_before_write on public.contacts;
create trigger contacts_validate_before_write
before insert on public.contacts
for each row execute function public.enforce_contact_rules();

create or replace function public.promote_primary_contact()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if new.is_primary then
    update public.contacts
    set is_primary = false
    where user_id = new.user_id
      and is_primary;
  end if;

  return new;
end;
$$;

drop trigger if exists contacts_primary_before_update on public.contacts;
create trigger contacts_primary_before_update
before update of is_primary on public.contacts
for each row
when (new.is_primary is true and old.is_primary is distinct from new.is_primary)
execute function public.promote_primary_contact();

-- In Supabase Dashboard > Authentication > Sign In / Providers > Email:
-- set the minimum password length to 8. Flutter additionally requires an
-- uppercase letter, lowercase letter, number, symbol, and no whitespace.
