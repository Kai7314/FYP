-- Run in Supabase Dashboard > SQL Editor if you want emergency SMS workers
-- to read the exact message prepared by the app.
--
-- The Flutter app still works without this column because it falls back to the
-- older emergency_delivery_outbox shape.

alter table public.emergency_delivery_outbox
  add column if not exists message_body text,
  add column if not exists provider text,
  add column if not exists provider_message_id text,
  add column if not exists last_error text,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists processed_at timestamptz;

create index if not exists emergency_delivery_outbox_pending_idx
on public.emergency_delivery_outbox(status, created_at)
where status = 'pending';

select column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name = 'emergency_delivery_outbox'
  and column_name in (
    'message_body',
    'provider',
    'provider_message_id',
    'last_error',
    'created_at',
    'processed_at'
  )
order by column_name;
