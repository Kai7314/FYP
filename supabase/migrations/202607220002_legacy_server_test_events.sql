-- Owner-scoped audit and rate limiting for the debug Legacy server tests.

create table if not exists public.legacy_server_test_events (
  id bigint generated always as identity primary key,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  action text not null check (
    action in ('live_status', 'day_89', 'day_90', 'day_97', 'test_email')
  ),
  succeeded boolean not null,
  detail text,
  created_at timestamptz not null default now()
);

create index if not exists legacy_server_test_events_owner_created_idx
on public.legacy_server_test_events(owner_user_id, created_at desc);

alter table public.legacy_server_test_events enable row level security;

revoke insert, update, delete on public.legacy_server_test_events
from anon, authenticated;

drop policy if exists "legacy_server_test_events_select_own"
on public.legacy_server_test_events;
create policy "legacy_server_test_events_select_own"
on public.legacy_server_test_events for select
to authenticated
using ((select auth.uid()) = owner_user_id);

notify pgrst, 'reload schema';
