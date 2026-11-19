-- =============================================================================
-- Sentinel (BioMap Leyte) - MVP database schema
-- Version : v1.0.0 (initial full snapshot)
-- Target  : Supabase PostgreSQL 15+ with PostGIS and RLS
-- Source  : business-logic-v1.1.md, following db-design-choices.md
--
-- Idempotent: safe to run repeatedly in the Supabase SQL editor.
--
-- Conventions (db-design-choices.md)
--   * Singular table names. `id bigint` is a server-only surrogate used for
--     indexing; it is never synced and never used as a foreign key.
--   * `uuid` is each row's global identity, minted by the creating client
--     (server-created tables default it). Relationships are `<parent>_uuid`
--     columns WITHOUT declared REFERENCES, so rows can sync in any order.
--   * Attribution: `created_by` (account uuid, stamped by the server from the
--     session, never accepted from a client), `created_at`, `updated_at`
--     (change column for last-write-wins), `archived_at` (soft delete).
--   * Closed vocabularies are Postgres enums.
--
-- Deliberate exceptions to soft delete (required by business-logic-v1.1):
--   * the daily retention purge hard-deletes old rejected/withdrawn
--     Observations, unattached uploads, and Audit Logs;
--   * an erasure request hard-deletes a person's non-approved data.
--
-- Versioning: forward migrations bump the patch (v1.0.0 -> v1.0.1 -> ...);
-- full snapshots exported from Supabase bump the minor (v1.0.0 -> v1.1.0).
-- =============================================================================

set search_path = public, extensions;

create extension if not exists postgis with schema extensions;

