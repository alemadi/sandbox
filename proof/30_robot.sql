-- =====================================================================
-- PROOF · THE ROBOT STILL RUNS under the new wall. wc_autoconfirm_tick is
-- SECURITY DEFINER owned by the table owner, so it keeps writing kv even
-- though anon cannot. It is NOT granted to anon (only pg_cron, as owner,
-- calls it) — so here we invoke it as the owner, exactly like cron does.
--
-- We also prove the golden rule: the robot NEVER overwrites a result the
-- organizer already set. Organizer pre-confirms m1 = 7-7 (a deliberately
-- impossible-looking score); ESPN then reports m1 = 2-1 and m2 = 1-0.
-- Expect: m2 confirmed by the robot, m1 left as the organizer's 7-7.
-- =====================================================================
\pset pager off

\echo ''
\echo '-- SETUP: organizer pre-confirms m1 = 7-7 (via the gated RPC) --'
set role anon;
select public.org_exec('demo-code-9090','set','wc:results',
   (coalesce((select value from kv where key='wc:results'),'{}')::jsonb
    || '{"m1":{"h":7,"a":7}}'::jsonb)::text) as org_preset_m1;
reset role;
\echo '-- wc:results before the robot runs: --'
select value as results_before from kv where key='wc:results';

\echo ''
\echo '======== TICK 1 — no response waiting yet; should fire a fetch ========'
select public.wc_autoconfirm_tick() as tick1_result;
select request_id as rid from wc_poll_state where id = 1 \gset
\echo '(robot queued ESPN request id = ':rid')'
\echo '-- the URL it asked for: --'
select url as fetched_url from net._pending where id = :rid;

\echo ''
\echo '======== DELIVER the canned ESPN scoreboard (async response arrives) ========'
\echo '# m1 Mexico 2-1 South Africa (completed) · m2 Korea Republic 1-0 Czech Republic (completed)'
insert into net._http_response(id, status_code, content) values (:rid, 200, $json$
{
  "events": [
    {
      "date": "2026-06-11T19:00:00Z",
      "competitions": [
        { "status": { "type": { "completed": true } },
          "competitors": [
            { "homeAway": "home", "score": "2", "team": { "displayName": "Mexico" } },
            { "homeAway": "away", "score": "1", "team": { "displayName": "South Africa" } }
          ] } ]
    },
    {
      "date": "2026-06-12T02:00:00Z",
      "competitions": [
        { "status": { "type": { "completed": true } },
          "competitors": [
            { "homeAway": "home", "score": "1", "team": { "displayName": "Korea Republic" } },
            { "homeAway": "away", "score": "0", "team": { "displayName": "Czech Republic" } }
          ] } ]
    }
  ]
}
$json$);

\echo ''
\echo '======== TICK 2 — consumes the response, confirms finished GROUP games ========'
select public.wc_autoconfirm_tick() as tick2_result;

\echo ''
\echo '-- FINAL wc:results: m1 kept as organizer 7-7, m2 added by robot 1-0 --'
select jsonb_pretty(value::jsonb) as results_after from kv where key='wc:results';

\echo ''
\echo '-- standings() now reflects the confirmed results (anon-readable) --'
set role anon;
select slug, pts, correct, predicted from public.standings() order by pts desc, slug;
reset role;
\echo ''
