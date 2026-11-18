-- =============================================================================
-- Sentinel (BioMap Leyte) - MVP database schema
-- Version : v1.0.0 (initial full snapshot)
-- Target  : Supabase PostgreSQL 15+ with PostGIS and RLS
-- Source  : business-logic-v1.1.md
--
-- Idempotent: safe to run repeatedly in the Supabase SQL editor.
--
-- Conventions
--   * Every table has a server-only `id` (bigint identity) used for indexing
--     only. It is never exposed to clients and never used as a foreign key.
--   * Every table has an `<entity>_uuid` column. The local (Android Room) and
--     server databases both use these `*_uuid` columns as foreign keys.
--   * Versioning: forward migrations bump the patch (v1.0.0 -> v1.0.1 -> ...);
--     full snapshots exported from Supabase bump the minor (v1.0.0 -> v1.1.0).
--   * All writes go through the API (sentinel-api) using the service role.
--     RLS is defense in depth: signed-in users can read only their own rows,
--     and anonymous users can read only Taxa and Privacy Notices.
-- =============================================================================

set search_path = public, extensions;

-- ---------------------------------------------------------------------------
-- 0. Extensions
-- ---------------------------------------------------------------------------
create extension if not exists postgis with schema extensions;

-- ---------------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------------

-- 1.1 privacy_notices: versioned Privacy Notice (RA 10173) --------------------
create table if not exists public.privacy_notices (
  id            bigint generated always as identity primary key,
  notice_uuid   uuid not null unique default gen_random_uuid(),
  version       text not null unique,
  url           text not null,                 -- where the notice text is published
  effective_at  timestamptz not null default now(),
  created_at    timestamptz not null default now()
);

-- 1.2 profiles ---------------------------------------------------------------
-- Created automatically on first Google Sign-In (see section 6). Consent
-- columns stay NULL until the Consent onboarding is completed.
create table if not exists public.profiles (
  id                          bigint generated always as identity primary key,
  profile_uuid                uuid not null unique
                                references auth.users (id) on delete cascade,
  display_name                text not null,
  role                        text not null default 'contributor'
                                check (role in ('contributor', 'reviewer', 'admin')),
  public_attribution_enabled  boolean not null default true,
  consent_notice_uuid         uuid
                                references public.privacy_notices (notice_uuid),
  consent_given_at            timestamptz,
  license_accepted_at         timestamptz,     -- CC BY-NC 4.0
  created_at                  timestamptz not null default now(),
  updated_at                  timestamptz not null default now(),
  -- Consent is recorded as a whole: notice version, time, and license together.
  constraint profiles_consent_complete_chk check (
    (consent_notice_uuid is null and consent_given_at is null and license_accepted_at is null)
    or
    (consent_notice_uuid is not null and consent_given_at is not null and license_accepted_at is not null)
  )
);

