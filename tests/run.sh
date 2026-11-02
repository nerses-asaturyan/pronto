#!/usr/bin/env bash
# Runs every hook test. Exits 0 only if all of them pass. Needs bash and git (Git Bash on Windows).
cd "$(dirname "$0")" || exit 1
status=0
for t in hooks/*.test.sh; do
  bash "$t" || status=1
done
if [ "$status" -eq 0 ]; then echo "All hook tests passed."; else echo "Some hook tests FAILED."; fi
exit "$status"
