-- Badge milestones are earned automatically, but a badge joins the user's
-- visible collection only after the user explicitly collects it.

alter table public.rewards
  add column if not exists claimed_at timestamptz;

create or replace function public.claim_current_user_badge(
  p_reward_code text
)
returns table (
  reward_code text,
  status text,
  claimed_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  normalized_code text := btrim(p_reward_code);
begin
  if current_user_id is null then
    raise exception 'You must be signed in';
  end if;

  if normalized_code is null or normalized_code = '' then
    raise exception 'Select a badge to collect';
  end if;

  -- Make the operation safe even when the client has not refreshed since the
  -- user completed the milestone.
  perform *
  from public.sync_current_user_rewards();

  return query
  update public.rewards earned
  set
    status = 'claimed',
    claimed_at = coalesce(earned.claimed_at, now())
  from public.reward_catalog catalog
  where earned.user_id = current_user_id
    and earned.reward_code = normalized_code
    and earned.status in ('earned', 'claimed')
    and catalog.code = earned.reward_code
    and catalog.reward_kind = 'virtual'
  returning
    earned.reward_code,
    earned.status,
    earned.claimed_at;

  if not found then
    if exists (
      select 1
      from public.reward_catalog catalog
      where catalog.code = normalized_code
        and catalog.reward_kind = 'voucher'
    ) then
      raise exception 'Vouchers do not belong in the badge list';
    end if;

    raise exception
      'This badge is not available yet. Complete its check-in goal first';
  end if;
end;
$$;

revoke all on function public.claim_current_user_badge(text)
from public, anon, authenticated;
grant execute on function public.claim_current_user_badge(text)
to authenticated;

notify pgrst, 'reload schema';
