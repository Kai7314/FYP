-- Keep safety decisions, check-in timing, Oren currency, and shop ownership
-- authoritative on Supabase. The Flutter app may cache these values for
-- display, but authenticated RPCs are the only mutation path.

create table if not exists public.oren_toy_catalog (
  id text primary key,
  name text not null,
  price integer not null check (price between 0 and 10000),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.oren_toy_catalog (id, name, price, active)
values
  ('yarn_ball', 'Yarn Ball', 8, true),
  ('fish_plush', 'Fish Plush', 12, true),
  ('feather_wand', 'Feather Wand', 16, true)
on conflict (id) do update set
  name = excluded.name,
  price = excluded.price,
  active = excluded.active,
  updated_at = now();

alter table public.oren_toy_catalog enable row level security;
drop policy if exists "oren_toy_catalog_read" on public.oren_toy_catalog;
create policy "oren_toy_catalog_read"
on public.oren_toy_catalog for select
to authenticated
using (active);

revoke insert, update, delete on public.oren_toy_catalog
from anon, authenticated;
grant select on public.oren_toy_catalog to authenticated;

create table if not exists public.oren_care_states (
  user_id uuid primary key references auth.users(id) on delete cascade,
  tokens integer not null default 0 check (tokens between 0 and 1000000),
  owned_toy_ids text[] not null default array[]::text[],
  selected_toy_id text,
  last_daily_token_date date,
  last_checkin_token_date date,
  last_action text not null default 'Oren is ready for today.',
  mood text not null default 'Calm',
  energy integer not null default 65 check (energy between 0 and 100),
  updated_at timestamptz not null default now(),
  legacy_imported_at timestamptz
);

alter table public.oren_care_states enable row level security;
drop policy if exists "oren_care_states_read_own" on public.oren_care_states;
create policy "oren_care_states_read_own"
on public.oren_care_states for select
to authenticated
using ((select auth.uid()) = user_id);

revoke insert, update, delete on public.oren_care_states
from anon, authenticated;
grant select on public.oren_care_states to authenticated;

create or replace function public.apply_oren_energy_decay(
  p_user_id uuid,
  p_now timestamptz default now()
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  elapsed_intervals integer;
  next_energy integer;
begin
  select greatest(
    0,
    least(
      1000000,
      floor(extract(epoch from (p_now - states.updated_at)) / 3600)::integer
    )
  )
    into elapsed_intervals
  from public.oren_care_states states
  where states.user_id = p_user_id;

  if coalesce(elapsed_intervals, 0) <= 0 then
    return;
  end if;

  select greatest(0, states.energy - elapsed_intervals)
    into next_energy
  from public.oren_care_states states
  where states.user_id = p_user_id;

  update public.oren_care_states states
  set
    energy = next_energy,
    mood = case
      when next_energy >= 90 then 'Energetic'
      when next_energy <= 25 then 'Tired'
      else 'Calm'
    end,
    last_action = case
      when next_energy >= 90 then 'Oren is full of energy.'
      when next_energy <= 25 then 'Oren is sleepy. A snack would help.'
      else 'Oren is ready for today.'
    end,
    updated_at = states.updated_at + make_interval(hours => elapsed_intervals)
  where states.user_id = p_user_id;
end;
$$;

revoke all on function public.apply_oren_energy_decay(uuid, timestamptz)
from public, anon, authenticated;

create or replace function public.get_current_user_oren_state()
returns setof public.oren_care_states
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(current_user_id::text, 17));

  insert into public.oren_care_states (user_id)
  values (current_user_id)
  on conflict (user_id) do nothing;

  perform public.apply_oren_energy_decay(current_user_id, now());

  return query
  select states.*
  from public.oren_care_states states
  where states.user_id = current_user_id;
end;
$$;

revoke all on function public.get_current_user_oren_state()
from public, anon, authenticated;
grant execute on function public.get_current_user_oren_state()
to authenticated;

create or replace function public.migrate_current_user_oren_state(
  p_legacy jsonb
)
returns setof public.oren_care_states
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  valid_owned text[] := array[]::text[];
  requested_selection text := btrim(coalesce(p_legacy ->> 'selected_toy_id', ''));
  imported_tokens integer := 0;
  imported_energy integer := 65;
  imported_daily date;
  imported_checkin date;
  malaysia_today date := (now() at time zone 'Asia/Kuala_Lumpur')::date;
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(current_user_id::text, 17));

  insert into public.oren_care_states (user_id)
  values (current_user_id)
  on conflict (user_id) do nothing;

  if exists (
    select 1
    from public.oren_care_states states
    where states.user_id = current_user_id
      and states.legacy_imported_at is null
  ) then
    if coalesce(p_legacy ->> 'tokens', '') ~ '^\d{1,7}$' then
      imported_tokens := least(10000, (p_legacy ->> 'tokens')::integer);
    end if;

    if coalesce(p_legacy ->> 'energy', '') ~ '^\d{1,3}$' then
      imported_energy := least(100, (p_legacy ->> 'energy')::integer);
    end if;

    if jsonb_typeof(p_legacy -> 'owned_toy_ids') = 'array' then
      select coalesce(array_agg(catalog.id order by catalog.id), array[]::text[])
        into valid_owned
      from public.oren_toy_catalog catalog
      where catalog.active
        and catalog.id in (
          select jsonb_array_elements_text(p_legacy -> 'owned_toy_ids')
        );
    end if;

    if coalesce(p_legacy ->> 'last_daily_token_date', '')
       ~ '^\d{4}-\d{2}-\d{2}$' then
      begin
        imported_daily := (p_legacy ->> 'last_daily_token_date')::date;
        if imported_daily > malaysia_today then imported_daily := null; end if;
      exception when others then
        imported_daily := null;
      end;
    end if;

    if coalesce(p_legacy ->> 'last_checkin_token_date', '')
       ~ '^\d{4}-\d{2}-\d{2}$' then
      begin
        imported_checkin := (p_legacy ->> 'last_checkin_token_date')::date;
        if imported_checkin > malaysia_today then imported_checkin := null; end if;
      exception when others then
        imported_checkin := null;
      end;
    end if;

    update public.oren_care_states states
    set
      tokens = imported_tokens,
      owned_toy_ids = valid_owned,
      selected_toy_id = case
        when requested_selection = any(valid_owned) then requested_selection
        when cardinality(valid_owned) > 0 then valid_owned[1]
        else null
      end,
      last_daily_token_date = imported_daily,
      last_checkin_token_date = imported_checkin,
      energy = imported_energy,
      mood = case
        when imported_energy >= 90 then 'Energetic'
        when imported_energy <= 25 then 'Tired'
        else 'Calm'
      end,
      last_action = 'Oren progress is synced securely.',
      updated_at = now(),
      legacy_imported_at = now()
    where states.user_id = current_user_id
      and states.legacy_imported_at is null;
  end if;

  perform public.apply_oren_energy_decay(current_user_id, now());

  return query
  select states.*
  from public.oren_care_states states
  where states.user_id = current_user_id;
