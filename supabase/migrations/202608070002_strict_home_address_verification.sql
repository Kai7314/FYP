-- Remove verification metadata from incomplete legacy address values and
-- prevent those values from being marked as verified again.

update public.users
set
  address_latitude = null,
  address_longitude = null,
  address_verified_at = null,
  address_validation_provider = null
where address_verified_at is not null
  and (
    char_length(btrim(coalesce(address, ''))) < 5
    or btrim(coalesce(address, '')) !~ '[[:alpha:]].*[[:alpha:]]'
    or btrim(coalesce(address_state, '')) = ''
    or btrim(coalesce(address_region, '')) = ''
  );

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
      char_length(btrim(coalesce(address, ''))) between 5 and 200 and
      btrim(coalesce(address, '')) ~ '[[:alpha:]].*[[:alpha:]]' and
      btrim(coalesce(address_state, '')) <> '' and
      btrim(coalesce(address_region, '')) <> '' and
      address_latitude between 0.8 and 7.6 and
      address_longitude between 99.5 and 119.5 and
      address_verified_at is not null and
      address_validation_provider is not null
    )
  );
