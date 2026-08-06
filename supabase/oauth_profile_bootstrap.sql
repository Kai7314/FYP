-- Run this in Supabase Dashboard > SQL Editor if OAuth users can log in
-- but app data does not load/save correctly.
-- It creates/backfills the public.users profile row for every auth.users row.

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default 'EthernaCare User'
);

alter table public.users
  add column if not exists terms_version text,
  add column if not exists terms_accepted_at timestamptz;

create or replace function public.safe_auth_display_name(
  metadata jsonb,
  email text
)
returns text
language plpgsql
immutable
as $$
declare
  display_name text;
begin
  display_name := coalesce(
    metadata ->> 'full_name',
    metadata ->> 'name',
    metadata ->> 'display_name',
    metadata ->> 'preferred_username',
    split_part(email, '@', 1),
    'EthernaCare User'
  );

  display_name := btrim(regexp_replace(display_name, '[^A-Za-z .''-]', ' ', 'g'));
  display_name := btrim(regexp_replace(display_name, '\s+', ' ', 'g'));

  if char_length(display_name) < 2
     or display_name !~ '^[A-Za-z]' then
    display_name := 'EthernaCare User';
  end if;

  if char_length(display_name) > 100 then
    display_name := 'EthernaCare User';
  end if;

  return display_name;
end;
$$;

create or replace function public.safe_auth_terms_version(metadata jsonb)
returns text
language sql
immutable
as $$
  select case
    when char_length(btrim(coalesce(metadata ->> 'terms_version', '')))
      between 4 and 30
      then btrim(metadata ->> 'terms_version')
    else null
  end;
$$;

create or replace function public.safe_auth_terms_accepted_at(metadata jsonb)
returns timestamptz
language plpgsql
stable
as $$
declare
  accepted_at timestamptz;
begin
  begin
    accepted_at := nullif(
      btrim(coalesce(metadata ->> 'terms_accepted_at', '')),
      ''
    )::timestamptz;
  exception when others then
    return null;
  end;

  if accepted_at > now() + interval '5 minutes' then
    return null;
  end if;
  return accepted_at;
end;
$$;

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (
    id,
    name,
    terms_version,
    terms_accepted_at
  )
  values (
    new.id,
    public.safe_auth_display_name(new.raw_user_meta_data, new.email),
    public.safe_auth_terms_version(new.raw_user_meta_data),
    public.safe_auth_terms_accepted_at(new.raw_user_meta_data)
  )
  on conflict (id) do update
  set
    name = case
      when public.users.name in ('EthernaCare User', 'User')
        then excluded.name
      else public.users.name
    end,
    terms_version = coalesce(
      public.users.terms_version,
      excluded.terms_version
    ),
    terms_accepted_at = coalesce(
      public.users.terms_accepted_at,
      excluded.terms_accepted_at
    )
  where public.users.name in ('EthernaCare User', 'User')
     or public.users.terms_version is null
     or public.users.terms_accepted_at is null;

  return new;
end;
$$;

-- The Flutter client calls this after every restored email or OAuth session.
-- SECURITY DEFINER allows profile repair even when an older RLS deployment
-- does not yet include the users_insert_own policy. auth.uid() still limits
-- the function to the signed-in user's own profile.
create or replace function public.ensure_current_user_profile()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  auth_user auth.users%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;

  select *
    into auth_user
  from auth.users
  where id = auth.uid();

  if auth_user.id is null then
    raise exception 'Authenticated user could not be found';
  end if;

  insert into public.users (
    id,
    name,
    terms_version,
    terms_accepted_at
  )
  values (
    auth_user.id,
    public.safe_auth_display_name(
      auth_user.raw_user_meta_data,
      auth_user.email
    ),
    public.safe_auth_terms_version(auth_user.raw_user_meta_data),
    public.safe_auth_terms_accepted_at(auth_user.raw_user_meta_data)
  )
  on conflict (id) do update
  set
    name = case
      when public.users.name in ('EthernaCare User', 'User')
        then excluded.name
      else public.users.name
    end,
    terms_version = coalesce(
      public.users.terms_version,
      excluded.terms_version
    ),
    terms_accepted_at = coalesce(
      public.users.terms_accepted_at,
      excluded.terms_accepted_at
    )
  where public.users.name in ('EthernaCare User', 'User')
     or public.users.terms_version is null
     or public.users.terms_accepted_at is null;
end;
$$;

revoke all on function public.ensure_current_user_profile() from public;
grant execute on function public.ensure_current_user_profile() to authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();

insert into public.users (
  id,
  name,
  terms_version,
  terms_accepted_at
)
select
  users.id,
  public.safe_auth_display_name(users.raw_user_meta_data, users.email),
  public.safe_auth_terms_version(users.raw_user_meta_data),
  public.safe_auth_terms_accepted_at(users.raw_user_meta_data)
from auth.users
on conflict (id) do update
set
  name = case
    when public.users.name in ('EthernaCare User', 'User')
      then excluded.name
    else public.users.name
  end,
  terms_version = coalesce(
    public.users.terms_version,
    excluded.terms_version
  ),
  terms_accepted_at = coalesce(
    public.users.terms_accepted_at,
    excluded.terms_accepted_at
  )
where public.users.name in ('EthernaCare User', 'User')
   or public.users.terms_version is null
   or public.users.terms_accepted_at is null;

select
  auth_users.id,
  auth_users.email,
  coalesce(auth_users.raw_app_meta_data ->> 'provider', 'email') as provider,
  public_users.name as app_profile_name,
  case when public_users.id is null then 'missing' else 'ok' end as app_profile
from auth.users auth_users
left join public.users public_users
  on public_users.id = auth_users.id
order by auth_users.created_at desc;