end;
$$;

revoke all on function public.migrate_current_user_oren_state(jsonb)
from public, anon, authenticated;
grant execute on function public.migrate_current_user_oren_state(jsonb)
to authenticated;

create or replace function public.perform_current_user_oren_action(
  p_action text,
  p_toy_id text default null
)
returns setof public.oren_care_states
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  action_name text := lower(btrim(coalesce(p_action, '')));
  toy public.oren_toy_catalog%rowtype;
  state public.oren_care_states%rowtype;
  malaysia_today date := (now() at time zone 'Asia/Kuala_Lumpur')::date;
  next_energy integer;
  full_energy boolean;
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(current_user_id::text, 17));
  insert into public.oren_care_states (user_id, legacy_imported_at)
  values (current_user_id, now())
  on conflict (user_id) do nothing;
  perform public.apply_oren_energy_decay(current_user_id, now());

  select states.* into state
  from public.oren_care_states states
  where states.user_id = current_user_id
  for update;

  if action_name = 'daily_login' then
    if state.last_daily_token_date is distinct from malaysia_today then
      update public.oren_care_states
      set
        tokens = tokens + 5,
        energy = least(100, energy + 5),
        last_daily_token_date = malaysia_today,
        mood = case when least(100, energy + 5) >= 90 then 'Energetic' else 'Happy' end,
        last_action = 'Daily login bonus earned: 5 Oren tokens.',
        updated_at = now()
      where user_id = current_user_id;
    end if;
  elsif action_name = 'daily_checkin' then
    if not exists (
      select 1
      from public.checkins checkins
      left join public.users users on users.id = checkins.user_id
      where checkins.user_id = current_user_id
        and checkins.checkin_time + make_interval(
          hours => greatest(1, least(168, coalesce(users.inactivity_threshold, 24)))
        ) > now()
    ) then
      raise exception 'Complete or renew your check-in before claiming today''s Oren bonus';
    end if;

    if state.last_checkin_token_date is distinct from malaysia_today then
      update public.oren_care_states
      set
        tokens = tokens + 3,
        energy = least(100, energy + 8),
        last_checkin_token_date = malaysia_today,
        mood = case when least(100, energy + 8) >= 90 then 'Energetic' else 'Happy' end,
        last_action = 'Daily check-in bonus earned: 3 Oren tokens.',
        updated_at = now()
      where user_id = current_user_id;
    else
      update public.oren_care_states
      set last_action = 'Daily check-in bonus already claimed today.'
      where user_id = current_user_id;
    end if;
  elsif action_name = 'feed_fish' then
    update public.oren_care_states
    set mood = 'Eating', energy = least(100, energy + 12),
        last_action = 'Oren enjoyed a fish snack.', updated_at = now()
    where user_id = current_user_id;
  elsif action_name = 'pet' then
    update public.oren_care_states
    set mood = 'Loved', energy = least(100, energy + 6),
        last_action = 'Oren liked the gentle pet.', updated_at = now()
    where user_id = current_user_id;
  elsif action_name in ('buy_toy', 'select_toy', 'play_toy') then
    select catalog.* into toy
    from public.oren_toy_catalog catalog
    where catalog.id = btrim(coalesce(p_toy_id, ''))
      and catalog.active;

    if not found then
      raise exception 'This Oren item is unavailable';
    end if;

    if action_name = 'buy_toy' then
      if toy.id = any(state.owned_toy_ids) then
        update public.oren_care_states
        set last_action = toy.name || ' is already owned.'
        where user_id = current_user_id;
      elsif state.tokens < toy.price then
        update public.oren_care_states
        set last_action = 'Not enough Oren tokens for ' || toy.name || '.'
        where user_id = current_user_id;
      else
        update public.oren_care_states
        set
          tokens = tokens - toy.price,
          owned_toy_ids = array_append(owned_toy_ids, toy.id),
          selected_toy_id = coalesce(selected_toy_id, toy.id),
          mood = 'Curious',
          last_action = toy.name || ' added to Oren inventory.',
          updated_at = now()
        where user_id = current_user_id;
      end if;
    elsif not (toy.id = any(state.owned_toy_ids)) then
      update public.oren_care_states
      set last_action = 'Buy ' || toy.name || ' before using it.'
      where user_id = current_user_id;
    elsif action_name = 'select_toy' then
      update public.oren_care_states
      set selected_toy_id = toy.id, mood = 'Curious',
          last_action = toy.name || ' is ready for playtime.', updated_at = now()
      where user_id = current_user_id;
    elsif state.energy <= 15 then
      update public.oren_care_states
      set mood = 'Tired',
          last_action = 'Oren is too tired to play. Feed Oren first.'
      where user_id = current_user_id;
    else
      full_energy := state.energy >= 90;
      next_energy := greatest(0, state.energy - case when full_energy then 16 else 10 end);
      update public.oren_care_states
      set
        energy = next_energy,
        mood = case when full_energy then 'Energetic' when next_energy <= 25 then 'Tired' else 'Playful' end,
        last_action = case
          when full_energy then 'Oren zoomed around with ' || toy.name || '.'
          when next_energy <= 25 then 'Oren played with ' || toy.name || ' and got sleepy.'
          else 'Oren played with ' || toy.name || '.'
        end,
        updated_at = now()
      where user_id = current_user_id;
    end if;
  elsif action_name = 'reset_mood' then
    update public.oren_care_states
    set
      mood = case when energy >= 90 then 'Energetic' when energy <= 25 then 'Tired' else 'Calm' end,
      last_action = case
        when energy >= 90 then 'Oren is full of energy.'
        when energy <= 25 then 'Oren is sleepy. A snack would help.'
        else 'Oren is ready for today.'
      end
    where user_id = current_user_id;
  else
    raise exception 'Unsupported Oren action';
  end if;

  return query
  select states.*
  from public.oren_care_states states
  where states.user_id = current_user_id;
