#!/usr/bin/env bash
# =====================================================================
# PROOF · run_all.sh — end-to-end, from a clean database.
# Proves: (1) the four cheats work against the live shape, (2) all four
# are blocked after protect.sql, (3) every legitimate path still works,
# (4) the ESPN robot still confirms group results without overwriting
# the organizer.
#
# Assumes a local PG16 cluster is already running on the socket below
# (see proof/README for the initdb/pg_ctl one-liners). Re-runnable.
# =====================================================================
set -euo pipefail
PGBIN=/usr/lib/postgresql/16/bin
SOCK=/home/claude/pgproof/sock
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
PSQL() { runuser -u postgres -- "$PGBIN/psql" -h "$SOCK" -U postgres "$@"; }

banner() { printf '\n\n\033[1m============================================================\n%s\n============================================================\033[0m\n' "$1"; }

banner "RESET — drop & recreate database wc"
PSQL -d postgres -c "drop database if exists wc;" -c "create database wc;"

banner "STAGE 1 — recreate the LIVE pre-protect shape (vulnerable)"
PSQL -d wc -v ON_ERROR_STOP=1 -qf "$HERE/00_stage1.sql"
PSQL -d wc -v ON_ERROR_STOP=1 -qf "$HERE/_robot_core.sql"
PSQL -d wc -v ON_ERROR_STOP=1 -qf "$ROOT/sql/standings.sql"
PSQL -d wc -v ON_ERROR_STOP=1 -qf "$HERE/01_seed.sql"
echo "stage 1 loaded."

banner "ATTACK #1 — the four cheats against the UNPROTECTED backend (all succeed)"
PSQL -d wc -f "$HERE/10_cheats.sql"

banner "RE-SEED — restore known-good state before hardening"
PSQL -d wc -v ON_ERROR_STOP=1 -qf "$HERE/01_seed.sql"
echo "re-seeded."

banner "HARDEN — apply protect.sql (RLS wall + RPCs + pin migration)"
PSQL -d wc -v ON_ERROR_STOP=1 -f "$ROOT/sql/protect.sql"

banner "ATTACK #2 — the SAME four cheats against the PROTECTED backend (all blocked)"
PSQL -d wc -f "$HERE/10_cheats.sql"

banner "LEGIT — the real player & organizer paths still work"
PSQL -d wc -f "$HERE/20_legit.sql"

banner "ROBOT — ESPN auto-confirm still runs, never overwrites the organizer"
PSQL -d wc -f "$HERE/30_robot.sql"

banner "DONE — all four vectors closed; legit paths + robot intact"
