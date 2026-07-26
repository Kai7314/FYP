-- Publish virtual reward catalog changes so signed-in clients can refresh
-- their active catalog immediately after an administrator saves a reward.

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables publication_tables
    where publication_tables.pubname = 'supabase_realtime'
      and publication_tables.schemaname = 'public'
      and publication_tables.tablename = 'reward_catalog'
  ) then
    alter publication supabase_realtime
      add table public.reward_catalog;
  end if;
end;
$$;

alter table public.reward_catalog replica identity full;

notify pgrst, 'reload schema';
