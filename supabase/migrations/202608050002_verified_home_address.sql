-- Store the coordinates returned by the profile address validation service.

alter table public.users
  add column if not exists address_latitude double precision,
  add column if not exists address_longitude double precision,
  add column if not exists address_verified_at timestamptz,
  add column if not exists address_validation_provider text;

alter table public.users
  drop constraint if exists users_verified_home_address_check;

alter table public.users
  add constraint users_verified_home_address_check check (
    (
      address_latitude is null and
      address_longitude is null and
      address_verified_at is null and
      address_validation_provider is null
    ) or (
      address_latitude between 0.8 and 7.6 and
      address_longitude between 99.5 and 119.5 and
      address_verified_at is not null and
      address_validation_provider is not null
    )
  );