-- 1.3 taxa (seeded from CSV via SQL) -----------------------------------------
create table if not exists public.taxa (
  id                    bigint generated always as identity primary key,
  taxon_uuid            uuid not null unique default gen_random_uuid(),
  common_name           text not null,
  scientific_name       text,
  category              text not null
                          check (category in ('bird','mammal','reptile','amphibian','insect','other')),
  taxonomic_rank        text not null,
  is_sensitive_default  boolean not null default false,
  reference_source      text,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

-- Lets the CSV seed use ON CONFLICT and be re-run safely.
create unique index if not exists taxa_name_uq
  on public.taxa (common_name, (coalesce(scientific_name, '')));

-- 1.4 observations -----------------------------------------------------------
create table if not exists public.observations (
  id                       bigint generated always as identity primary key,
  observation_uuid         uuid not null unique default gen_random_uuid(),
  -- NULL only after the Contributor's erasure request: approved Observations
  -- are kept and shown as "Anonymous Contributor".
  contributor_uuid         uuid
                             references public.profiles (profile_uuid) on delete set null,
  idempotency_key          uuid,
  taxon_uuid               uuid
                             references public.taxa (taxon_uuid) on delete restrict,
  claimed_common_name      text,
  claimed_scientific_name  text,
  wildlife_category        text not null
                             check (wildlife_category in ('bird','mammal','reptile','amphibian','insect','other')),
  observed_at              timestamptz not null,
  description              text,
  habitat_notes            text,
  behavior_notes           text,
  exact_location           geography(Point, 4326) not null,
  location_accuracy_m      numeric
                             check (location_accuracy_m is null or location_accuracy_m >= 0),
  is_sensitive             boolean not null default false,
  public_location          geography(Point, 4326),         -- computed by trigger
  location_precision       text not null default 'exact'
                             check (location_precision in ('exact', 'grid_5km')),
  status                   text not null default 'submitted'
                             check (status in ('submitted','under_review','needs_changes',
                                               'approved','rejected','withdrawn')),
  claimed_by_uuid          uuid
                             references public.profiles (profile_uuid) on delete set null,
  submitted_at             timestamptz not null default now(),
  status_changed_at        timestamptz not null default now(),   -- drives the 90-day purge
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now(),
  -- No claim while waiting in the queue, returned for changes, or withdrawn.
  constraint observations_claim_state_chk
    check (status not in ('submitted', 'needs_changes', 'withdrawn') or claimed_by_uuid is null),
  -- Approval requires a Reviewer-confirmed Taxon.
  constraint observations_approved_taxon_chk
    check (status <> 'approved' or taxon_uuid is not null),
  -- A Reviewer cannot claim their own Observation.
  constraint observations_no_self_claim_chk
    check (claimed_by_uuid is null or contributor_uuid is null or claimed_by_uuid <> contributor_uuid)
);

-- Idempotent create: a replayed (contributor, key) pair maps to one row.
create unique index if not exists observations_idempotency_uq
  on public.observations (contributor_uuid, idempotency_key)
  where idempotency_key is not null;

-- 1.5 observation_media ------------------------------------------------------
-- A row is created when the API issues a signed upload URL (observation_uuid
-- NULL), then attached when the Observation is created. Unattached rows older
-- than 24 hours are purged.
create table if not exists public.observation_media (
  id                bigint generated always as identity primary key,
  media_uuid        uuid not null unique default gen_random_uuid(),
  observation_uuid  uuid
                      references public.observations (observation_uuid) on delete cascade,
  uploader_uuid     uuid
                      references public.profiles (profile_uuid) on delete set null,
  storage_path      text not null unique,          -- private bucket
  file_type         text not null
                      check (file_type in ('image/jpeg', 'image/png', 'image/webp')),
  file_size         integer not null
                      check (file_size > 0 and file_size <= 10485760),   -- <= 10 MB
  caption           text,
  exif_stripped_at  timestamptz,
  attached_at       timestamptz,
  created_at        timestamptz not null default now(),
  constraint observation_media_attach_chk
    check ((observation_uuid is null) = (attached_at is null))
);

-- 1.6 ai_analysis ------------------------------------------------------------
create table if not exists public.ai_analysis (
  id                 bigint generated always as identity primary key,
  analysis_uuid      uuid not null unique default gen_random_uuid(),
  observation_uuid   uuid not null
                       references public.observations (observation_uuid) on delete cascade,
  provider           text not null default 'gemini',
  model              text not null default 'gemini-2.5-flash',
  analysis_type      text not null default 'species_suggestion'
                       check (analysis_type in ('species_suggestion')),
  structured_result  jsonb,
  status             text not null default 'pending'
                       check (status in ('pending', 'processing', 'completed', 'failed')),
  started_at         timestamptz,
  error_message      text,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  -- One analysis per Observation and type; a retry re-queues the same row.
  constraint ai_analysis_obs_type_uq unique (observation_uuid, analysis_type)
);

-- 1.7 review_events (immutable) ---------------------------------------------
create table if not exists public.review_events (
  id                bigint generated always as identity primary key,
  event_uuid        uuid not null unique default gen_random_uuid(),
  observation_uuid  uuid not null
                      references public.observations (observation_uuid) on delete cascade,
  reviewer_uuid     uuid
                      references public.profiles (profile_uuid) on delete set null,
  action            text not null
                      check (action in ('claim','unclaim','approve','reject','request_changes',
                                        'flag_sensitive','unflag_sensitive')),
  reason            text,
  corrections       jsonb,
  previous_status   text,
  new_status        text,
  created_at        timestamptz not null default now()
);

-- 1.8 audit_logs (immutable; identifiers only, never Observation content) ----
create table if not exists public.audit_logs (
  id           bigint generated always as identity primary key,
  audit_uuid   uuid not null unique default gen_random_uuid(),
  actor_uuid   uuid
                 references public.profiles (profile_uuid) on delete set null,
  action       text not null,
  entity_type  text not null,
  entity_uuid  uuid,
  created_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 2. Indexes
-- ---------------------------------------------------------------------------
create index if not exists observations_public_location_gix
  on public.observations using gist (public_location);
create index if not exists observations_exact_location_gix
  on public.observations using gist (exact_location);
create index if not exists observations_status_observed_cat_idx
  on public.observations (status, observed_at, wildlife_category);
create index if not exists observations_contributor_idx
  on public.observations (contributor_uuid);
create index if not exists observations_taxon_idx
  on public.observations (taxon_uuid);
create index if not exists observations_review_queue_idx
  on public.observations (submitted_at)
  where status in ('submitted', 'under_review');
create index if not exists observations_purge_idx
  on public.observations (status_changed_at)
  where status in ('rejected', 'withdrawn');
create index if not exists observation_media_obs_idx
  on public.observation_media (observation_uuid);
create index if not exists observation_media_unattached_idx
  on public.observation_media (created_at)
  where observation_uuid is null;
create index if not exists ai_analysis_status_idx
  on public.ai_analysis (status, created_at);
create index if not exists review_events_obs_idx
  on public.review_events (observation_uuid);
create index if not exists audit_logs_entity_idx
  on public.audit_logs (entity_type, entity_uuid);
create index if not exists audit_logs_created_idx
  on public.audit_logs (created_at);

-- ---------------------------------------------------------------------------
-- 3. Generic trigger functions
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create or replace function public.track_status_change()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.status is distinct from old.status then
    new.status_changed_at := now();
  end if;
  return new;
end;
$$;

-- Immutable tables block direct UPDATE/DELETE. Allowed exceptions:
--   * foreign-key actions (cascade / set null), which run at trigger depth > 1;
--   * the retention purge, which sets app.retention_purge = 'on'.
create or replace function public.prevent_direct_mutation()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if pg_trigger_depth() > 1
     or coalesce(current_setting('app.retention_purge', true), '') = 'on' then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;
  raise exception '% is immutable; % is not allowed', tg_table_name, tg_op;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists taxa_set_updated_at on public.taxa;
create trigger taxa_set_updated_at before update on public.taxa
  for each row execute function public.set_updated_at();

drop trigger if exists observations_set_updated_at on public.observations;
create trigger observations_set_updated_at before update on public.observations
  for each row execute function public.set_updated_at();

drop trigger if exists observations_track_status on public.observations;
create trigger observations_track_status before update of status on public.observations
  for each row execute function public.track_status_change();

drop trigger if exists ai_analysis_set_updated_at on public.ai_analysis;
create trigger ai_analysis_set_updated_at before update on public.ai_analysis
  for each row execute function public.set_updated_at();

drop trigger if exists review_events_immutable on public.review_events;
create trigger review_events_immutable before update or delete on public.review_events
  for each row execute function public.prevent_direct_mutation();

drop trigger if exists audit_logs_immutable on public.audit_logs;
create trigger audit_logs_immutable before update or delete on public.audit_logs
  for each row execute function public.prevent_direct_mutation();

-- ---------------------------------------------------------------------------
-- 4. Location privacy (~5 km deterministic grid)
-- ---------------------------------------------------------------------------
-- Snap a point to the centroid of its 0.045-degree grid cell.
create or replace function public.snap_to_grid_5km(p geography)
returns geography
language sql
immutable
set search_path = public, extensions
as $$
  select st_setsrid(
           st_makepoint(
             (floor(st_x(p::geometry) / 0.045) + 0.5) * 0.045,
             (floor(st_y(p::geometry) / 0.045) + 0.5) * 0.045
           ),
           4326
         )::geography;
$$;

-- effective_sensitive = observation.is_sensitive OR taxon.is_sensitive_default
create or replace function public.compute_public_location()
returns trigger
language plpgsql
set search_path = public, extensions
as $$
declare
  v_taxon_sensitive boolean := false;
begin
  if new.taxon_uuid is not null then
    select t.is_sensitive_default into v_taxon_sensitive
      from public.taxa t
     where t.taxon_uuid = new.taxon_uuid;
  end if;

  if new.is_sensitive or coalesce(v_taxon_sensitive, false) then
    new.public_location    := public.snap_to_grid_5km(new.exact_location);
    new.location_precision := 'grid_5km';
  else
    new.public_location    := new.exact_location;
    new.location_precision := 'exact';
  end if;
  return new;
end;
$$;

drop trigger if exists observations_compute_public_location on public.observations;
create trigger observations_compute_public_location
  before insert or update of exact_location, is_sensitive, taxon_uuid
  on public.observations
  for each row execute function public.compute_public_location();

-- When a Taxon's default sensitivity changes, recompute its Observations.
-- Touching taxon_uuid re-fires the trigger above.
create or replace function public.recalc_observations_for_taxon()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  update public.observations
     set taxon_uuid = taxon_uuid
   where taxon_uuid = new.taxon_uuid;
  return new;
end;
$$;

drop trigger if exists taxa_sensitivity_changed on public.taxa;
create trigger taxa_sensitivity_changed
  after update of is_sensitive_default on public.taxa
  for each row
  when (old.is_sensitive_default is distinct from new.is_sensitive_default)
  execute function public.recalc_observations_for_taxon();

-- ---------------------------------------------------------------------------
-- 5. Consent (RA 10173)
-- ---------------------------------------------------------------------------
-- The current notice is the latest one already in effect.
create or replace function public.current_privacy_notice_uuid()
returns uuid
language sql
stable
set search_path = public
as $$
  select n.notice_uuid
    from public.privacy_notices n
   where n.effective_at <= now()
   order by n.effective_at desc, n.id desc
   limit 1;
$$;

create or replace function public.has_current_consent(p_profile uuid)
returns boolean
language sql
stable
set search_path = public
as $$
  select exists (
    select 1
      from public.profiles p
     where p.profile_uuid = p_profile
       and p.license_accepted_at is not null
       and p.consent_notice_uuid = public.current_privacy_notice_uuid()
  );
$$;

-- Defense in depth: no Observation is created without current Consent.
create or replace function public.require_contributor_consent()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if not public.has_current_consent(new.contributor_uuid) then
    raise exception 'Consent to the current Privacy Notice is required'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists observations_require_consent on public.observations;
create trigger observations_require_consent
  before insert on public.observations
  for each row execute function public.require_contributor_consent();

-- ---------------------------------------------------------------------------
-- 6. Profile on first sign-in
-- ---------------------------------------------------------------------------
-- The display name is a placeholder from the Google given name; the Consent
-- onboarding lets the user confirm or change it. The email is never used.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (profile_uuid, display_name)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'given_name', ''),
      nullif(split_part(coalesce(new.raw_user_meta_data ->> 'full_name', ''), ' ', 1), ''),
      'Contributor'
    )
  )
  on conflict (profile_uuid) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- 7. Reports (Administrators; small counts suppressed)