end;
$$;

revoke all on function public.perform_current_user_oren_action(text, text)
from public, anon, authenticated;
grant execute on function public.perform_current_user_oren_action(text, text)
to authenticated;

-- Safety rows are created through authenticated functions. This prevents a
-- modified client from choosing an arbitrary recipient or SMS body.
create or replace function public.create_current_user_emergency_alert(
  p_status text default 'triggered'
)
returns setof public.emergency_alerts
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  safe_status text;
begin
  if current_user_id is null then raise exception 'Authentication required'; end if;
  safe_status := case when p_status = 'test_triggered' then 'test_triggered' else 'triggered' end;

  return query
  insert into public.emergency_alerts (user_id, triggered_time, status)
  values (current_user_id, now(), safe_status)
  returning public.emergency_alerts.*;
end;
$$;

create or replace function public.attach_current_user_alert_location(
  p_alert_id uuid,
  p_latitude double precision,
  p_longitude double precision
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then raise exception 'Authentication required'; end if;
  if p_latitude not between -90 and 90 or p_longitude not between -180 and 180 then
    raise exception 'Invalid emergency location';
  end if;
  if not exists (
    select 1 from public.emergency_alerts alerts
    where alerts.id = p_alert_id and alerts.user_id = current_user_id
  ) then
    raise exception 'Emergency alert not found';
  end if;

  insert into public.locations (alert_id, latitude, longitude, timestamp)
  values (p_alert_id::text, p_latitude, p_longitude, now());
end;
$$;

create or replace function public.queue_current_user_emergency_sms(
  p_alert_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  alert_record public.emergency_alerts%rowtype;
  primary_contact public.contacts%rowtype;
  target text;
  location_record public.locations%rowtype;
  message_body text;
  inserted_count integer := 0;
begin
  if current_user_id is null then raise exception 'Authentication required'; end if;

  select alerts.* into alert_record
  from public.emergency_alerts alerts
  where alerts.id = p_alert_id and alerts.user_id = current_user_id;
  if not found then raise exception 'Emergency alert not found'; end if;

  select coalesce(users.emergency_escalation_target, 'primary_contact')
    into target
  from public.users users where users.id = current_user_id;
  if target = 'official_999' and alert_record.status <> 'test_triggered' then
    return false;
  end if;

  select contacts.* into primary_contact
  from public.contacts contacts
  where contacts.user_id = current_user_id
    and contacts.is_primary
    and contacts.phone_verified_at is not null
    and btrim(coalesce(contacts.phone, '')) <> ''
  order by contacts.id
  limit 1;
  if not found then raise exception 'Add and verify a primary trusted contact first'; end if;

  select locations.* into location_record
  from public.locations locations
  where locations.alert_id = p_alert_id::text
  order by locations.timestamp desc
  limit 1;

  if alert_record.status = 'test_triggered' then
    message_body := 'TEST - Emergency alert from EthernaCare. This is a test after three check-in reminders. No real emergency alert was sent and 999 was not contacted.';
  else
    message_body := 'Emergency alert from EthernaCare. The user may need help. Please contact them immediately.' ||
      case when location_record.id is null
        then E'\nLocation: unavailable. Please call the user immediately and contact emergency services when necessary.'
        else E'\nLocation: https://maps.google.com/?q=' || location_record.latitude::text || ',' || location_record.longitude::text
      end;
  end if;

  insert into public.emergency_delivery_outbox (
    alert_id, user_id, contact_name, contact_phone, message_body,
    delivery_key, status, attempt_count
  ) values (
    p_alert_id::text, current_user_id, primary_contact.name,
    primary_contact.phone, message_body,
    'emergency:' || p_alert_id::text || ':' || primary_contact.id::text,
    'pending', 0
  ) on conflict (delivery_key) where delivery_key is not null do nothing;
  get diagnostics inserted_count = row_count;
  return inserted_count > 0 or exists (
    select 1 from public.emergency_delivery_outbox outbox
    where outbox.delivery_key = 'emergency:' || p_alert_id::text || ':' || primary_contact.id::text
  );
end;
$$;

create or replace function public.queue_current_user_primary_test_sms()
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  primary_contact public.contacts%rowtype;
  minute_key bigint := floor(extract(epoch from now()) / 60)::bigint;
begin
  if current_user_id is null then raise exception 'Authentication required'; end if;
  select contacts.* into primary_contact
  from public.contacts contacts
  where contacts.user_id = current_user_id and contacts.is_primary
    and contacts.phone_verified_at is not null
    and btrim(coalesce(contacts.phone, '')) <> ''
  order by contacts.id limit 1;
  if not found then return false; end if;

  insert into public.emergency_delivery_outbox (
    alert_id, user_id, contact_name, contact_phone, message_body,
    delivery_key, status, attempt_count
  ) values (
    'test-contact-' || current_user_id::text || '-' || minute_key::text,
    current_user_id, primary_contact.name, primary_contact.phone,
    'TEST message from EthernaCare. This is only a test of the emergency SMS flow. No emergency alert has been triggered.',
    'test-contact-sms:' || current_user_id::text || ':' || minute_key::text,
    'pending', 0
  ) on conflict (delivery_key) where delivery_key is not null do nothing;
  return true;
end;
$$;

create or replace function public.queue_current_user_inactivity_sms(
  p_last_checkin timestamptz,
  p_test_mode boolean default false
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  profile public.users%rowtype;
  monitor public.inactivity_monitor_status%rowtype;
  minute_key bigint := floor(extract(epoch from now()) / 60)::bigint;
  heartbeat_key bigint := extract(epoch from p_last_checkin)::bigint;
  message_body text;
begin
  if current_user_id is null then raise exception 'Authentication required'; end if;
  select users.* into profile from public.users users where users.id = current_user_id;
  if profile.phone_verified_at is null or btrim(coalesce(profile.phone, '')) = '' then
    raise exception 'Add and verify your phone number before SMS reminders can be sent';
  end if;

  if not p_test_mode then
    select status.* into monitor
    from public.inactivity_monitor_status status
    where status.user_id = current_user_id;
    if not found or monitor.missed_windows < 2
       or abs(extract(epoch from (monitor.last_checkin_at - p_last_checkin))) >= 1 then
      raise exception 'The inactivity reminder is not due';
    end if;
  end if;

  message_body := case when p_test_mode then 'TEST - ' else '' end ||
    'EthernaCare check-in reminder: you have missed two ' ||
    greatest(1, least(168, coalesce(profile.inactivity_threshold, 24)))::text || '-' ||
    case when coalesce(profile.inactivity_threshold, 24) = 1 then 'hour' else 'hours' end ||
    ' check-in windows. Open EthernaCare and tap Oren now. If inactivity continues, your configured emergency escalation may notify your primary trusted contact.';

  insert into public.emergency_delivery_outbox (
    alert_id, user_id, contact_name, contact_phone, message_body,
    delivery_key, status, attempt_count
  ) values (
    'inactivity-user-' || current_user_id::text || '-' || heartbeat_key::text,
    current_user_id, coalesce(nullif(btrim(profile.name), ''), 'EthernaCare user'),
    profile.phone, message_body,
    case when p_test_mode
      then 'test-user-sms:' || current_user_id::text || ':' || minute_key::text
      else 'inactivity-user:' || current_user_id::text || ':' || heartbeat_key::text
    end,
    'pending', 0
  ) on conflict (delivery_key) where delivery_key is not null do nothing;
  return true;
end;
$$;

revoke all on function public.create_current_user_emergency_alert(text),
  public.attach_current_user_alert_location(uuid, double precision, double precision),
  public.queue_current_user_emergency_sms(uuid),
  public.queue_current_user_primary_test_sms(),
  public.queue_current_user_inactivity_sms(timestamptz, boolean)
from public, anon, authenticated;

grant execute on function public.create_current_user_emergency_alert(text),
  public.attach_current_user_alert_location(uuid, double precision, double precision),
  public.queue_current_user_emergency_sms(uuid),
  public.queue_current_user_primary_test_sms(),
  public.queue_current_user_inactivity_sms(timestamptz, boolean)
to authenticated;

drop policy if exists "checkins_insert_own" on public.checkins;
drop policy if exists "alerts_insert_own" on public.emergency_alerts;
drop policy if exists "locations_insert_own" on public.locations;
drop policy if exists "outbox_insert_own" on public.emergency_delivery_outbox;

revoke insert on public.checkins, public.emergency_alerts, public.locations,
  public.emergency_delivery_outbox from authenticated;

-- Mirror the remaining planning and contact rules at the database boundary.
create or replace function public.enforce_contact_business_rules()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  normalized_phone text := regexp_replace(coalesce(new.phone, ''), '[^0-9]', '', 'g');
begin
  if char_length(btrim(coalesce(new.name, ''))) not between 2 and 50 then
    raise exception 'Contact name must contain 2 to 50 characters';
  end if;
  if char_length(normalized_phone) not between 8 and 15 then
    raise exception 'Contact phone must contain 8 to 15 digits';
  end if;
  if char_length(btrim(coalesce(new.relationship, ''))) not between 2 and 30 then
    raise exception 'Contact relationship must contain 2 to 30 characters';
  end if;
  if char_length(btrim(coalesce(new.address, ''))) not between 1 and 200 then
    raise exception 'Contact address must contain 1 to 200 characters';
  end if;
  if char_length(btrim(coalesce(new.address_state, ''))) not between 1 and 80
     or char_length(btrim(coalesce(new.address_region, ''))) not between 1 and 80 then
    raise exception 'Contact state and region are required and must not exceed 80 characters';
  end if;
  if exists (
    select 1 from public.contacts contacts
    where contacts.user_id = new.user_id
      and regexp_replace(coalesce(contacts.phone, ''), '[^0-9]', '', 'g') = normalized_phone
      and (tg_op = 'INSERT' or contacts.id is distinct from new.id)
  ) then
    raise exception 'This phone number is already an emergency contact';
  end if;
  if tg_op = 'INSERT' and (
    select count(*) from public.contacts contacts where contacts.user_id = new.user_id
  ) >= 5 then
    raise exception 'A user can have at most 5 emergency contacts';
  end if;
  return new;
end;
$$;

drop trigger if exists contacts_business_rules_before_write on public.contacts;
create trigger contacts_business_rules_before_write
before insert or update of name, relationship, phone, address, address_state, address_region
on public.contacts
for each row execute function public.enforce_contact_business_rules();

create table if not exists public.legacy_notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  content text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.legacy_notes
  drop constraint if exists legacy_notes_title_length_check,
  drop constraint if exists legacy_notes_content_length_check;
alter table public.legacy_notes
  add constraint legacy_notes_title_length_check
    check (char_length(btrim(title)) between 2 and 80) not valid,
  add constraint legacy_notes_content_length_check
    check (char_length(btrim(content)) between 2 and 1000) not valid;

create or replace function public.reject_legacy_note_secrets()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  note_text text := coalesce(new.title, '') || E'\n' || coalesce(new.content, '');
begin
  if note_text ~* '(^|[^a-z0-9_])(password|passcode|pin|otp|one[- ]?time password|api[- _]?key|access[- _]?token|secret[- _]?key|private[- _]?key|seed[- _]?phrase|recovery[- _]?phrase|cvv|security[- _]?code)([^a-z0-9_]|$)'
     or note_text ~* '-----BEGIN [A-Z ]*PRIVATE KEY-----'
     or note_text ~* '(^|[^a-z0-9_-])sk-[a-z0-9_-]{16,}([^a-z0-9_-]|$)'
     or note_text ~* '(^|[^a-z0-9_-])eyJ[a-z0-9_-]{20,}\.[a-z0-9_-]{10,}' then
    raise exception 'Legacy Notes must not contain passwords, PINs, OTPs, recovery phrases, API keys, access tokens, or security codes';
  end if;
  return new;
end;
$$;

drop trigger if exists legacy_notes_reject_secrets_before_write on public.legacy_notes;
create trigger legacy_notes_reject_secrets_before_write
before insert or update of title, content on public.legacy_notes
for each row execute function public.reject_legacy_note_secrets();

create table if not exists public.funeral_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  religion text not null default '',
  service_type text not null default '',
  venue text not null default '',
  notes text not null default '',
  authorized_contact text not null default '',
  updated_at timestamptz not null default now()
);

alter table public.funeral_preferences
  drop constraint if exists funeral_preferences_religion_check,
  drop constraint if exists funeral_preferences_service_type_check,
  drop constraint if exists funeral_preferences_text_length_check;
alter table public.funeral_preferences
  add constraint funeral_preferences_religion_check check (religion in (
    '', 'Islam', 'Buddhism', 'Christianity', 'Hinduism', 'Sikhism', 'Taoism',
    'Traditional or folk beliefs', 'No religion or secular',
    'Other or prefer not to say'
  )) not valid,
  add constraint funeral_preferences_service_type_check check (service_type in (
    '', 'Burial', 'Cremation', 'Memorial service', 'Religious funeral service',
    'Wake or visitation', 'Green or natural burial', 'Repatriation', 'Not decided'
  )) not valid,
  add constraint funeral_preferences_text_length_check check (
    char_length(btrim(venue)) <= 100 and
    char_length(btrim(notes)) <= 500 and
    char_length(btrim(authorized_contact)) <= 100
  ) not valid;

create or replace function public.enforce_authorized_funeral_contact()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if btrim(coalesce(new.authorized_contact, '')) <> '' and not exists (
    select 1
    from public.contacts contacts
    where contacts.user_id = new.user_id
      and new.authorized_contact in (
        contacts.name,
        contacts.name || ' - ' || contacts.phone
      )
  ) then
    raise exception 'Choose an authorized contact from your trusted contacts';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists funeral_preferences_validate_before_write
on public.funeral_preferences;
create trigger funeral_preferences_validate_before_write
before insert or update on public.funeral_preferences
for each row execute function public.enforce_authorized_funeral_contact();

alter table public.documents
  drop constraint if exists documents_name_length_check,
  drop constraint if exists documents_storage_owner_check;
alter table public.documents
  add constraint documents_name_length_check
    check (char_length(btrim(name)) between 1 and 180) not valid,
  add constraint documents_storage_owner_check
    check (storage_path like user_id::text || '/%') not valid;

notify pgrst, 'reload schema';
