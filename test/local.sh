#!/usr/bin/env bash
# Run everything against a throwaway Postgres cluster in a temp directory.
# Needs initdb, pg_ctl and psql on PATH (or in PG_BIN). Nothing is left behind.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -n "${PG_BIN:-}" ]; then export PATH="$PG_BIN:$PATH"; fi
# macOS: postgres refuses to start ("postmaster became multithreaded") when the
# shell locale is unset or invalid. C is always valid.
export LC_ALL=C

tmp=$(mktemp -d)
cleanup() { pg_ctl -D "$tmp/data" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$tmp"; }
trap cleanup EXIT

initdb -D "$tmp/data" -U postgres --auth=trust >/dev/null
# No TCP listener: the cluster is reachable only through a socket in $tmp.
pg_ctl -D "$tmp/data" -l "$tmp/log" -o "-c listen_addresses='' -k $tmp" -w start >/dev/null

export PGHOST="$tmp" PGUSER=postgres
test/run.sh
echo
test/mutation.sh
