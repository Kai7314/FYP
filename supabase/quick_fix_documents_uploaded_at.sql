-- Run this in Supabase Dashboard > SQL Editor if Legacy Planning says
-- "column documents.uploaded_at does not exist".

alter table public.documents
  add column if not exists uploaded_at timestamptz not null default now();

select
  column_name,
  data_type
from information_schema.columns
where table_schema = 'public'
  and table_name = 'documents'
  and column_name in ('id', 'user_id', 'name', 'storage_path', 'uploaded_at')
order by ordinal_position;
