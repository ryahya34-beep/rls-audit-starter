#!/usr/bin/env bash
# Build a fresh database from sql/ and run every test against it.
#
# Connection comes from the usual libpq variables (PGHOST, PGPORT, PGUSER,
# PGPASSWORD). The user must be a superuser: the tests switch roles the way
# PostgREST does. Extra SQL files listed in EXTRA_SQL are applied after the
# schema; test/mutation.sh uses that to break things on purpose.
set -euo pipefail
cd "$(dirname "$0")/.."

DB="${TEST_DB:-rls_audit_test}"
PSQL=(psql -X -q -v ON_ERROR_STOP=1)

"${PSQL[@]}" -d postgres -c "drop database if exists $DB" -c "create database $DB" >/dev/null

for f in test/shim.sql sql/*.sql test/helpers.sql ${EXTRA_SQL:-}; do
  "${PSQL[@]}" -d "$DB" -f "$f" >/dev/null 2>&1 || {
    echo "SETUP FAILED while loading $f:"
    "${PSQL[@]}" -d "$DB" -f "$f" 2>&1 | grep -E 'ERROR' | head -3 || true
    exit 2
  }
done

pass=0
fail=0
checks=0
for t in test/[0-9][0-9]_*.sql; do
  name=$(basename "$t" .sql)
  if out=$("${PSQL[@]}" -d "$DB" -o /dev/null -f "$t" 2>&1); then
    n=$(grep -c 'ok - ' <<<"$out" || true)
    checks=$((checks + n))
    pass=$((pass + 1))
    echo "PASS  $name ($n checks)"
    if [ -n "${VERBOSE:-}" ]; then grep 'ok - ' <<<"$out" | sed 's/^.*ok - /        ok - /'; fi
  else
    fail=$((fail + 1))
    echo "FAIL  $name"
    grep -E 'FAIL:|ERROR:' <<<"$out" | sed 's/^.*\(FAIL:\|ERROR:\)/        \1/' | head -3
  fi
done

echo
echo "$pass passed, $fail failed, $checks checks"
[ "$fail" -eq 0 ]
