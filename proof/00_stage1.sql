-- =====================================================================
-- PROOF · STAGE 1 — recreate the LIVE pre-protect shape (the vulnerable
-- state). Mirrors Supabase: a kv table, an `anon` role that the
-- publishable key maps to, and the wide-open grants PostgREST exposes.
-- Plus a faithful pg_net stub so the robot can run locally.
-- =====================================================================

-- --- Supabase-like roles -------------------------------------------------
-- anon + authenticated are NOLOGIN, NOBYPASSRLS — exactly like Supabase.
do $$ begin
  if not exists (select 1 from pg_roles where rolname='anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname='authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname='service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
end $$;

grant usage on schema public to anon, authenticated, service_role;

-- --- the one table that stores everything --------------------------------
create table if not exists public.kv(
  key text primary key,
  value text,
  updated_at timestamptz default now()
);

-- THE VULNERABILITY: PostgREST lets the anon key do all of these.
grant select, insert, update, delete on table public.kv to anon, authenticated;

-- =====================================================================
-- pg_net stub — real pg_net is an async HTTP worker. The robot only
-- touches net.http_get(url)->bigint and net._http_response(id,status_code,
-- content). We return a fresh id per call and let the proof "deliver" the
-- response by inserting into net._http_response between ticks — exactly
-- the two-tick async cycle prod sees.
-- =====================================================================
create schema if not exists net;
create sequence if not exists net._req_seq start 1;

create table if not exists net._http_response(
  id          bigint primary key,
  status_code int,
  content_type text default 'application/json',
  headers     jsonb default '{}'::jsonb,
  content     text,
  timed_out   boolean default false,
  error_msg   text,
  created     timestamptz default now()
);

-- records the URL each request asked for (lets the proof show the fetch)
create table if not exists net._pending(id bigint primary key, url text, created timestamptz default now());

create or replace function net.http_get(url text, params jsonb default '{}'::jsonb,
                                         headers jsonb default '{}'::jsonb, timeout_milliseconds int default 5000)
returns bigint language plpgsql as $$
declare rid bigint;
begin
  rid := nextval('net._req_seq');
  insert into net._pending(id, url) values (rid, url);
  return rid;   -- async: response arrives later via net._http_response
end $$;
