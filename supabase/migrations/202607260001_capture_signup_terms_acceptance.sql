-- Copy explicit Terms acceptance from Supabase auth signup metadata into the
-- public profile used by the Flutter app.

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

  if char_length(display_name) > 50 then
    display_name := btrim(substring(display_name from 1 for 50));
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
grant execute on function public.ensure_current_user_profile()
to authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();

update public.users as profiles
set
  terms_version = coalesce(
    profiles.terms_version,
    public.safe_auth_terms_version(auth_users.raw_user_meta_data)
  ),
  terms_accepted_at = coalesce(
    profiles.terms_accepted_at,
    public.safe_auth_terms_accepted_at(auth_users.raw_user_meta_data)
  )
from auth.users as auth_users
where profiles.id = auth_users.id
  and (
    profiles.terms_version is null
    or profiles.terms_accepted_at is null
  );

notify pgrst, 'reload schema';
