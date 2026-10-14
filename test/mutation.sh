#!/usr/bin/env bash
# Mutation testing: break the schema on purpose, one way at a time, and
# require the test suite to go red. A mutation the tests do not notice
# ("survived") means a test is missing or does not actually check anything.
set -uo pipefail
cd "$(dirname "$0")/.."

echo "Baseline (no mutation):"
if ! test/run.sh >/dev/null; then
  echo "  the suite is not green without mutations; fix that first"
  exit 2
fi
echo "  green"
echo

survived=0
for m in test/mutations/*.sql; do
  name=$(basename "$m" .sql)
  desc=$(head -1 "$m" | sed 's/^-- *//')
  out=$(EXTRA_SQL="$m" test/run.sh 2>&1)
  code=$?
  if [ "$code" -eq 0 ]; then
    survived=$((survived + 1))
    echo "SURVIVED  $name: $desc"
  elif [ "$code" -eq 2 ]; then
    survived=$((survived + 1))
    echo "BROKEN    $name: the mutation itself failed to apply"
    grep -E 'ERROR' <<<"$out" | head -3
  else
    caught=$(grep '^FAIL' <<<"$out" | awk '{print $2}' | paste -sd, -)
    echo "KILLED    $name: $desc"
    echo "          caught by: $caught"
  fi
done

echo
total=$(ls test/mutations/*.sql | wc -l | tr -d ' ')
echo "$((total - survived)) of $total mutations killed"
[ "$survived" -eq 0 ]
