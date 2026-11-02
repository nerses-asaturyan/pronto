#!/usr/bin/env bash
# The result file, verdicts read from the reviewer's own transcript, and cleanup of old state.
. "$(dirname "$0")/lib.sh"

R="$T/main"
mkdir -p "$R/.pronto"
g init -q
echo base > "$R/app.txt"
g add app.txt
g commit -q -m init
printf '[pronto worker: dm]\n## Checks\n```pronto-checks\ngrep -q dark app.txt\n```\n' > "$R/.pronto/dm.md"
g worktree add -q "$T/wt" -b claude/dm
WT="$(jpath "$T/wt")"
RESULT="$R/.pronto/dm.result.md"
TP="$T/projects/w1.jsonl"
mkdir -p "${TP%.jsonl}/subagents"
TPJ="$(jpath "$TP")"

stop() { hook gate "$(printf '{"session_id":"w1","cwd":"%s","last_assistant_message":"Done.","background_tasks":%s}' "$WT" "${1:-[]}")"; }
has() { grep -qF -- "$1" "$RESULT"; }

hook mark "$(printf '{"session_id":"w1","cwd":"%s","prompt":"[pronto worker: dm] go"}' "$WT")"
expect "worker in a worktree starts" 0 "1 check(s) saved"

hook gate "$(printf '{"session_id":"w1","cwd":"%s","last_assistant_message":"[pronto waiting] Which color?"}' "$WT")"
expect "a worker asking the user may stop" 0
check "the result file is written next to the card in the main checkout" test -f "$RESULT"
check "and says it waits for you" has "Status: WAITING FOR YOU"
check "no result file is written inside the worktree" test ! -f "$T/wt/.pronto/dm.result.md"

echo dark >> "$T/wt/app.txt"
stop
stop '[{"id":"a1"}]'
expect "background review: the worker may wait" 0 "not verified yet"
check "the result says it waits for the review" has "Status: WAITING FOR REVIEW"

# The desktop app's background reviewer ends with a SubagentHandback call; last_assistant_message has no verdict.
printf '%s\n' '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_1","name":"SubagentHandback","input":{"message":"ACCEPT\n- Done when 1: app.txt line 2 says \"dark\""}}]}}' \
  > "${TP%.jsonl}/subagents/agent-a1.jsonl"
hook review "$(printf '{"session_id":"w1","transcript_path":"%s","agent_id":"a1","agent_type":"pronto:reviewer","last_assistant_message":""}' "$TPJ")"
check "the verdict is read from the reviewer's own transcript (path built from agent_id)" grep -qx ACCEPT "$W/w1/review"
check "the review text is saved with quotes and new lines unescaped" grep -qF 'app.txt line 2 says "dark"' "$W/w1/review.txt"

stop
expect "the next stop is accepted" 0 "reviewer accepted the work"
check "the result says ACCEPTED" has "Status: ACCEPTED"
check "the result lists the passing check" has "PASS  grep -q dark app.txt"
check "the result keeps the reviewer's report" has 'app.txt line 2 says "dark"'
check "the result names the worker's branch" has "Branch: claude/dm"

rm -f "$W/w1/review"
printf '%s\n' '{"type":"tool_use","name":"SubagentHandback","input":{"message":"REJECT\n- no test"}}' > "$T/agent-b2.jsonl"
hook review "$(printf '{"session_id":"w1","transcript_path":"%s","agent_transcript_path":"%s","agent_id":"zz","agent_type":"pronto:reviewer"}' "$TPJ" "$(jpath "$T/agent-b2.jsonl")")"
check "agent_transcript_path is used when the hook gets it" grep -qx REJECT "$W/w1/review"

rm -f "$W/w1/review"
hook review "$(printf '{"session_id":"w1","transcript_path":"%s","agent_type":"pronto:reviewer","last_assistant_message":"Verdict: **REJECT**\\n- missing test"}' "$TPJ")"
check "\"Verdict: REJECT\" as the first line counts" grep -qx REJECT "$W/w1/review"

rm -f "$W/w1/review"
hook review "$(printf '{"session_id":"w1","transcript_path":"%s","agent_type":"pronto:reviewer","last_assistant_message":"Looks fine to me.\\nACCEPT"}' "$TPJ")"
check "a verdict that is not on the first line is not counted" test ! -f "$W/w1/review"

hook review "$(printf '{"session_id":"w1","transcript_path":"%s","agent_type":"pronto:reviewer","last_assistant_message":"ACCEPT\\nFiles: C:\\\\Users\\\\ana\\\\notes\\\\a.js"}' "$TPJ")"
check "a Windows path in the report keeps its backslashes" grep -qxF 'Files: C:\Users\ana\notes\a.js' "$W/w1/review.txt"

# NOT DONE after three failed checks, in a second worker.
printf '[pronto worker: nd]\n```pronto-checks\nfalse\n```\n' > "$R/.pronto/nd.md"
RJ="$(jpath "$R")"
hook mark "$(printf '{"session_id":"w2","cwd":"%s","prompt":"[pronto worker: nd] go"}' "$RJ")"
for i in 1 2 3; do hook gate "$(printf '{"session_id":"w2","cwd":"%s"}' "$RJ")"; done
expect "three failed checks end the task" 0 "NOT done"
check "the result says NOT DONE and shows the failing check" grep -qF "FAIL  false" "$R/.pronto/nd.result.md"

# Cleanup: state of a worker not seen for 8 days goes, recent state stays.
mkdir -p "$W/old" "$W/recent"
echo $(($(date +%s) - 8 * 86400)) > "$W/old/seen"
date +%s > "$W/recent/seen"
printf '[pronto worker: c3]\n```pronto-checks\ntrue\n```\n' > "$R/.pronto/c3.md"
hook mark "$(printf '{"session_id":"w3","cwd":"%s","prompt":"[pronto worker: c3] go"}' "$RJ")"
check "old worker state is removed when a new worker starts" test ! -d "$W/old"
check "recent worker state is kept" test -d "$W/recent"
check "the active worker's state is kept" test -d "$W/w1"

finish
