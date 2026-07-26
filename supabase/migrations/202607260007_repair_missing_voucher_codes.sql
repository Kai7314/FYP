-- Ensure previously earned rewards receive a code if their catalog entry is
-- subsequently changed from a badge into a voucher.

create or replace function public.sync_current_user_rewards()
returns table (
  current_streak integer,
  newly_earned integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  streak_value integer;
  inserted_count integer;
begin
  if current_user_id is null then
    raise exception 'You must be signed in';
  end if;

  streak_value := public.current_checkin_streak(current_user_id, now());

  insert into public.rewards (
    user_id,
    streak_days,
    reward_type,
    reward_code,
    status,
    earned_at,
    redeem_code
  )
  select
    current_user_id,
    catalog.milestone_days,
    catalog.title,
    catalog.code,
    'earned',
    now(),
    case
      when catalog.reward_kind = 'voucher'
        then public.generate_reward_redeem_code()
      else null
    end
  from public.reward_catalog catalog
  where catalog.active
    and catalog.reward_kind in ('virtual', 'voucher')
    and catalog.milestone_days <= streak_value
  on conflict (user_id, reward_code)
    where reward_code is not null
  do nothing;

  get diagnostics inserted_count = row_count;

  update public.rewards rewards
  set redeem_code = public.generate_reward_redeem_code()
  from public.reward_catalog catalog
  where rewards.user_id = current_user_id
    and catalog.code = rewards.reward_code
    and catalog.reward_kind = 'voucher'
    and rewards.redeem_code is null;

  return query
  select streak_value, inserted_count;
end;
$$;

revoke all on function public.sync_current_user_rewards()
from public, anon, authenticated;
grant execute on function public.sync_current_user_rewards()
to authenticated;

notify pgrst, 'reload schema';