-- ---------------------------------------------------------------------------
-- Counts by status, category, and month (Asia/Manila) for Observations
-- observed between p_from and p_to (inclusive), plus total Contributors.
-- Any breakdown count below 5 is returned as '<5'.
create or replace function public.report_observation_counts(p_from date, p_to date)
returns table (dimension text, bucket text, observation_count text)
language sql
stable
security definer
set search_path = public
as $$
  with base as (
    select o.status,
           o.wildlife_category,
           to_char(o.observed_at at time zone 'Asia/Manila', 'YYYY-MM') as month
      from public.observations o
     where (o.observed_at at time zone 'Asia/Manila')::date between p_from and p_to
  ),
  breakdowns as (
    select 'status'::text as dimension, b.status as bucket, count(*) as n
      from base b group by b.status
    union all
    select 'category', b.wildlife_category, count(*)
      from base b group by b.wildlife_category
    union all
    select 'month', b.month, count(*)
      from base b group by b.month
  )
  select x.dimension,
         x.bucket,
         case when x.n < 5 then '<5' else x.n::text end
    from breakdowns x
  union all
  select 'total', 'contributors', count(*)::text
    from public.profiles p
   where p.role = 'contributor'
  order by 1, 2;
$$;

-- ---------------------------------------------------------------------------
-- 8. Retention purge and data-subject erasure
-- ---------------------------------------------------------------------------
-- Both functions return the Storage paths that the API must then delete from
-- the private bucket (Storage objects are removed through the Storage API).

