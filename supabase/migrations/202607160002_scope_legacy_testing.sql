-- Scope Legacy Checking test mode to an account-owner controlled flag.

alter table public.users
  add column if not exists legacy_access_enabled boolean not null default false,
  add column if not exists legacy_access_test_enabled boolean not null default false,
  add column if not exists legacy_access_started_at timestamptz not null default now();

create table if not exists public.legacy_access_otps (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  contact_id uuid references public.contacts(id) on delete cascade,
  phone text not null,
  code_hash text not null,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  attempt_count integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists legacy_access_otps_lookup_idx
on public.legacy_access_otps(owner_user_id, phone, created_at desc);

create table if not exists public.legacy_access_audit (
  id bigint generated always as identity primary key,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  contact_id uuid references public.contacts(id) on delete set null,
  event text not null check (event in ('legacy_data_released')),
  created_at timestamptz not null default now()
);

create index if not exists legacy_access_audit_owner_created_idx
on public.legacy_access_audit(owner_user_id, created_at desc);

alter table public.legacy_access_otps enable row level security;
alter table public.legacy_access_audit enable row level security;

revoke all on table public.legacy_access_otps from anon, authenticated;
revoke insert, update, delete on table public.legacy_access_audit
from anon, authenticated;

drop policy if exists "legacy_access_audit_select_own"
on public.legacy_access_audit;
create policy "legacy_access_audit_select_own"
on public.legacy_access_audit for select
to authenticated
using ((select auth.uid()) = owner_user_id);

create or replace function public.guard_legacy_access_fields()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if (
    new.legacy_access_enabled is distinct from old.legacy_access_enabled
    or new.legacy_access_test_enabled is distinct from old.legacy_access_test_enabled
    or new.legacy_access_started_at is distinct from old.legacy_access_started_at
  ) and coalesce(
    current_setting('app.legacy_access_update', true),
    ''
  ) <> 'allowed' then
    raise exception 'Use the Legacy Checking settings to update access';
  end if;

  return new;
end;
$$;

drop trigger if exists users_guard_legacy_access_fields on public.users;
create trigger users_guard_legacy_access_fields
before update of legacy_access_enabled, legacy_access_test_enabled,
  legacy_access_started_at
on public.users
for each row execute function public.guard_legacy_access_fields();

create or replace function public.set_legacy_access_enabled(enabled boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'You must be signed in';
  end if;

  perform set_config('app.legacy_access_update', 'allowed', true);

  update public.users
  set
    legacy_access_enabled = enabled,
    legacy_access_test_enabled = case
      when enabled then legacy_access_test_enabled
      else false
    end,
    legacy_access_started_at = case
      when enabled then now()
      else legacy_access_started_at
    end
  where id = auth.uid();

  if not found then
    raise exception 'User profile was not found';
  end if;
end;
$$;

revoke all on function public.set_legacy_access_enabled(boolean) from public;
grant execute on function public.set_legacy_access_enabled(boolean)
to authenticated;

create or replace function public.set_legacy_access_test_enabled(enabled boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'You must be signed in';
  end if;

  if enabled and not exists (
    select 1
    from public.contacts
    where user_id = auth.uid()
      and is_primary
      and phone_verified_at is not null
  ) then
    raise exception 'Verify the primary contact phone before enabling testing access';
  end if;

  perform set_config('app.legacy_access_update', 'allowed', true);

  update public.users
  set legacy_access_test_enabled = enabled
  where id = auth.uid()
    and (not enabled or legacy_access_enabled);

  if not found then
    raise exception 'Enable Legacy Checking before testing access';
  end if;
end;
$$;

revoke all on function public.set_legacy_access_test_enabled(boolean)
from public;
grant execute on function public.set_legacy_access_test_enabled(boolean)
to authenticated;

notify pgrst, 'reload schema';
