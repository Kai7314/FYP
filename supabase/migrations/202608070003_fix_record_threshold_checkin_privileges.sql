-- Direct inserts into checkins are intentionally blocked. Allow the narrowly
-- scoped RPC to insert a heartbeat for auth.uid() using the function owner's
-- table privileges.

alter function public.record_threshold_checkin() security definer;
alter function public.record_threshold_checkin()
  set search_path = pg_catalog, public;

revoke all on function public.record_threshold_checkin()
from public, anon, authenticated;

grant execute on function public.record_threshold_checkin()
to authenticated;

comment on function public.record_threshold_checkin() is
  'Records a threshold-aware check-in for auth.uid(); direct client inserts remain revoked.';
