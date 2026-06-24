-- Run this in Supabase Dashboard > SQL Editor if first-login profile setup says
-- "Could not find the 'address' column of 'users'".

alter table public.users
  add column if not exists phone text,
  add column if not exists address text,
  add column if not exists age integer,
  add column if not exists blood_type text,
  add column if not exists inactivity_threshold integer not null default 24,
  add column if not exists terms_version text,
  add column if not exists terms_accepted_at timestamptz,
  add column if not exists profile_completed_at timestamptz;

select column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name = 'users'
  and column_name in (
    'phone',
    'address',
    'age',
    'blood_type',
    'inactivity_threshold',
    'terms_version',
    'terms_accepted_at',
    'profile_completed_at'
  )
order by column_name;
