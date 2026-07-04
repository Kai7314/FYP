-- Run this in Supabase Dashboard > SQL Editor if adding contacts says
-- "Could not find the 'is_primary' column of 'contacts'".

alter table public.contacts
  add column if not exists relationship text not null default 'Trusted contact',
  add column if not exists address text not null default '',
  add column if not exists address_state text,
  add column if not exists address_region text,
  add column if not exists is_primary boolean not null default false;

create unique index if not exists contacts_one_primary_per_user
on public.contacts(user_id)
where is_primary;

create or replace function public.set_primary_contact(p_contact_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_user_id uuid;
begin
  select user_id
  into target_user_id
  from public.contacts
  where id = p_contact_id;

  if target_user_id is null then
    raise exception 'Contact not found';
  end if;

  if target_user_id <> auth.uid() then
    raise exception 'Not allowed to update this contact';
  end if;

  update public.contacts
  set is_primary = false
  where user_id = target_user_id
    and id <> p_contact_id
    and is_primary;

  update public.contacts
  set is_primary = true
  where id = p_contact_id
    and user_id = target_user_id;
end;
$$;

grant execute on function public.set_primary_contact(uuid) to authenticated;

select column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name = 'contacts'
  and column_name in (
    'relationship',
    'address',
    'address_state',
    'address_region',
    'is_primary'
  )
order by column_name;