-- ---------------------------------------------------------------------------
-- 1. Enums (idempotent)
-- ---------------------------------------------------------------------------
do $$ begin
  create type public.user_role as enum ('contributor', 'reviewer', 'admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.wildlife_category as enum
    ('bird', 'mammal', 'reptile', 'amphibian', 'insect', 'other');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.observation_status as enum
    ('submitted', 'under_review', 'needs_changes', 'approved', 'rejected', 'withdrawn');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.location_precision as enum ('exact', 'grid_5km');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.media_file_type as enum ('image/jpeg', 'image/png', 'image/webp');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.ai_analysis_type as enum ('species_suggestion');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.ai_status as enum ('pending', 'processing', 'completed', 'failed');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.review_action as enum
    ('claim', 'unclaim', 'approve', 'reject', 'request_changes',
     'flag_sensitive', 'unflag_sensitive');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------
-- 2. Tables
-- ---------------------------------------------------------------------------

-- 2.1 privacy_notice: versioned Privacy Notice (RA 10173). Server-only. ------
create table if not exists public.privacy_notice (
  id            bigint generated always as identity not null,
  uuid          uuid not null unique default gen_random_uuid(),
  version       text not null unique,
  url           text not null,
  effective_at  timestamptz not null default now(),
  created_at    timestamptz not null default now(),
  constraint privacy_notice_pkey primary key (id)
);

-- 2.2 profile: one per account; `uuid` equals the auth account id. ------------
-- Created on first Google Sign-In (section 6). Consent columns stay NULL until
-- the Consent onboarding is completed.
create table if not exists public.profile (
  id                          bigint generated always as identity not null,
  uuid                        uuid not null unique,
  display_name                text not null,
  role                        public.user_role not null default 'contributor',
  public_attribution_enabled  boolean not null default true,
  consent_notice_uuid         uuid,             -- privacy_notice.uuid accepted
  consent_given_at            timestamptz,
  license_accepted_at         timestamptz,      -- CC BY-NC 4.0
  created_by                  uuid,
  created_at                  timestamptz not null default now(),
  updated_at                  timestamptz not null default now(),
  archived_at                 timestamptz,
  constraint profile_pkey primary key (id),
  -- Consent is recorded as a whole: notice version, time, and license together.
  constraint profile_consent_complete_chk check (
    (consent_notice_uuid is null and consent_given_at is null and license_accepted_at is null)
    or
    (consent_notice_uuid is not null and consent_given_at is not null and license_accepted_at is not null)
  )
);

-- 2.3 taxon: species list, seeded via SQL (no Admin UI). -----------------------
create table if not exists public.taxon (
  id                    bigint generated always as identity not null,
  uuid                  uuid not null unique default gen_random_uuid(),
  common_name           text not null,
  scientific_name       text,
  category              public.wildlife_category not null,
  taxonomic_rank        text not null,
  is_sensitive_default  boolean not null default false,
  reference_source      text,
  created_by            uuid,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  archived_at           timestamptz,
  constraint taxon_pkey primary key (id)
);

-- Names are unique among live rows only (archived history never blocks a new row).
-- Also lets the CSV seed use ON CONFLICT and be re-run safely.
create unique index if not exists idx_taxon_name_live
  on public.taxon (common_name, (coalesce(scientific_name, '')))
  where archived_at is null;

-- 2.4 observation ------------------------------------------------------------
-- `uuid` is minted by the capturing client (Web or an offline Android Draft),
-- so a replayed sync upserts the same row: no separate idempotency key needed.
-- `created_by` becomes NULL after the author's erasure request; approved
-- Observations stay and are shown as "Anonymous Contributor".
-- API push rule: the upsert's ON CONFLICT (uuid) ... WHERE must also require
-- observation.created_by = <session account>, or a client could overwrite
-- another person's Observation by sending its uuid.
create table if not exists public.observation (
  id                       bigint generated always as identity not null,
  uuid                     uuid not null unique,
  taxon_uuid               uuid,                -- Reviewer-confirmed Taxon
  claimed_common_name      text,                -- Contributor's claim, never authoritative
  claimed_scientific_name  text,
  wildlife_category        public.wildlife_category not null,
  observed_at              timestamptz not null,
  description              text,
  habitat_notes            text,
  behavior_notes           text,
  exact_location           geography(Point, 4326) not null,
  location_accuracy_m      numeric
                             check (location_accuracy_m is null or location_accuracy_m >= 0),
  is_sensitive             boolean not null default false,
  public_location          geography(Point, 4326),                 -- trigger-computed
  location_precision       public.location_precision not null default 'exact',
  status                   public.observation_status not null default 'submitted',
  claimed_by               uuid,                -- Reviewer's account uuid (server-stamped)
  submitted_at             timestamptz not null default now(),
  status_changed_at        timestamptz not null default now(),     -- server-only; drives the 90-day purge
  created_by               uuid,                -- author's account uuid (server-stamped)
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now(),
  archived_at              timestamptz,
  constraint observation_pkey primary key (id),
  -- No claim while queued, returned for changes, or withdrawn.
  constraint observation_claim_state_chk
    check (status not in ('submitted', 'needs_changes', 'withdrawn') or claimed_by is null),
  -- Approval requires a Reviewer-confirmed Taxon.
  constraint observation_approved_taxon_chk
    check (status <> 'approved' or taxon_uuid is not null),
  -- A Reviewer cannot claim their own Observation.
  constraint observation_no_self_claim_chk
    check (claimed_by is null or created_by is null or claimed_by <> created_by)
);

-- 2.5 observation_media ------------------------------------------------------
-- A row is created when the API issues a signed upload URL (observation_uuid
-- NULL) and attached when the Observation is created. Unattached rows older
-- than 24 hours are purged. Use a storage_path that does not contain the
-- uploader's id (for example observations/<media uuid>) so signed URLs never
-- reveal who uploaded a photo.
create table if not exists public.observation_media (
  id                bigint generated always as identity not null,
  uuid              uuid not null unique,
  observation_uuid  uuid,
  storage_path      text not null unique,             -- private bucket
  file_type         public.media_file_type not null,
  file_size         integer not null
                      check (file_size > 0 and file_size <= 10485760),   -- <= 10 MB
  caption           text,
  exif_stripped_at  timestamptz,
  attached_at       timestamptz,
  created_by        uuid,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  archived_at       timestamptz,
  constraint observation_media_pkey primary key (id),
  constraint observation_media_attach_chk
    check ((observation_uuid is null) = (attached_at is null))
);

-- 2.6 ai_analysis: server-only (written by the API worker). -------------------
create table if not exists public.ai_analysis (
  id                 bigint generated always as identity not null,
  uuid               uuid not null unique default gen_random_uuid(),
  observation_uuid   uuid not null,
  provider           text not null default 'gemini',
  model              text not null default 'gemini-2.5-flash',
  analysis_type      public.ai_analysis_type not null default 'species_suggestion',
  structured_result  jsonb,
  status             public.ai_status not null default 'pending',
  started_at         timestamptz,
  error_message      text,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  constraint ai_analysis_pkey primary key (id)
);

-- One analysis per Observation and type; a retry re-queues the same row.
create unique index if not exists idx_ai_analysis_obs_type
  on public.ai_analysis (observation_uuid, analysis_type);

-- 2.7 review_event: immutable decision history. Server-only. -------------------
create table if not exists public.review_event (
  id                bigint generated always as identity not null,
  uuid              uuid not null unique default gen_random_uuid(),
  observation_uuid  uuid not null,
  action            public.review_action not null,
  reason            text,
  corrections       jsonb,
  previous_status   public.observation_status,
  new_status        public.observation_status,
  created_by        uuid,                             -- the Reviewer (server-stamped)
  created_at        timestamptz not null default now(),
  constraint review_event_pkey primary key (id)
);

-- 2.8 audit_log: immutable; identifiers only, never Observation content. -------
create table if not exists public.audit_log (
  id           bigint generated always as identity not null,
  uuid         uuid not null unique default gen_random_uuid(),
  action       text not null,
  entity_type  text not null,
  entity_uuid  uuid,
  created_by   uuid,                                  -- the actor (server-stamped)
  created_at   timestamptz not null default now(),
  constraint audit_log_pkey primary key (id)
);

-- ---------------------------------------------------------------------------
-- 3. Indexes (every *_uuid lookup path is indexed)
-- ---------------------------------------------------------------------------
create index if not exists idx_observation_public_location
  on public.observation using gist (public_location);
create index if not exists idx_observation_exact_location
  on public.observation using gist (exact_location);
create index if not exists idx_observation_status_observed_cat
  on public.observation (status, observed_at, wildlife_category);
create index if not exists idx_observation_created_by
  on public.observation (created_by);
create index if not exists idx_observation_claimed_by
  on public.observation (claimed_by);
create index if not exists idx_observation_taxon
  on public.observation (taxon_uuid);
create index if not exists idx_observation_review_queue
  on public.observation (submitted_at)
  where status in ('submitted', 'under_review') and archived_at is null;
create index if not exists idx_observation_purge
  on public.observation (status_changed_at)
  where status in ('rejected', 'withdrawn');
create index if not exists idx_observation_media_observation
  on public.observation_media (observation_uuid);
create index if not exists idx_observation_media_created_by
  on public.observation_media (created_by);
create index if not exists idx_observation_media_unattached
  on public.observation_media (created_at)
  where observation_uuid is null;
create index if not exists idx_ai_analysis_status
  on public.ai_analysis (status, created_at);
create index if not exists idx_review_event_observation
  on public.review_event (observation_uuid);
create index if not exists idx_review_event_created_by
  on public.review_event (created_by);
create index if not exists idx_audit_log_entity
  on public.audit_log (entity_type, entity_uuid);
create index if not exists idx_audit_log_created_at
  on public.audit_log (created_at);

-- ---------------------------------------------------------------------------
-- 4. Generic trigger functions
-- ---------------------------------------------------------------------------

-- Change column: a client push supplies its own updated_at and keeps it; any
-- other write (API or manual edit on the server) that leaves it unchanged gets
-- bumped to now(), so a stale client push cannot silently overwrite it.
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.updated_at is not distinct from old.updated_at then
    new.updated_at := now();
  end if;
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

-- Immutable tables block direct UPDATE/DELETE. The only exceptions are the
-- retention purge and erasure functions, which set app.retention_purge = 'on'
-- for their own transaction.
create or replace function public.prevent_direct_mutation()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if coalesce(current_setting('app.retention_purge', true), '') = 'on' then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;
  raise exception '% is immutable; % is not allowed', tg_table_name, tg_op;
end;
$$;

drop trigger if exists trg_profile_touch on public.profile;
create trigger trg_profile_touch before update on public.profile
  for each row execute function public.touch_updated_at();

drop trigger if exists trg_taxon_touch on public.taxon;
create trigger trg_taxon_touch before update on public.taxon
  for each row execute function public.touch_updated_at();

drop trigger if exists trg_observation_touch on public.observation;
create trigger trg_observation_touch before update on public.observation
  for each row execute function public.touch_updated_at();

drop trigger if exists trg_observation_media_touch on public.observation_media;
create trigger trg_observation_media_touch before update on public.observation_media
  for each row execute function public.touch_updated_at();

drop trigger if exists trg_ai_analysis_touch on public.ai_analysis;
create trigger trg_ai_analysis_touch before update on public.ai_analysis
  for each row execute function public.touch_updated_at();

drop trigger if exists trg_observation_status on public.observation;
create trigger trg_observation_status before update of status on public.observation
  for each row execute function public.track_status_change();

drop trigger if exists trg_review_event_immutable on public.review_event;
create trigger trg_review_event_immutable before update or delete on public.review_event
  for each row execute function public.prevent_direct_mutation();

drop trigger if exists trg_audit_log_immutable on public.audit_log;
create trigger trg_audit_log_immutable before update or delete on public.audit_log
  for each row execute function public.prevent_direct_mutation();

-- ---------------------------------------------------------------------------
-- 5. Location privacy (~5 km deterministic grid)
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
      from public.taxon t
     where t.uuid = new.taxon_uuid;
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

drop trigger if exists trg_observation_public_location on public.observation;
create trigger trg_observation_public_location
  before insert or update of exact_location, is_sensitive, taxon_uuid
  on public.observation
  for each row execute function public.compute_public_location();

-- When a Taxon's default sensitivity changes, recompute its Observations.
-- Touching taxon_uuid re-fires the trigger above and bumps updated_at, so
-- clients pull the new Public Location.
create or replace function public.recalc_observations_for_taxon()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  update public.observation
     set taxon_uuid = taxon_uuid
   where taxon_uuid = new.uuid;
  return new;
end;
$$;

drop trigger if exists trg_taxon_sensitivity on public.taxon;
create trigger trg_taxon_sensitivity
  after update of is_sensitive_default on public.taxon
  for each row
  when (old.is_sensitive_default is distinct from new.is_sensitive_default)
  execute function public.recalc_observations_for_taxon();

-- ---------------------------------------------------------------------------
-- 6. Consent (RA 10173) and profile creation
-- ---------------------------------------------------------------------------
create or replace function public.current_privacy_notice_uuid()
returns uuid
language sql
stable
set search_path = public
as $$
  select n.uuid
    from public.privacy_notice n
   where n.effective_at <= now()
   order by n.effective_at desc, n.id desc
   limit 1;
$$;

create or replace function public.has_current_consent(p_account uuid)
returns boolean
language sql
stable
set search_path = public
as $$
  select exists (
    select 1
      from public.profile p
     where p.uuid = p_account
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
  if not public.has_current_consent(new.created_by) then
    raise exception 'Consent to the current Privacy Notice is required'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_observation_consent on public.observation;
create trigger trg_observation_consent
  before insert on public.observation
  for each row execute function public.require_contributor_consent();

-- First Google Sign-In: create the profile with a placeholder display name
-- from the Google given name. The Consent onboarding lets the user confirm or
-- change it. The email is never copied.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profile (uuid, display_name, created_by)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'given_name', ''),
      nullif(split_part(coalesce(new.raw_user_meta_data ->> 'full_name', ''), ' ', 1), ''),
      'Contributor'
    ),
    new.id
  )
  on conflict (uuid) do nothing;
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
-- Counts of live Observations by status, category, and month (Asia/Manila)
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
    select o.status::text            as status,
           o.wildlife_category::text as category,
           to_char(o.observed_at at time zone 'Asia/Manila', 'YYYY-MM') as month
      from public.observation o
     where o.archived_at is null
       and (o.observed_at at time zone 'Asia/Manila')::date between p_from and p_to
  ),
  breakdowns as (
    select 'status'::text as dimension, b.status as bucket, count(*) as n
      from base b group by b.status
    union all
    select 'category', b.category, count(*) from base b group by b.category
    union all
    select 'month', b.month, count(*) from base b group by b.month
  )
  select x.dimension,
         x.bucket,
         case when x.n < 5 then '<5' else x.n::text end
    from breakdowns x
  union all
  select 'total', 'contributors', count(*)::text
    from public.profile p
   where p.role = 'contributor' and p.archived_at is null
  order by 1, 2;
