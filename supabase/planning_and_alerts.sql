-- Run once in Supabase Dashboard > SQL Editor.

create table if not exists public.funeral_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  religion text not null default '',
  service_type text not null default '',
  venue text not null default '',
  notes text not null default '',
  authorized_contact text not null default '',
  updated_at timestamptz not null default now()
);

create table if not exists public.documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  storage_path text not null unique,
  uploaded_at timestamptz not null default now()
);

create table if not exists public.legacy_notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 2 and 80),
  content text not null check (char_length(btrim(content)) between 2 and 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.emergency_delivery_outbox (
  id bigint generated always as identity primary key,
  alert_id text not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  contact_name text,
  contact_phone text not null,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'sent', 'failed')),
  attempt_count integer not null default 0,
  last_error text,
  created_at timestamptz not null default now(),
  processed_at timestamptz
);

alter table public.funeral_preferences enable row level security;
alter table public.documents enable row level security;
alter table public.legacy_notes enable row level security;
alter table public.emergency_delivery_outbox enable row level security;

drop policy if exists "preferences_own_all" on public.funeral_preferences;
create policy "preferences_own_all"
on public.funeral_preferences for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "documents_own_all" on public.documents;
create policy "documents_own_all"
on public.documents for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "legacy_notes_own_all" on public.legacy_notes;
create policy "legacy_notes_own_all"
on public.legacy_notes for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "outbox_select_own" on public.emergency_delivery_outbox;
create policy "outbox_select_own"
on public.emergency_delivery_outbox for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "outbox_insert_own" on public.emergency_delivery_outbox;
create policy "outbox_insert_own"
on public.emergency_delivery_outbox for insert
to authenticated
with check ((select auth.uid()) = user_id);

insert into storage.buckets (id, name, public, file_size_limit)
values ('legacy-documents', 'legacy-documents', false, 10485760)
on conflict (id) do update set
  public = false,
  file_size_limit = 10485760;

drop policy if exists "legacy_documents_read_own" on storage.objects;
create policy "legacy_documents_read_own"
on storage.objects for select
to authenticated
using (
  bucket_id = 'legacy-documents'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "legacy_documents_insert_own" on storage.objects;
create policy "legacy_documents_insert_own"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'legacy-documents'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "legacy_documents_delete_own" on storage.objects;
create policy "legacy_documents_delete_own"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'legacy-documents'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

-- A server worker or Edge Function should process pending outbox rows using an
-- SMS/push provider, increment attempt_count, and mark sent or failed.
