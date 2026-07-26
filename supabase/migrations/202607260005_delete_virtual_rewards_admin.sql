-- Allow the separate reward administrator interface to permanently remove
-- selected virtual rewards that have never been earned.

create or replace function public.delete_virtual_rewards_admin(
  p_codes text[]
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_codes text[];
  deleted_count integer := 0;
begin
  if not public.is_current_user_reward_admin() then
    raise exception 'Reward administrator access is required';
  end if;

  select coalesce(
    array_agg(distinct lower(btrim(input_code))),
    array[]::text[]
  )
    into normalized_codes
  from unnest(coalesce(p_codes, array[]::text[])) input_code
  where input_code is not null
    and btrim(input_code) <> '';

  if cardinality(normalized_codes) = 0 then
    raise exception 'Select at least one virtual reward';
  end if;

  if exists (
    select 1
    from public.rewards earned
    where earned.reward_code = any(normalized_codes)
  ) then
    raise exception
      'One or more selected rewards have already been earned; deactivate them instead';
  end if;

  delete from public.reward_catalog catalog
  where catalog.code = any(normalized_codes)
    and catalog.reward_kind = 'virtual';

  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;

revoke all on function public.delete_virtual_rewards_admin(text[])
from public, anon, authenticated;
grant execute on function public.delete_virtual_rewards_admin(text[])
to authenticated;

notify pgrst, 'reload schema';