$$;

-- ---------------------------------------------------------------------------
-- 8. Retention purge and data-subject erasure
-- ---------------------------------------------------------------------------
-- Both functions return the Storage paths the API must then delete from the
-- private bucket (Storage objects are removed through the Storage API).

-- Daily purge: rejected/withdrawn Observations after 90 days (with their
-- media, AI Analysis, and Review Events), uploads never attached after 24
-- hours, and Audit Logs after 1 year.
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
  with doomed as (
    select o.uuid
      from public.observation o
     where o.status in ('rejected', 'withdrawn')
       and o.status_changed_at < now() - interval '90 days'
  ),
  del_events as (
    delete from public.review_event e
     using doomed d where e.observation_uuid = d.uuid
    returning 1
  ),
  del_ai as (
    delete from public.ai_analysis a
     using doomed d where a.observation_uuid = d.uuid
    returning 1
  ),
  del_media as (
    delete from public.observation_media m
     where m.observation_uuid in (select d.uuid from doomed d)
        or (m.observation_uuid is null and m.created_at < now() - interval '24 hours')
    returning m.storage_path
  ),
  del_obs as (
    delete from public.observation o
     using doomed d where o.uuid = d.uuid
    returning 1
  ),
  del_audit as (
    delete from public.audit_log a
     where a.created_at < now() - interval '1 year'
    returning 1
  )
  select x.storage_path from del_media x;

  perform set_config('app.retention_purge', 'off', true);
