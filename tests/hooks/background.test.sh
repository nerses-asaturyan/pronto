#!/usr/bin/env bash
# The Claude desktop app runs the reviewer in the background and hands its report back as a prompt.
. "$(dirname "$0")/lib.sh"

R="$T/proj"
mkdir -p "$R/.pronto"
g init -q
echo hi > "$R/greet.js"
g add greet.js
g commit -q -m init
printf '[pronto worker: t1]\n## Checks\n```pronto-checks\ngrep -q hi greet.js\n```\n' > "$R/.pronto/t1.md"
RJ="$(jpath "$R")"
# The start of the app's hand-back prompt, as it arrived in the live test.
HB='Another Claude session sent a message:\n<agent-message from=\\"x\\">\n[Subagent hand-back] The reviewer finished.\nThe report follows:\n  '

# stop <background_tasks JSON>
stop() { hook gate "$(printf '{"session_id":"s1","cwd":"%s","last_assistant_message":"Done.","background_tasks":%s}' "$RJ" "$1")"; }
prompt() { hook mark "$(printf '{"session_id":"%s","cwd":"%s","prompt":"%s"}' "$1" "$RJ" "$2")"; }

prompt s1 '[pronto worker: t1]\nDo it'
expect "worker starts" 0 "1 check(s) saved"

stop '[{"id":"b1","type":"shell"}]'
expect "a background job before any review request does not skip the request" 2 "review of this exact work"

stop '[{"id":"a1","type":"agent"}]'
expect "while the reviewer runs in the background, the worker may wait" 0 "not verified yet"
check "waiting does not use up a try" grep -qx 1 "$W/s1/asks"

stop '["a1"]'
expect "a background list of plain strings also counts" 0 "not verified yet"

prompt s1 "${HB}**ACCEPT**\n- all good"
check "the hand-back prompt's ACCEPT is saved" grep -qx ACCEPT "$W/s1/review"
stop '[]'
expect "the next stop is accepted" 0 "reviewer accepted the work"

prompt s1 "${HB}REJECT\n- missing test"
stop '[]'
expect "a hand-back REJECT blocks the stop" 2 "rejected the work (try 1 of 3)"

prompt other "${HB}ACCEPT"
check "a hand-back in a session that is not a worker creates nothing" test ! -d "$W/other"

rm -f "$W/s1/review"
prompt s1 'The report follows: ACCEPT'
check "ACCEPT typed in a normal prompt (no hand-back tag) is not a verdict" test ! -f "$W/s1/review"

prompt s1 "${HB}ACCEPT"
echo bye >> "$R/greet.js"
stop '[]'
expect "a hand-back verdict for older work does not count" 2 "review of this exact work"

finish