-- Daily purge: rejected/withdrawn Observations after 90 days (with their
-- media, AI Analysis, and Review Events), unattached uploads after 24 hours,
-- Audit Logs after 1 year.
create or replace function public.run_retention_purge()
returns table (storage_path text)
language plpgsql
security definer
set search_path = public
as $$
#variable_conflict use_column
begin
  perform set_config('app.retention_purge', 'on', true);

  return query
    select m.storage_path
      from public.observation_media m
      join public.observations o on o.observation_uuid = m.observation_uuid
     where o.status in ('rejected', 'withdrawn')
       and o.status_changed_at < now() - interval '90 days';

  return query
    delete from public.observation_media m
     where m.observation_uuid is null
       and m.created_at < now() - interval '24 hours'
    returning m.storage_path;

  delete from public.observations o
   where o.status in ('rejected', 'withdrawn')
     and o.status_changed_at < now() - interval '90 days';

  delete from public.audit_logs a
   where a.created_at < now() - interval '1 year';

  perform set_config('app.retention_purge', 'off', true);
end;
$$;

-- Erasure request: approved Observations stay as "Anonymous Contributor";
-- everything else of the person is hard-deleted.
create or replace function public.erase_contributor(p_profile uuid)
returns table (storage_path text)
language plpgsql
security definer
set search_path = public
as $$
#variable_conflict use_column
begin
  -- Release any Observations this person had claimed as a Reviewer.
  update public.observations o
     set status = 'submitted', claimed_by_uuid = null
   where o.claimed_by_uuid = p_profile
     and o.status = 'under_review';

  return query
    select m.storage_path
      from public.observation_media m
      left join public.observations o on o.observation_uuid = m.observation_uuid
     where (o.contributor_uuid = p_profile and o.status <> 'approved')
        or (m.observation_uuid is null and m.uploader_uuid = p_profile);

  delete from public.observation_media m
   where m.observation_uuid is null
     and m.uploader_uuid = p_profile;

  delete from public.observations o
   where o.contributor_uuid = p_profile
     and o.status <> 'approved';

  -- Cascades to the profile; remaining references become NULL (anonymous).
  delete from auth.users u where u.id = p_profile;