end;
$$;

-- Erasure request: approved Observations stay as "Anonymous Contributor";
-- everything else of the person is hard-deleted.
create or replace function public.erase_contributor(p_account uuid)
returns table (storage_path text)
language plpgsql
security definer
set search_path = public
as $$
#variable_conflict use_column
begin
  perform set_config('app.retention_purge', 'on', true);

  -- Release Observations this person had claimed as a Reviewer.
  update public.observation o
     set status = 'submitted', claimed_by = null
   where o.claimed_by = p_account
     and o.status = 'under_review';

  return query
  with doomed as (
    select o.uuid
      from public.observation o
     where o.created_by = p_account
       and o.status <> 'approved'
  ),
  del_events as (
    delete from public.review_event e
     using doomed d where e.observation_uuid = d.uuid
    returning 1
  ),
  del_ai as (
    delete from public.ai_analysis a
     using doomed d where a.observation_uuid = d.uuid
    returning 1
  ),
  del_media as (
    delete from public.observation_media m
     where m.observation_uuid in (select d.uuid from doomed d)
        or (m.observation_uuid is null and m.created_by = p_account)
    returning m.storage_path
  ),
  del_obs as (
    delete from public.observation o
     using doomed d where o.uuid = d.uuid
    returning 1
  )
  select x.storage_path from del_media x;

  -- What remains (approved Observations and history) loses the person's id.
  update public.observation        set created_by = null where created_by = p_account;
  update public.observation        set claimed_by = null where claimed_by = p_account;
  update public.observation_media  set created_by = null where created_by = p_account;
  update public.review_event       set created_by = null where created_by = p_account;
  update public.audit_log          set created_by = null where created_by = p_account;

  delete from public.profile p where p.uuid = p_account;
  delete from auth.users u where u.id = p_account;

  perform set_config('app.retention_purge', 'off', true);
