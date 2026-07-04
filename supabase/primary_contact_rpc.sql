-- Run in Supabase Dashboard > SQL Editor to make primary-contact switching
-- atomic and avoid contacts_one_primary_per_user conflicts.

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
