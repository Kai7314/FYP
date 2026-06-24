-- Run this in Supabase Dashboard > SQL Editor if contacts cannot be deleted.

alter table public.contacts enable row level security;

drop policy if exists "contacts_select_own" on public.contacts;
create policy "contacts_select_own"
on public.contacts for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "contacts_delete_own" on public.contacts;
create policy "contacts_delete_own"
on public.contacts for delete
to authenticated
using ((select auth.uid()) = user_id);

select
  policyname,
  cmd,
  qual
from pg_policies
where schemaname = 'public'
  and tablename = 'contacts'
  and cmd in ('SELECT', 'DELETE')
order by cmd, policyname;