end;
$$;

-- ---------------------------------------------------------------------------
-- 9. Row Level Security and privileges
-- ---------------------------------------------------------------------------
-- Defense in depth. The API connects with the service role and enforces RBAC;
-- all writes go through it. Public reads also go through the API, so
-- `exact_location` is never reachable by anon, and Reviewers read other
-- people's data only through the API (no per-user trails).
alter table public.privacy_notice     enable row level security;
alter table public.profile            enable row level security;
alter table public.taxon              enable row level security;
alter table public.observation        enable row level security;
alter table public.observation_media  enable row level security;
alter table public.ai_analysis        enable row level security;
alter table public.review_event       enable row level security;
alter table public.audit_log          enable row level security;

revoke all on public.privacy_notice, public.profile, public.taxon,
              public.observation, public.observation_media, public.ai_analysis,
              public.review_event, public.audit_log
  from anon, authenticated;

grant select on public.privacy_notice, public.taxon to anon, authenticated;
grant select on public.profile, public.observation,
                public.observation_media, public.ai_analysis
  to authenticated;
-- review_event and audit_log: no client access (API and console only).

drop policy if exists privacy_notice_select_all on public.privacy_notice;
create policy privacy_notice_select_all on public.privacy_notice
  for select to anon, authenticated
  using (true);

