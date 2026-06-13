-- =====================================================================
-- ROLLBACK for protect.sql — restores the EXACT pre-protect state.
-- Run this in the Supabase SQL editor to undo the hardening, together
-- with `git revert` of the matching index.html commit (the old client
-- reads the PIN from the player row, so we put PIN hashes back).
--
-- Order matters: restore PINs into rows BEFORE dropping wc_auth.
-- Idempotent: safe to run more than once.
-- =====================================================================

-- 1) Put PIN hashes back inside each player row (old client expects them).
update public.kv k
   set value = (k.value::jsonb || jsonb_build_object('pin', a.pin_hash))::text
  from public.wc_auth a
 where k.key = 'wc:player:' || a.slug;

-- 2) Drop the RLS wall on kv and restore the original open grants.
drop policy if exists kv_read_all on public.kv;
alter table public.kv disable row level security;
grant select, insert, update, delete on table public.kv to anon, authenticated;

-- 3) Drop RLS on the robot/aux tables (they were never client-granted).
alter table if exists public.wc_fixtures   disable row level security;
alter table if exists public.wc_alias      disable row level security;
alter table if exists public.wc_poll_state disable row level security;

-- 4) Drop the RPCs added by protect.sql (in dependency order).
--    NOTE: server_time() predates protect.sql in production — KEEP it,
--    and restore its grant.
drop function if exists public.org_exec(text, text, text, text);
drop function if exists public.org_check(text);
drop function if exists public.save_picks(text, text, jsonb);
drop function if exists public.wc_pin_hash(text);
grant execute on function public.server_time() to anon, authenticated;

-- 5) Drop the tables protect.sql introduced.
drop table if exists public.wc_auth;
drop table if exists public.wc_org_auth;
drop table if exists public.wc_locks;

-- pgcrypto is left installed (harmless; other code may rely on it).

-- Sanity after rollback:
--   select relrowsecurity from pg_class where relname='kv';        -- f
--   select count(*) from kv where key like 'wc:player:%'
--          and value::jsonb ? 'pin';                                -- = #players
--   select to_regprocedure('public.save_picks(text,text,jsonb)');  -- NULL
