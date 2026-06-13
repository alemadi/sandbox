-- =====================================================================
-- PROOF · THE FOUR CHEATS — attempted as the `anon` role (what the
-- publishable key maps to). Run this BEFORE protect (they all succeed)
-- and AFTER protect (they are all blocked). ON_ERROR_STOP is OFF so a
-- denied statement prints its error and the script continues; each
-- statement autocommits independently so one failure doesn't poison the
-- next. Superuser SELECTs after each attempt show the actual stored state.
-- =====================================================================
\pset pager off

\echo ''
\echo '################ CHEAT 1 — edit a pick AFTER kickoff ################'
\echo '# m1 (Mexico v South Africa) kicked off 2026-06-11. Alice tries to'
\echo '# rewrite her m1 prediction to a perfect 5-0 from DevTools/curl.'
set role anon;
update public.kv
   set value = jsonb_set(value::jsonb, '{predictions,m1}', '{"o":"H","h":5,"a":0}'::jsonb)::text
 where key = 'wc:player:alice';
reset role;
\echo '# --> stored m1 prediction for alice now reads:'
select value::jsonb->'predictions'->'m1' as alice_m1 from public.kv where key='wc:player:alice';

\echo ''
\echo '################ CHEAT 2 — forge an official result ################'
\echo '# m5 (Qatar v Switzerland) has not been played. Anon injects a'
\echo '# fabricated 9-0 result straight into wc:results.'
set role anon;
update public.kv
   set value = jsonb_set(value::jsonb, '{m5}', '{"h":9,"a":0}'::jsonb)::text
 where key = 'wc:results';
reset role;
\echo '# --> wc:results m5 now reads:'
select value::jsonb->'m5' as results_m5 from public.kv where key='wc:results';

\echo ''
\echo '################ CHEAT 3 — steal a PIN + hijack a rival ################'
\echo '# Anon reads Bob''s PIN hash from his own row, then overwrites his'
\echo '# entire entry (wipes his picks / defaces his profile).'
set role anon;
select value::jsonb->>'pin' as bob_pin_hash_exposed from public.kv where key='wc:player:bob';
update public.kv
   set value = jsonb_build_object('slug','bob','name','HACKED','dept','','predictions','{}'::jsonb)::text
 where key = 'wc:player:bob';
reset role;
\echo '# --> Bob''s stored row now reads:'
select value::jsonb->>'name' as bob_name, value::jsonb->'predictions' as bob_preds
  from public.kv where key='wc:player:bob';

\echo ''
\echo '################ CHEAT 4 — delete a rival entirely ################'
\echo '# Anon deletes Carol''s row to knock her off the leaderboard.'
set role anon;
delete from public.kv where key='wc:player:carol';
reset role;
\echo '# --> Carol still present? (1 = yes, 0 = deleted):'
select count(*) as carol_rows from public.kv where key='wc:player:carol';
\echo ''