drop policy if exists taxon_select_all on public.taxon;
create policy taxon_select_all on public.taxon
  for select to anon, authenticated
  using (true);

drop policy if exists profile_select_own on public.profile;
create policy profile_select_own on public.profile
  for select to authenticated
  using (uuid = auth.uid());

drop policy if exists observation_select_own on public.observation;
create policy observation_select_own on public.observation
  for select to authenticated
  using (created_by = auth.uid());

drop policy if exists observation_media_select_own on public.observation_media;
create policy observation_media_select_own on public.observation_media
  for select to authenticated
  using (
    created_by = auth.uid()
    or exists (
      select 1 from public.observation o
       where o.uuid = observation_media.observation_uuid
         and o.created_by = auth.uid()
    )
  );

drop policy if exists ai_analysis_select_own on public.ai_analysis;
create policy ai_analysis_select_own on public.ai_analysis
  for select to authenticated
  using (
    exists (
      select 1 from public.observation o
       where o.uuid = ai_analysis.observation_uuid
         and o.created_by = auth.uid()
    )
  );

-- Privileged functions: API (service role) only.
revoke execute on function public.has_current_consent(uuid)              from public, anon, authenticated;
revoke execute on function public.report_observation_counts(date, date) from public, anon, authenticated;
revoke execute on function public.run_retention_purge()                  from public, anon, authenticated;
revoke execute on function public.erase_contributor(uuid)                from public, anon, authenticated;
grant  execute on function public.has_current_consent(uuid)              to service_role;
grant  execute on function public.report_observation_counts(date, date) to service_role;
grant  execute on function public.run_retention_purge()                  to service_role;
grant  execute on function public.erase_contributor(uuid)                to service_role;

-- ---------------------------------------------------------------------------
-- 10. Seed: initial Privacy Notice
-- ---------------------------------------------------------------------------
insert into public.privacy_notice (version, url, effective_at)
values ('1.0', '/privacy', '2026-11-01 00:00:00+08')
on conflict (version) do nothing;

-- =============================================================================
-- End of v1.0.0
-- =============================================================================
