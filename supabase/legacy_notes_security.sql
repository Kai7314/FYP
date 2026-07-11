-- Run in Supabase Dashboard > SQL Editor after legacy_notes_crud.sql.
-- Prevents credentials and authentication secrets from being stored in
-- Legacy Notes, even when a request bypasses the Flutter form.

create or replace function public.reject_legacy_note_secrets()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  note_text text;
begin
  note_text := coalesce(new.title, '') || E'\n' || coalesce(new.content, '');

  if note_text ~* '(^|[^a-z0-9_])(password|passcode|pin|otp|one[- ]?time password|api[- _]?key|access[- _]?token|secret[- _]?key|private[- _]?key|seed[- _]?phrase|recovery[- _]?phrase|cvv|security[- _]?code)([^a-z0-9_]|$)'
     or note_text ~* '-----BEGIN [A-Z ]*PRIVATE KEY-----'
     or note_text ~* '(^|[^a-z0-9_-])sk-[a-z0-9_-]{16,}([^a-z0-9_-]|$)'
     or note_text ~* '(^|[^a-z0-9_-])eyJ[a-z0-9_-]{20,}\.[a-z0-9_-]{10,}' then
    raise exception using
      errcode = 'P0001',
      message = 'Legacy Notes must not contain passwords, PINs, OTPs, recovery phrases, API keys, access tokens, or security codes';
  end if;

  return new;
end;
$$;

drop trigger if exists legacy_notes_reject_secrets_before_write
on public.legacy_notes;

create trigger legacy_notes_reject_secrets_before_write
before insert or update of title, content on public.legacy_notes
for each row execute function public.reject_legacy_note_secrets();

-- Returns only record identifiers that may need manual review. It does not
-- expose note content in the result.
select id, created_at, updated_at
from public.legacy_notes
where (coalesce(title, '') || E'\n' || coalesce(content, '')) ~*
  '(^|[^a-z0-9_])(password|passcode|pin|otp|one[- ]?time password|api[- _]?key|access[- _]?token|secret[- _]?key|private[- _]?key|seed[- _]?phrase|recovery[- _]?phrase|cvv|security[- _]?code)([^a-z0-9_]|$)'
order by updated_at desc;
