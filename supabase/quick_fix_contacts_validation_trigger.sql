-- Run this in Supabase Dashboard > SQL Editor if adding contacts says
-- "Contact address is required and must not exceed 200 characters"
-- even when you entered an address.

alter table public.contacts
  add column if not exists relationship text not null default 'Trusted contact',
  add column if not exists address text not null default '',
  add column if not exists address_state text,
  add column if not exists address_region text,
  add column if not exists is_primary boolean not null default false;

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

  if char_length(btrim(coalesce(new.address, ''))) < 1 then
    raise exception 'Contact address is required';
  end if;

  if char_length(btrim(new.address)) > 200 then
    raise exception 'Contact address must not exceed 200 characters';
  end if;

  if char_length(btrim(coalesce(new.address_state, ''))) < 1
     or char_length(btrim(coalesce(new.address_state, ''))) > 80 then
    raise exception 'Contact state is required and must not exceed 80 characters';
  end if;

  if char_length(btrim(coalesce(new.address_region, ''))) < 1
     or char_length(btrim(coalesce(new.address_region, ''))) > 80 then
    raise exception 'Contact region is required and must not exceed 80 characters';
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
