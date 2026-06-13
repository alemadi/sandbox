-- =====================================================================
-- PROOF · THE LEGITIMATE PATHS STILL WORK. Everything here is called as
-- `anon` (what the publishable key maps to) through the SECURITY DEFINER
-- RPCs — the only doors left open. \timing shows the brute-force naps.
-- =====================================================================
\pset pager off
\timing on

\echo ''
\echo '======== A) save_picks with the CORRECT pin ========'
\echo '# Alice (pin 1234) sends her FULL predictions: she TAMPERS m1 (locked,'
\echo '# kicked off yesterday) to 0-9, keeps m5, and adds a fresh m10 pick.'
\echo '# Expect: m1 kept as the stored 2-1, m5 kept, m10 accepted.'
set role anon;
select jsonb_pretty(public.save_picks('alice','1234', jsonb_build_object(
  'name','Alice','dept','Treasury','champ','Brazil',
  'predictions', jsonb_build_object(
     'm1', jsonb_build_object('o','A','h',0,'a',9),     -- tamper attempt (locked)
     'm5', jsonb_build_object('o','D','h',1,'a',1),      -- unchanged (still open)
     'm10',jsonb_build_object('o','H','h',3,'a',1))      -- brand-new (open)
))) as stored_row;
reset role;

\echo ''
\echo '======== B) save_picks with a WRONG pin (note the ~0.3s nap) ========'
set role anon;
select public.save_picks('alice','9999','{"predictions":{}}'::jsonb);
reset role;

\echo ''
\echo '======== C) a brand-new player claims their slug ========'
\echo '# Dave has never played; first save with pin 1111 claims slug "dave".'
set role anon;
select public.save_picks('dave','1111', jsonb_build_object(
  'name','Dave','dept','Ops',
  'predictions', jsonb_build_object('m10', jsonb_build_object('o','A','h',0,'a','2'::text)))) is not null as dave_created;
reset role;
\echo '# Dave now in wc_auth (pin stored privately, never in kv)?'
select exists(select 1 from wc_auth where slug='dave') as dave_has_auth,
       (select value::jsonb ? 'pin' from kv where key='wc:player:dave') as dave_row_has_pin;

\echo ''
\echo '======== D) champion-pick seal (same lock machinery as matches) ========'
\echo '# _champ locks 2026-06-18, still future, so we PROVE the seal inside a'
\echo '# transaction that back-dates the lock, then ROLL BACK (real date kept).'
begin;
update wc_locks set ko='2020-01-01T00:00:00Z' where id='_champ';
set role anon;
select (public.save_picks('alice','1234','{"champ":"Spain","predictions":{}}'::jsonb))->>'champ'
       as champ_after_locked_change_attempt;   -- expect Brazil, not Spain
reset role;
rollback;
\echo '# (rolled back — _champ lock back to its real 2026-06-18 date)'
select ko as champ_lock_real from wc_locks where id='_champ';

\echo ''
\echo '======== E) standings() still readable by anon (RLS read policy) ========'
set role anon;
select slug, pts, predicted from public.standings() order by slug;
reset role;

\echo ''
\echo '======== F) organizer path — code verified in SQL ========'
\echo '# Rotate the org code to a known proof value (prod keeps the real'
\echo '# shipped hash; rotate with: update wc_org_auth set code_hash=wc_pin_hash(...)).'
update wc_org_auth set code_hash = public.wc_pin_hash('demo-code-9090');
\echo '# F1: wrong code -> false (+~0.4s nap):'
set role anon;
select public.org_check('not-the-code') as wrong_code_ok;
\echo '# F2: right code -> true:'
select public.org_check('demo-code-9090') as right_code_ok;
\echo '# F3: organizer legitimately confirms m5 = 2-1 via org_exec:'
select public.org_exec('demo-code-9090','set','wc:results',
       (coalesce((select value from kv where key='wc:results'),'{}')::jsonb
        || '{"m5":{"h":2,"a":1}}'::jsonb)::text) as org_set_m5;
\echo '# F4: WRONG code cannot write (expect bad_code):'
select public.org_exec('nope','set','wc:results','{"m5":{"h":0,"a":5}}') as should_fail;
reset role;
\echo '# --> wc:results m5 after organizer action:'
select value::jsonb->'m5' as results_m5 from kv where key='wc:results';
\timing off
\echo ''
