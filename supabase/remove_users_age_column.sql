-- Optional cleanup after removing age from the app.
-- Run in Supabase Dashboard > SQL Editor only if you want to remove the
-- existing public.users.age column from your database.

alter table public.users
  drop constraint if exists users_age_range;

alter table public.users
  drop column if exists age;

select column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name = 'users'
  and column_name = 'age';
