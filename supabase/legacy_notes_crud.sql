-- Run this in Supabase Dashboard > SQL Editor to enable Legacy Planning notes.

create table if not exists public.legacy_notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 2 and 80),
  content text not null check (char_length(btrim(content)) between 2 and 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.legacy_notes enable row level security;

drop policy if exists "legacy_notes_own_all" on public.legacy_notes;
create policy "legacy_notes_own_all"
on public.legacy_notes for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

select
  column_name,
  data_type
from information_schema.columns
where table_schema = 'public'
  and table_name = 'legacy_notes'
order by ordinal_position;
