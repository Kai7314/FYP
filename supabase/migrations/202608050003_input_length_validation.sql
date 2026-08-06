-- Enforce the same display-name limit used by the Flutter forms.

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
     or char_length(display_name) > 100
     or display_name !~ '^[A-Za-z]' then
    display_name := 'EthernaCare User';
  end if;

  return display_name;
end;
$$;

alter table public.users
  drop constraint if exists users_name_length_check;

alter table public.users
  add constraint users_name_length_check
  check (char_length(btrim(name)) between 2 and 100)
  not valid;
