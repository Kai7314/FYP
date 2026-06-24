-- Run this in Supabase Dashboard > SQL Editor if adding contacts says
-- "Could not find the 'is_primary' column of 'contacts'".

alter table public.contacts
  add column if not exists relationship text not null default 'Trusted contact',
  add column if not exists address text not null default '',
  add column if not exists is_primary boolean not null default false;

create unique index if not exists contacts_one_primary_per_user
on public.contacts(user_id)
where is_primary;

select column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name = 'contacts'
  and column_name in ('relationship', 'address', 'is_primary')
order by column_name;
