-- Repair Legacy Planning document metadata and private Storage access.

create table if not exists public.documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  storage_path text not null unique,
  uploaded_at timestamptz not null default now()
);

-- Existing projects may already have an older, incomplete documents table.
alter table public.documents
  add column if not exists id uuid default gen_random_uuid(),
  add column if not exists user_id uuid references auth.users(id) on delete cascade,
  add column if not exists name text,
  add column if not exists storage_path text,
  add column if not exists uploaded_at timestamptz default now();

update public.documents
set id = gen_random_uuid()
where id is null;

update public.documents
set name = 'Legacy document'
where name is null or btrim(name) = '';

update public.documents
set storage_path = coalesce(user_id::text, 'unassigned')
  || '/migrated/' || id::text
where storage_path is null or btrim(storage_path) = '';

update public.documents
set uploaded_at = now()
where uploaded_at is null;

alter table public.documents
  alter column id set default gen_random_uuid(),
  alter column id set not null,
  alter column name set not null,
  alter column storage_path set not null,
  alter column uploaded_at set default now(),
  alter column uploaded_at set not null;

create unique index if not exists documents_storage_path_uidx
on public.documents(storage_path);

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
  file_size_limit = excluded.file_size_limit,
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

notify pgrst, 'reload schema';
