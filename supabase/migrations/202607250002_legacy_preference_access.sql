-- Audit funeral-preference-only access separately from the protected release
-- of Legacy Notes and secure documents.

alter table public.legacy_access_audit
  drop constraint if exists legacy_access_audit_event_check;

alter table public.legacy_access_audit
  add constraint legacy_access_audit_event_check
  check (event in (
    'funeral_preferences_released',
    'legacy_data_released'
  ));

notify pgrst, 'reload schema';