end;
$$;

-- ---------------------------------------------------------------------------
-- 9. Row Level Security and privileges
-- ---------------------------------------------------------------------------
alter table public.privacy_notices    enable row level security;
alter table public.profiles           enable row level security;
alter table public.taxa               enable row level security;
alter table public.observations       enable row level security;
alter table public.observation_media  enable row level security;
alter table public.ai_analysis        enable row level security;
alter table public.review_events      enable row level security;
alter table public.audit_logs         enable row level security;

-- Start from no client access, then grant only what is needed.
revoke all on public.privacy_notices, public.profiles, public.taxa,
              public.observations, public.observation_media, public.ai_analysis,
              public.review_events, public.audit_logs
  from anon, authenticated;

grant select on public.privacy_notices, public.taxa to anon, authenticated;
grant select on public.profiles, public.observations,
                public.observation_media, public.ai_analysis
  to authenticated;
-- review_events and audit_logs: no client access (API and console only).

drop policy if exists privacy_notices_select_all on public.privacy_notices;
create policy privacy_notices_select_all on public.privacy_notices
  for select to anon, authenticated
  using (true);

drop policy if exists taxa_select_all on public.taxa;
create policy taxa_select_all on public.taxa
  for select to anon, authenticated
  using (true);

drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
  for select to authenticated
  using (profile_uuid = auth.uid());

drop policy if exists observations_select_own on public.observations;
create policy observations_select_own on public.observations
  for select to authenticated
  using (contributor_uuid = auth.uid());

drop policy if exists observation_media_select_own on public.observation_media;
create policy observation_media_select_own on public.observation_media
  for select to authenticated
  using (
    uploader_uuid = auth.uid()
    or exists (
      select 1 from public.observations o
       where o.observation_uuid = observation_media.observation_uuid
         and o.contributor_uuid = auth.uid()
    )
  );

drop policy if exists ai_analysis_select_own on public.ai_analysis;
create policy ai_analysis_select_own on public.ai_analysis
  for select to authenticated
  using (
    exists (
      select 1 from public.observations o
       where o.observation_uuid = ai_analysis.observation_uuid
         and o.contributor_uuid = auth.uid()
    )
  );

-- Privileged functions: API (service role) only.
revoke execute on function public.has_current_consent(uuid)                 from public, anon, authenticated;
revoke execute on function public.report_observation_counts(date, date)     from public, anon, authenticated;
revoke execute on function public.run_retention_purge()                     from public, anon, authenticated;
revoke execute on function public.erase_contributor(uuid)                   from public, anon, authenticated;
grant  execute on function public.has_current_consent(uuid)                 to service_role;
grant  execute on function public.report_observation_counts(date, date)     to service_role;
grant  execute on function public.run_retention_purge()                     to service_role;
grant  execute on function public.erase_contributor(uuid)                   to service_role;

-- ---------------------------------------------------------------------------
-- 10. Seed: initial Privacy Notice
-- ---------------------------------------------------------------------------
insert into public.privacy_notices (version, url, effective_at)
values ('1.0', '/privacy', '2026-11-01 00:00:00+08')
on conflict (version) do nothing;

-- =============================================================================
-- End of v1.0.0
-- =============================================================================
