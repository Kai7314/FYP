-- Document bytes are uploaded to the user's private folder, then an Edge
-- Function validates the file before service_role creates metadata.

drop policy if exists "documents_own_all" on public.documents;
drop policy if exists "documents_select_own" on public.documents;
create policy "documents_select_own"
on public.documents for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "documents_delete_own" on public.documents;
create policy "documents_delete_own"
on public.documents for delete
to authenticated
using ((select auth.uid()) = user_id);

revoke insert, update on public.documents from authenticated;
grant select, delete on public.documents to authenticated;

notify pgrst, 'reload schema';
