-- =====================================================================
-- PROOF · STAGE 1 SEED — three legacy players in the OLD shape, with
-- their PIN hash sitting inside their own (anon-readable) row. PIN scheme
-- matches the client/server: sha256('wc26:'||pin). Built via digest() so
-- the hashes are guaranteed identical to what save_picks/org_exec expect.
-- PINs:  alice=1234  bob=5678  carol=4321
-- =====================================================================
create extension if not exists pgcrypto;

insert into public.kv(key, value, updated_at) values
('wc:player:alice', jsonb_build_object(
   'slug','alice','ig','alice','name','Alice','dept','Treasury','country','QA',
   'joinedAt','2026-06-01T08:00:00Z','champ','Brazil',
   'pin', encode(digest('wc26:1234','sha256'),'hex'),
   'predictions', jsonb_build_object(
      'm1', jsonb_build_object('o','H','h',2,'a',1),
      'm2', jsonb_build_object('o','A','h',0,'a',1),
      'm5', jsonb_build_object('o','D','h',1,'a',1))
 )::text, now()),
('wc:player:bob', jsonb_build_object(
   'slug','bob','ig','bob','name','Bob','dept','Risk','country','QA',
   'joinedAt','2026-06-02T08:00:00Z','champ','France',
   'pin', encode(digest('wc26:5678','sha256'),'hex'),
   'predictions', jsonb_build_object(
      'm1', jsonb_build_object('o','D','h',1,'a',1),
      'm3', jsonb_build_object('o','H','h',2,'a',0))
 )::text, now()),
('wc:player:carol', jsonb_build_object(
   'slug','carol','ig','carol','name','Carol','dept','IT','country','QA',
   'joinedAt','2026-06-03T08:00:00Z','champ','Argentina',
   'pin', encode(digest('wc26:4321','sha256'),'hex'),
   'predictions', jsonb_build_object(
      'm1', jsonb_build_object('o','A','h',0,'a',2),
      'm5', jsonb_build_object('o','H','h',3,'a',0))
 )::text, now())
on conflict (key) do update set value=excluded.value, updated_at=now();

-- results start empty; the robot will confirm m1/m2 later in the proof
insert into public.kv(key, value, updated_at) values ('wc:results','{}',now())
on conflict (key) do update set value=excluded.value, updated_at=now();
