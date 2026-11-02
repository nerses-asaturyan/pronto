#!/usr/bin/env bash
# The gate runs the card's checks from a saved copy, in a worktree or a plain folder.
. "$(dirname "$0")/lib.sh"

R="$T/main repo"
mkdir -p "$R/.pronto"
g init -q
echo base > "$R/app.txt"
g add .
g commit -q -m init
cat > "$R/.pronto/dark-mode.md" << 'EOF'
[pronto worker: dark-mode]
# Task: dark mode

## Checks
```pronto-checks
# comment lines are skipped
cat > /dev/null; true
grep -q dark app.txt
<one command per line>
```
EOF
g worktree add -q "$T/wt" -b pronto/dark-mode
WT="$(jpath "$T/wt")"

hook mark "$(printf '{"session_id":"w1","cwd":"%s","prompt":"[pronto worker: dark-mode]\\n# Task: dark mode"}' "$WT")"
expect "worker in a worktree finds the card in the main checkout" 0 "2 check(s) saved"
check "comments and template placeholders are not saved as checks" test "$(grep -c . "$W/w1/checks")" -eq 2

hook gate "$(printf '{"session_id":"w1","cwd":"%s","last_assistant_message":"Done!"}' "$WT")"
expect "stop before the work: blocked" 2 "FAIL  grep -q dark app.txt"
check "checks run with no stdin (cat does not hang) and report PASS" grep -qF "PASS  cat > /dev/null; true" "$T/err"

printf '```pronto-checks\ntrue\n```\n' > "$R/.pronto/dark-mode.md"
hook gate "$(printf '{"session_id":"w1","cwd":"%s"}' "$WT")"
expect "weakening the card's checks changes nothing: the saved copy runs" 2 "FAIL  grep -q dark app.txt"

echo dark >> "$T/wt/app.txt"
hook gate "$(printf '{"session_id":"w1","cwd":"%s"}' "$WT")"
expect "after the work, checks pass and a review is requested" 2 "review of this exact work"
check "the request names the pronto:reviewer agent" grep -qF '"pronto:reviewer"' "$T/err"

# A plain folder (no git) with the worker in a subfolder.
P="$T/plain"
mkdir -p "$P/.pronto" "$P/sub"
printf '```pronto-checks\ntest -f done.txt\n```\n' > "$P/.pronto/notes.md"
PJ="$(jpath "$P")"
hook mark "$(printf '{"session_id":"w3","cwd":"%s","prompt":"[pronto worker: notes] go"}' "$PJ")"
hook gate "$(printf '{"session_id":"w3","cwd":"%s"}' "$PJ")"
expect "non-git folder: blocked while the check fails" 2 "try 1 of 3"
hook gate "$(printf '{"session_id":"w3","cwd":"%s"}' "$PJ")"
expect "second failure counts as try 2" 2 "try 2 of 3"
hook gate "$(printf '{"session_id":"w3","cwd":"%s"}' "$PJ")"
expect "third failure lets the worker stop, marked NOT done" 0 "The task is NOT done"
check "the ended task's card is deleted" test ! -f "$P/.pronto/notes.md"
check "the ended task's state is deleted" test ! -d "$W/w3"
check "the result file stays for the planner" grep -qF "Status: NOT DONE" "$P/.pronto/notes.result.md"

printf '```pronto-checks\ntest -f done.txt\n```\n' > "$P/.pronto/notes.md"
hook mark "$(printf '{"session_id":"w3","cwd":"%s","prompt":"[pronto worker: notes] go"}' "$PJ")"
touch "$P/done.txt"
hook gate "$(printf '{"session_id":"w3","cwd":"%s"}' "$PJ")"
expect "non-git folder: once the check passes, a review is requested" 2 "review of this exact work"

finish
