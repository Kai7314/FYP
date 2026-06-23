-- Run this once in Supabase Dashboard > SQL Editor.
-- It lets authenticated users access only their own EthernaCare records.

alter table public.users enable row level security;
alter table public.checkins enable row level security;
alter table public.contacts enable row level security;
alter table public.rewards enable row level security;
alter table public.emergency_alerts enable row level security;

drop policy if exists "users_select_own" on public.users;
create policy "users_select_own"
on public.users for select
to authenticated
using ((select auth.uid()) = id);

drop policy if exists "users_insert_own" on public.users;
create policy "users_insert_own"
on public.users for insert
to authenticated
with check ((select auth.uid()) = id);

drop policy if exists "users_update_own" on public.users;
create policy "users_update_own"
on public.users for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

drop policy if exists "checkins_select_own" on public.checkins;
create policy "checkins_select_own"
on public.checkins for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "checkins_insert_own" on public.checkins;
create policy "checkins_insert_own"
on public.checkins for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "contacts_select_own" on public.contacts;
create policy "contacts_select_own"
on public.contacts for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "contacts_insert_own" on public.contacts;
create policy "contacts_insert_own"
on public.contacts for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "contacts_update_own" on public.contacts;
create policy "contacts_update_own"
on public.contacts for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "contacts_delete_own" on public.contacts;
create policy "contacts_delete_own"
on public.contacts for delete
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "rewards_select_own" on public.rewards;
create policy "rewards_select_own"
on public.rewards for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "rewards_insert_own" on public.rewards;
create policy "rewards_insert_own"
on public.rewards for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "rewards_update_own" on public.rewards;
create policy "rewards_update_own"
on public.rewards for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "alerts_select_own" on public.emergency_alerts;
create policy "alerts_select_own"
on public.emergency_alerts for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "alerts_insert_own" on public.emergency_alerts;
create policy "alerts_insert_own"
on public.emergency_alerts for insert
to authenticated
with check ((select auth.uid()) = user_id);
