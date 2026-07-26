-- Replace physical fulfillment and sponsored vouchers with automatic,
-- server-validated virtual milestone badges.

alter table public.reward_catalog
  drop constraint if exists reward_catalog_reward_kind_check;

alter table public.reward_catalog
  add constraint reward_catalog_reward_kind_check
  check (reward_kind in ('physical', 'voucher', 'virtual'));

update public.reward_catalog
set
  active = false,
  updated_at = now()
where active;

insert into public.reward_catalog (
  code,
  title,
  sponsor,
  description,
  milestone_days,
  reward_kind,
  voucher_value,
  catalog_version,
  active,
  updated_at
)
values
  (
    'oren_sprout_badge',
    'Oren Sprout Badge',
    'EthernaCare',
    'A fresh start badge for building your check-in habit.',
    3,
    'virtual',
    null,
    2,
    true,
    now()
  ),
  (
    'oren_companion_badge',
    'Caring Companion Badge',
    'EthernaCare',
    'A virtual badge celebrating one week with Oren.',
    7,
    'virtual',
    null,
    2,
    true,
    now()
  ),
  (
    'oren_safety_star_badge',
    'Safety Star Badge',
    'EthernaCare',
    'A virtual star for ten consistent safety check-ins.',
    10,
    'virtual',
    null,
    2,
    true,
    now()
  ),
  (
    'oren_guardian_badge',
    'Trusted Guardian Badge',
    'EthernaCare',
    'A virtual badge for two dependable check-in weeks.',
    14,
    'virtual',
    null,
    2,
    true,
    now()
  ),
  (
    'oren_golden_badge',
    'Golden Oren Badge',
    'EthernaCare',
    'The highest virtual badge for a 30-day check-in streak.',
    30,
    'virtual',
    null,
    2,
    true,
    now()
  )
on conflict (code) do update set
  title = excluded.title,
  sponsor = excluded.sponsor,
  description = excluded.description,
  milestone_days = excluded.milestone_days,
  reward_kind = excluded.reward_kind,
  voucher_value = excluded.voucher_value,
  catalog_version = excluded.catalog_version,
  active = true,
  updated_at = now();

-- Existing request rows are retained as historical records, but the client
-- can no longer create requests or use administrator fulfillment functions.
revoke execute on function public.request_current_user_reward(
  text,
  text,
  text,
  text,
  text,
  text
) from authenticated;

revoke execute on function public.is_current_user_reward_admin()
from authenticated;

revoke execute on function public.list_reward_requests_admin()
from authenticated;

revoke execute on function public.update_reward_request_admin(
  uuid,
  text,
  text,
  text
) from authenticated;

revoke select on table public.reward_requests from authenticated;

drop policy if exists "reward_requests_select_own_or_admin"
on public.reward_requests;

update public.reward_admins
set active = false
where active;

notify pgrst, 'reload schema';
