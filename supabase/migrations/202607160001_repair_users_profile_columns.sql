-- Keep the public users profile aligned with every field sent by Edit Profile.

alter table public.users
  add column if not exists phone text,
  add column if not exists phone_verified_at timestamptz,
  add column if not exists address text,
  add column if not exists address_state text,
  add column if not exists address_region text,
  add column if not exists blood_type text,
  add column if not exists inactivity_threshold integer not null default 24,
  add column if not exists emergency_escalation_target text not null default 'primary_contact',
  add column if not exists terms_version text,
  add column if not exists terms_accepted_at timestamptz,
  add column if not exists profile_completed_at timestamptz;

update public.users
set emergency_escalation_target = 'primary_contact'
where emergency_escalation_target = 'trusted_contacts';

notify pgrst, 'reload schema';
