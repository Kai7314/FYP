-- Run in Supabase Dashboard > SQL Editor to diagnose Google/OAuth users whose
-- authentication succeeds but whose EthernaCare data appears not to sync.
-- This script is read-only.

select
  auth_users.id,
  auth_users.email,
  coalesce(
    (
      select string_agg(distinct identities.provider, ', ')
      from auth.identities identities
      where identities.user_id = auth_users.id
    ),
    auth_users.raw_app_meta_data ->> 'provider',
    'email'
  ) as providers,
  auth_users.created_at,
  auth_users.last_sign_in_at,
  case when profiles.id is null then 'MISSING' else 'OK' end as public_profile,
  profiles.name,
  (select count(*) from public.checkins c where c.user_id = auth_users.id)
    as checkin_count,
  (select count(*) from public.contacts c where c.user_id = auth_users.id)
    as contact_count,
  (select count(*) from public.rewards r where r.user_id = auth_users.id)
    as reward_count
from auth.users auth_users
left join public.users profiles on profiles.id = auth_users.id
order by auth_users.last_sign_in_at desc nulls last;

-- Ideally one email maps to one auth.users ID with multiple identities. Rows
-- returned here indicate separate accounts; RLS correctly keeps their app data
-- separate until identities/data are deliberately merged.
select
  lower(email) as email,
  count(*) as auth_user_count,
  string_agg(id::text, ', ' order by created_at) as auth_user_ids
from auth.users
where email is not null
group by lower(email)
having count(*) > 1
order by lower(email);

select
  trigger_name,
  event_manipulation,
  action_statement
from information_schema.triggers
where event_object_schema = 'auth'
  and event_object_table = 'users'
  and trigger_name = 'on_auth_user_created';

select
  routine_name,
  security_type
from information_schema.routines
where routine_schema = 'public'
  and routine_name in (
    'handle_new_auth_user',
    'ensure_current_user_profile',
    'safe_auth_display_name'
  )
order by routine_name;
