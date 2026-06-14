# Engagement set — promotion package (sandbox → production)

**Prepared:** 2026-06-14 · **Source:** sandbox branch `claude/determined-dijkstra-ogpqf3`
**Baseline compared:** `46441d5` (sandbox before the engagement starter pack) → current `HEAD`
**Patch file:** `docs/engagement-promotion.patch` (net diff for `index.html`, 1 file)

> The app launched **2 days ago** and is live mid-competition. This package promotes
> only the **additive, read-only / local-only** engagement features and flags the two
> items that need a human decision before they touch production.

---

## Safety verdict (verified in code)

The shared leaderboard **cannot be corrupted by any of these features**, by construction:

- `index.html` `kv` store is **read-only to the browser** (`sql/protect.sql`). Every shared
  write goes through one server-validated RPC, **`save_picks`**, gated by Postgres on the match
  clock + PIN. There are exactly two `save_picks` call sites and both are the pre-existing core
  pick-save flow.
- **No engagement feature calls `save_picks`** or writes a shared key. Their only persistence is
  `localStorage` (`sset(..., /*shared=*/false)` → `lsSet`). The "Your Day" snapshot writes
  `wc:ydSeen` with `shared=false` (`index.html` `buildYourDay()`), i.e. local only.

So "maximize engagement" and "don't break the launch" are compatible here. Ship the green items.

---

## What's in the patch, by feature

| # | Feature | Risk | Writes? | Ship? |
|---|---------|------|---------|-------|
| 1 | **Pick button polish** — equal 3-col grid, bigger touch targets/fonts (CSS `.picks`/`.pick`) | 🟢 cosmetic | none | ✅ |
| 2 | **"Your Day" home card** — greeting, rank, since-last-visit delta, deadline radar, next-unpicked CTA | 🟢 read + local | `wc:ydSeen` (local) | ✅ |
| 3 | **Reveal badge** on Matches nav — count of results waiting | 🟢 read | none | ✅ |
| 4 | **Named overnight overtakes** — "X passed you / you overtook Y overnight" | 🟢 read | none | ✅ |
| 5 | **Head-to-head share card** — rival-aware "catch me" share image + text (the *server-score fix*) | 🟢 read | none | ✅ (sanity-check score, see below) |
| 6 | **Rival "Share the challenge" button** in the rival-watch card | 🟢 | none | ✅ |
| 7 | **Swipe combo meter** — "🔥 N in a row" chip, rising tone, confetti at 5/10/20 | 🟢 in-memory | none | ✅ |
| 8 | **Install coach** — add-to-home-screen prompt (Android `beforeinstallprompt` + iOS hint) | 🟢 | `wc:installSeen` (local) | ✅ |
| 9 | **FAQ copy** updates describing the above | 🟢 content | none | ✅ |
| 10 | **Offline pick outbox** — caches picks locally + "saving / offline" indicator, retries via the **same** `save_picks` RPC | 🟡 behavioral | `wc:outbox` (local) | ⚠️ test offline path first |
| — | **`demoSeedYourDay()`** — seeds fake player data when URL has `#demo` | 🔴 **sandbox-only** | local fake data | ❌ **DO NOT PROMOTE** |

---

## ⚠️ Before you apply the patch — two required edits

The patch is the raw sandbox diff. **Strip these sandbox-only pieces** so they never reach prod:

1. **Drop the entire `demoSeedYourDay()` function.** In the patch it's the added block that begins:
   ```
   /* ===== demo bootstrap: open the app with #demo to preview the "Your Day" card ... */
   function demoSeedYourDay(){ ... }
   ```
   It writes fake `wc:player:`, `wc:me`, `wc:pin`, `wc:ranksnap` into localStorage. Harmless in a
   sandbox, **wrong in production**.

2. **Drop its call in `init()`.** Same patch, remove the added line:
   ```
   try{demoSeedYourDay();}catch(e){}
   ```
   Keep the rest of that `init` hunk (`buildYourDay(); openReveal(); setOfflineUI/replayOutbox;
   maybeInstallCoach`).

---

## 🟡 One behavioral change to confirm (not a pure add)

- **`init()` replaces `if(!openReveal())welcomeDelta();` with `buildYourDay(); openReveal();`** — the
  "Your Day" card intentionally supersedes the old `welcomeDelta()` welcome toast. Confirm you're OK
  retiring `welcomeDelta()` (it also dodges the old consume-on-read welcome-delta bug).
- **`persistPlayer()` gains the offline outbox** (`markOutbox`/`clearOutbox`/`setOfflineUI`). The
  actual write path is unchanged — it still calls `savePicksRPC()` → server-validated `save_picks`.
  The outbox only adds a localStorage cache + retry UI. **Test:** make a pick offline, reconnect,
  confirm it syncs and the indicator clears.

---

## Pre-ship checklist

- [ ] Apply `docs/engagement-promotion.patch` to the **production** `index.html`.
- [ ] **Remove** `demoSeedYourDay()` + its `init()` call (above).
- [ ] Confirm the head-to-head share card shows **your real standings score** (matches the leaderboard),
      not a stale/local number — open it as two different players and eyeball it.
- [ ] Confirm `welcomeDelta()` retirement is intended.
- [ ] Test the offline outbox: pick offline → reconnect → syncs, indicator clears.
- [ ] Smoke test at 375px (the set was verified there): no console errors, cards render,
      install coach appears once and dismisses, combo confetti fires.
- [ ] Ship **additively** — nothing here changes scoring or standings, so it can go live mid-comp.
      If you have a flag mechanism, gate the "Your Day" card so you can flip it off without a redeploy.

---

## How this patch was generated

```bash
git diff 46441d5 HEAD -- index.html > docs/engagement-promotion.patch
```

`46441d5` is the `baseline: sandbox before engagement starter pack` commit, so this diff is **exactly**
the kept engagement set (starter pack + the keep/remove finalize), with nothing from the sandbox
isolation work mixed in.
