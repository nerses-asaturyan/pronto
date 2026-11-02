#!/usr/bin/env bash
# One worker through checks and review: the verdict only counts for the exact work it saw.
. "$(dirname "$0")/lib.sh"

R="$T/repo"
mkdir -p "$R/.pronto"
g init -q
echo base > "$R/app.txt"
g add app.txt
g commit -q -m init
printf '[pronto worker: dark-mode]\n## Checks\n```pronto-checks\ngrep -q dark app.txt\n```\n' > "$R/.pronto/dark-mode.md"
CWD="$(jpath "$R")"
TP="$(jpath "$T/projects/repo/w1.jsonl")"

stop() { hook gate "$(printf '{"session_id":"w1","cwd":"%s","last_assistant_message":"Done."}' "$CWD")"; }
# review <session id> <agent type> <reply>: a subagent finishes.
review() {
  hook review "$(printf '{"session_id":"%s","transcript_path":"%s","cwd":"%s","agent_type":"%s","last_assistant_message":"%s"}' \
    "$1" "$TP" "$CWD" "$2" "$3")"
}

hook mark "$(printf '{"session_id":"w1","cwd":"%s","prompt":"[pronto worker: dark-mode] Do the task"}' "$CWD")"
expect "worker starts" 0 "1 check(s) saved"

stop
expect "stops early: a check fails" 2 "a check failed"

echo dark >> "$R/app.txt"
stop
expect "does the work: a review is requested" 2 "review of this exact work"

review w1 Explore "ACCEPT looks fine"
check "another subagent's ACCEPT is ignored" test ! -f "$W/w1/review"

review w1 pronto:reviewer 'REJECT\n- Done when 1: no test'
stop
expect "the reviewer rejects: blocked, try 1" 2 "rejected the work (try 1 of 3)"

echo "dark test" >> "$R/app.txt"
stop
expect "after a fix, the new work needs a new review" 2 "review of this exact work"

review w1 pronto:reviewer '**ACCEPT**\n- all good'
echo "late edit" >> "$R/app.txt"
stop
expect "an edit after the ACCEPT needs a new review" 2 "review of this exact work"

review w1 pronto:reviewer 'ACCEPT\n- all good'
echo "notes" > "$R/.pronto/dark-mode.notes.md"
stop
expect "ACCEPT counts when only .pronto notes changed after it" 0 "reviewer accepted the work"

echo more >> "$R/app.txt"
stop
review sub-123 reviewer "ACCEPT"
stop
expect "a verdict with the subagent's own session id is matched by the parent transcript" 0 "reviewer accepted the work"

for i in 1 2 3; do
  echo "x$i" >> "$R/app.txt"
  stop
  expect "ignoring the review request is blocked ($i of 3)" 2 "review of this exact work"
done
echo x4 >> "$R/app.txt"
stop
expect "after 3 ignored requests the worker may stop, marked NOT verified" 0 "NOT verified"

finish
