#!/usr/bin/env bash
# Which prompts make a session a worker, and which are left alone.
. "$(dirname "$0")/lib.sh"

R="$T/proj"
mkdir -p "$R/.pronto"
g init -q
echo hi > "$R/greet.js"
g add greet.js
g commit -q -m init
printf '[pronto worker: time-greeting]\n## Checks\n```pronto-checks\ngrep -q morning greet.js\n```\n' > "$R/.pronto/time-greeting.md"
g worktree add -q "$R/.claude/worktrees/wt1" -b claude/wt1
WT="$(jpath "$R/.claude/worktrees/wt1")"
RJ="$(jpath "$R")"

# The Claude desktop app puts its own text before the card in a new session's first prompt.
APP='<system-reminder>\nYou are operating in a git worktree.\n</system-reminder>\n\nBackground (from the session that started this one):\nThe user is trying Pronto.\n\nTask:\n'

hook mark "$(printf '{"session_id":"live","cwd":"%s","prompt":"%s[pronto worker: time-greeting]\\n# Task: greeting"}' "$WT" "$APP")"
expect "marker after the app's text marks the worker (card found from a worktree)" 0 "1 check(s) saved"

hook gate "$(printf '{"session_id":"live","cwd":"%s","last_assistant_message":"Done."}' "$WT")"
expect "that worker cannot stop before the work is done" 2 "a check failed"

hook mark "$(printf '{"session_id":"quote","cwd":"%s","prompt":"It said: \\"[pronto worker: time-greeting] Do the task\\""}' "$RJ")"
check "a marker quoted mid-line does not mark the session" test ! -d "$W/quote"

hook mark "$(printf '{"session_id":"nocard","cwd":"%s","prompt":"[pronto worker: nope]"}' "$RJ")"
check "a marker without a card file does not mark the session" test ! -d "$W/nocard"

hook mark "$(printf '{"session_id":"plain","cwd":"%s","prompt":"/pronto add dark mode"}' "$RJ")"
hook gate "$(printf '{"session_id":"plain","cwd":"%s"}' "$RJ")"
expect "a normal session stops freely" 0
check "and gets no Pronto message" test -z "$out$err"

echo 2 > "$W/live/rejects"
hook mark "$(printf '{"session_id":"live","cwd":"%s","prompt":"[pronto worker: time-greeting]\\nagain"}' "$WT")"
check "a worker that sees the marker again is not reset" grep -qx 2 "$W/live/rejects"

# Windows: a cwd with escaped backslashes and a space, worker in a subfolder of the repo.
R="$T/my repo"
mkdir -p "$R/sub" "$R/.pronto"
g init -q
printf '[pronto worker: x]\n```pronto-checks\necho "FAIL from real path"; exit 1\n```\n' > "$R/.pronto/x.md"
SUB="$(jpath "$R/sub")"
hook mark "$(printf '{"session_id":"esc","cwd":"%s","prompt":"[pronto worker: x] go"}' "$SUB")"
hook gate "$(printf '{"session_id":"esc","cwd":"%s"}' "$SUB")"
expect "an escaped path with a space finds the repo and runs its checks" 2 "FAIL from real path"

finish
