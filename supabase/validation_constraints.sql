-- Run once in Supabase Dashboard > SQL Editor.
-- These rules mirror Flutter validation and protect writes from other clients.

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

  return new;
end;
$$;

drop trigger if exists contacts_validate_before_write on public.contacts;
create trigger contacts_validate_before_write
before insert on public.contacts
for each row execute function public.enforce_contact_rules();

-- In Supabase Dashboard > Authentication > Sign In / Providers > Email:
-- set the minimum password length to 8. Flutter additionally requires an
-- uppercase letter, lowercase letter, number, symbol, and no whitespace.
