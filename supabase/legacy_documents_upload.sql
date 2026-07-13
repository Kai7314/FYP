-- Run this once in Supabase Dashboard > SQL Editor to enable secure
-- Legacy Planning document uploads, viewing, and deletion.

create table if not exists public.documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  storage_path text not null unique,
  uploaded_at timestamptz not null default now()
);

alter table public.documents
  add column if not exists uploaded_at timestamptz not null default now();

create index if not exists documents_user_uploaded_at_idx
on public.documents(user_id, uploaded_at desc);

alter table public.documents enable row level security;

drop policy if exists "documents_own_all" on public.documents;
create policy "documents_own_all"
on public.documents for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'legacy-documents',
  'legacy-documents',
  false,
  10485760,
  array['application/pdf', 'image/jpeg', 'image/png']::text[]
)
on conflict (id) do update set
  public = false,
  file_size_limit = 10485760,
  allowed_mime_types = excluded.allowed_mime_types;

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

select
  buckets.id,
  buckets.public,
  buckets.file_size_limit,
  buckets.allowed_mime_types
from storage.buckets buckets
where buckets.id = 'legacy-documents';

