#!/usr/bin/env bash
# One worker through checks and review: the verdict only counts for the exact work it saw.
. "$(dirname "$0")/lib.sh"

R="$T/repo"
mkdir -p "$R/.pronto"
g init -q
echo base > "$R/app.txt"
g add app.txt
g commit -q -m init
CWD="$(jpath "$R")"
TP="$(jpath "$T/projects/repo/w1.jsonl")"

# start: save the card and start worker w1. A finished task deletes its card, so each task starts here.
start() {
  printf '[pronto worker: dark-mode]\n## Checks\n```pronto-checks\ngrep -q dark app.txt\n```\n' > "$R/.pronto/dark-mode.md"
  hook mark "$(printf '{"session_id":"w1","cwd":"%s","prompt":"[pronto worker: dark-mode] Do the task"}' "$CWD")"
}
stop() { hook gate "$(printf '{"session_id":"w1","cwd":"%s","last_assistant_message":"Done."}' "$CWD")"; }
# review <session id> <agent type> <reply>: a subagent finishes.
review() {
  hook review "$(printf '{"session_id":"%s","transcript_path":"%s","cwd":"%s","agent_type":"%s","last_assistant_message":"%s"}' \
    "$1" "$TP" "$CWD" "$2" "$3")"
}
# lacks <text>: the last hook output does not have the text.
lacks() { ! printf '%s\n%s\n' "$out" "$err" | grep -qF -- "$1"; }

start
expect "worker starts" 0 "1 check(s) saved"

stop
expect "stops early: a check fails" 2 "a check failed"

echo dark >> "$R/app.txt"
stop
expect "does the work: a review is requested" 2 "review of this exact work"
check "the request tells the reviewer the checks already passed" grep -qF "ran the card's 1 check(s) on this exact work and they all passed, so do not run them again" "$T/err"
check "the first request is not a re-review" lacks "re-review"
check "the worker is told to give no results before the review accepts" grep -qF "give the user no results or summary" "$T/err"

review w1 Explore "ACCEPT looks fine"
check "another subagent's ACCEPT is ignored" test ! -f "$W/w1/review"

review w1 pronto:reviewer 'REJECT\n- Done when 1: no test'
stop
expect "the reviewer rejects: blocked, try 1" 2 "rejected the work (try 1 of 3)"

echo "dark test" >> "$R/app.txt"
stop
expect "after a fix, the new work needs a new review" 2 "review of this exact work"
check "the new review is a re-review that points to the last review" grep -qF "This is a re-review: the last review is in" "$T/err"
check "and gives the diff since the rejected work" grep -qE "git diff [0-9a-f]{40,64} [0-9a-f]{40,64}\." "$T/err"
diffcmd="$(grep -oE 'git diff [0-9a-f]{40,64} [0-9a-f]{40,64}' "$T/err")"
check "that diff shows exactly the fix" sh -c "cd '$R' && $diffcmd | grep -qx '+dark test'"

review w1 pronto:reviewer '**ACCEPT**\n- all good'
echo "late edit" >> "$R/app.txt"
stop
expect "an edit after the ACCEPT needs a new review" 2 "review of this exact work"

review w1 pronto:reviewer 'ACCEPT\n- all good'
echo "notes" > "$R/.pronto/dark-mode.notes.md"
stop
expect "ACCEPT counts when only .pronto notes changed after it" 0 "reviewer accepted the work"
check "the accepted task's card is deleted" test ! -f "$R/.pronto/dark-mode.md"
check "its notes are deleted" test ! -f "$R/.pronto/dark-mode.notes.md"
check "its saved state is deleted" test ! -d "$W/w1"
check "its result file stays for the planner" grep -qF "Status: ACCEPTED" "$R/.pronto/dark-mode.result.md"
stop
expect "after the task ends, the session stops like a normal one" 0
check "with no message from Pronto" test -z "$out$err"

start
echo more >> "$R/app.txt"
stop
review sub-123 reviewer "ACCEPT"
stop
expect "a verdict with the subagent's own session id is matched by the parent transcript" 0 "reviewer accepted the work"

start
for i in 1 2 3; do
  echo "x$i" >> "$R/app.txt"
  stop
  expect "ignoring the review request is blocked ($i of 3)" 2 "review of this exact work"
done
echo x4 >> "$R/app.txt"
stop
expect "after 3 ignored requests the worker may stop, marked NOT verified" 0 "NOT verified"
check "a task that ends NOT verified is cleaned up too" test ! -f "$R/.pronto/dark-mode.md" -a ! -d "$W/w1"

finish
