# Staff Challenge 26 — SANDBOX (local-only)

A safe, isolated copy of the production app for testing and R&D.
**It cannot touch production.** Picks and state are saved to your browser's
`localStorage` only — no Supabase, no shared leaderboard, no robot, no live data.

This copy was prepared per the project's **Sandbox Orchestration Doctrine §4**
(the four isolation boundaries). Two of those boundaries are already baked into
these files; the other two are *your* steps and are listed below.

---

## What's already isolated in this copy

| Boundary (doctrine §4) | Status here | How |
|---|---|---|
| **2. Separate backend** | ✅ done | `SUPABASE_URL` is blank → `CONFIGURED===false`. The kv layer (`sget/sset/sdel/slist` in `index.html`) returns early on `!CONFIGURED`, so **no network write can fire**. |
| **3. No custom domain** | ✅ done | `CNAME` deleted. This repo physically cannot claim `staffchallenge26.com`. |
| **1. Separate repo** | ⬜ your step | Create a *new* repo, e.g. `qnb-staff-wc2026-sandbox`. Never push this to the production repo or its `main`. |
| **4. Fresh, scoped creds** | ⬜ your step | If/when you push, use a **separate fine-grained PAT** scoped to the sandbox repo only (Contents: read/write). **Never reuse the production token** — if a public sandbox trips GitHub secret-scanning, a shared token gets auto-revoked and takes prod down with it. |

---

## Run it locally (10 seconds)

The app is one static file. Either:

- **Just open it:** double-click `index.html` (opens at `file://…`). Good enough for most UI/logic testing.
- **Or serve it** (cleaner; avoids a few `file://` quirks):
  ```bash
  cd qnb-staff-wc2026-sandbox
  python3 -m http.server 8080
  # → http://localhost:8080
  ```

### Confirm you're in safe local mode
You should see the amber banner: *"Setup needed: database keys aren't configured yet, so picks won't sync."*
That banner is the **proof of isolation** — it means `CONFIGURED===false` and nothing is reaching a backend.
Open DevTools → Network and you'll see zero requests to any `*.supabase.co`.

To reset the sandbox to a clean slate, clear site data / `localStorage` for the origin (or use a private window).

---

## Later: if you want a *shared* sandbox (separate Supabase project)

Local-only can't test the shared leaderboard, RPC writes, standings, or the robot —
those need a real backend. To add one **without ever touching production**:

1. Create a **brand-new** Supabase project (its own URL + anon key).
2. In `index.html` (~line 1011), paste the **new** project's URL and anon key.
   **Never** the production project `fzybuasvhzhmkbhxbton` — one stray write corrupts live results.
3. Load the SQL into the **new** project's SQL Editor: `sql/standings.sql`, `sql/protect.sql`,
   and (only if you want auto-confirm) `sql/robot.sql`. Without `robot.sql` there is no robot.
4. **Seed pseudonymised data only.** The ~344 real staff names / `wc:player:<slug>` identifiers
   are real QNB-staff PII (doctrine §4). Map them to synthetic handles before any real data
   enters the sandbox. No PII in logs, URLs, or snapshots.

The source files in this repo contain **no** player data — it all lives in Supabase kv — so
pseudonymisation only becomes relevant at the moment you copy live data into a sandbox backend.

---

## What was changed vs. production (full list)

- `index.html` ~line 1011–1012: `SUPABASE_URL` blanked; `SUPABASE_KEY` → `"SANDBOX_LOCAL_ONLY"`.
- `CNAME`: **deleted**.
- `manifest.json`: name → "Staff Challenge — SANDBOX"; `start_url`/`scope` made relative.
- `docs/CHANGELOG.md`: sandbox-fork banner + entry prepended; production history kept below it.
- This `SANDBOX_README.md`: added.

Nothing else from production was modified. No token, repo, domain, DB, or kv key was touched in creating this copy.
