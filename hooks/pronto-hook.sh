#!/usr/bin/env bash
# pronto hook: worker sessions may only stop after their task's checks pass and the reviewer accepts.
#   pronto-hook.sh mark    UserPromptSubmit: a prompt with a line "[pronto worker: <slug>]" marks the
#                          session, if .pronto/<slug>.md exists, and saves a copy of the card and checks.
#                          In a marked session, a background reviewer's report (it arrives as a prompt
#                          in the Claude desktop app) records the verdict.
#   pronto-hook.sh gate    Stop: in a marked session, run the saved checks, then require a review.
#                          Every allowed stop writes .pronto/<slug>.result.md next to the card.
#   pronto-hook.sh review  SubagentStop: if the subagent is the reviewer, record its verdict
# Any other session is left alone. Uses only bash, git, grep, sed, awk and date.
set -u

MAX_TRIES=3
KEEP_DAYS=7
input="$(tr -d '\r\n')"

# Value of a top-level string field in the hook's JSON input, with \\ unescaped.
field() {
  printf '%s' "$input" | grep -o "\"$1\" *: *\"[^\"]*\"" | head -n 1 \
    | sed 's/^[^:]*: *"//; s/"$//; s/\\\\/\\/g'
}

# A JSON string value that may hold escaped quotes, still escaped. Use json_unescape on it.
json_string() {
  printf '%s' "$input" | grep -o -E "\"$1\" *: *\"([^\"\\\\]|\\\\.)*\"" | head -n 1 \
    | sed -E 's/^"[^"]*" *: *"//; s/"$//'
}

# Escaped backslashes are set aside first, so a path like C:\\Users\\ana\\notes does not turn \n into a new line.
json_unescape() {
  awk '{ gsub(/\\\\/, "\001"); gsub(/\\n/, "\n"); gsub(/\\t/, "\t"); gsub(/\\"/, "\""); gsub(/\001/, "\\"); print }'
}

# ACCEPT or REJECT, if the text's first non-blank line starts with it (markdown marks allowed).
first_verdict() {
  printf '%s\n' "$1" | sed '/[^[:space:]]/,$!d' | head -n 1 \
    | grep -o -E '^[[:space:]*_#]*(Verdict:[[:space:]*]*)?(ACCEPT|REJECT)' | grep -o -E 'ACCEPT|REJECT'
}

session="$(field session_id)"
[ -n "$session" ] || exit 0
workers="${TMPDIR:-/tmp}/pronto-workers"
state="$workers/$session"

# Opt-in debug log: create the file $workers/debug to record which hooks fire (no prompt text).
debug() {
  [ -f "$workers/debug" ] && printf '%s %s session=%s %s\n' "$(date '+%F %T')" "${1:-}" "$session" "${2:-}" >> "$workers/debug.log"
  return 0
}
debug "${1:-}"

to_unix() {
  if [ -n "$1" ] && command -v cygpath > /dev/null 2>&1; then cygpath -u "$1"; else printf '%s' "$1"; fi
}
to_native() {
  if command -v cygpath > /dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi
}

# The session's folder. It follows worktrees; CLAUDE_PROJECT_DIR does not.
session_dir() {
  local dir
  dir="$(to_unix "$(field cwd)")"
  printf '%s' "${dir:-${CLAUDE_PROJECT_DIR:-.}}"
}

# Folders that may hold .pronto/<slug>.md: the main checkout (worktrees share it), the repo root,
# the session's folder, and the project folder.
card_dirs() {
  local common
  common="$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2> /dev/null)"
  [ -n "$common" ] && dirname "$common"
  git -C "$1" rev-parse --show-toplevel 2> /dev/null
  printf '%s\n' "$1"
  [ -n "${CLAUDE_PROJECT_DIR:-}" ] && printf '%s\n' "$CLAUDE_PROJECT_DIR"
}

# Lines inside the ```pronto-checks block, without blanks, comments or template placeholders.
read_checks() {
  awk '/^```pronto-checks/ { inside = 1; next } inside && /^```/ { inside = 0 } inside' "$1" \
    | grep -v -E '^[[:space:]]*(#|<|$)'
}

# Go to the folder the worker started in: its repo or worktree root.
go_root() {
  local root
  root="$(cat "$state/root" 2> /dev/null)"
  cd "${root:-$(session_dir)}"
}

# Fingerprint of the current work (tracked and untracked files, outside .pronto/).
# A review only counts for the exact work it saw.
work_fingerprint() {
  local idx tree
  git rev-parse --is-inside-work-tree > /dev/null 2>&1 || { printf 'no-git'; return; }
  idx="$(mktemp)"
  cp "$(git rev-parse --git-path index)" "$idx" 2> /dev/null
  GIT_INDEX_FILE="$idx" git add -A -- . ':(exclude).pronto' > /dev/null 2>&1
  tree="$(GIT_INDEX_FILE="$idx" git write-tree 2> /dev/null)"
  rm -f "$idx"
  printf '%s' "${tree:-unknown}"
}

# Save the reviewer's verdict (ACCEPT or REJECT) and report for the work as it is now.
record_verdict() {
  go_root || return 0
  printf '%s\n%s\n' "$(work_fingerprint)" "$1" > "$state/review"
  printf '%s\n' "${3:-}" > "$state/review.txt"
  printf '0' > "$state/asks"
  debug "${2:-verdict}" "verdict=$1"
}

# Forget workers that have not been seen for KEEP_DAYS days.
clean_old_state() {
  local d seen now
  now="$(date +%s)"
  for d in "$workers"/*/; do
    [ -d "$d" ] || continue
    seen="$(cat "$d/seen" 2> /dev/null || date -r "$d" +%s 2> /dev/null)"
    [ -n "$seen" ] && [ $((now - seen)) -gt $((KEEP_DAYS * 86400)) ] && rm -rf "$d"
  done
  return 0
}

count() { cat "$state/$1" 2> /dev/null || echo 0; }

block() {
  printf '%s\n' "$@" >&2
  exit 2
}

allow_with() {
  printf '{"systemMessage":"pronto: %s"}\n' "$1"
  exit 0
}

# Write the outcome next to the task card, so the user and the planner session can read it later.
write_result() {
  local card slug
  card="$(cat "$state/cardpath" 2> /dev/null)"
  slug="$(cat "$state/slug" 2> /dev/null)"
  [ -n "$card" ] && [ -n "$slug" ] || return 0
  {
    printf '# Pronto result: %s\n\n' "$slug"
    printf -- '- Status: %s\n' "$1"
    printf -- '- Time: %s\n' "$(date '+%F %T')"
    printf -- '- Worker folder: %s\n' "$(to_native "$PWD")"
    if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
      printf -- '- Branch: %s at %s\n' "$(git branch --show-current 2> /dev/null)" "$(git rev-parse --short HEAD 2> /dev/null)"
    fi
    printf '\n%s%s\n\n## Checks\n\n```\n%s\n```\n' "$(printf '%s' "${2:0:1}" | tr '[:lower:]' '[:upper:]')" "${2:1}" \
      "$(printf '%s' "${report:-Not run.}" | sed '/^$/d')"
    if [ -s "$state/review.txt" ]; then
      printf '\n## Last review\n\n%s\n' "$(cat "$state/review.txt")"
    fi
  } > "$(dirname "$card")/$slug.result.md" 2> /dev/null
  return 0
}

# Allow the stop, tell the user, and keep the outcome in the result file.
finish_with() {
  write_result "$1" "$2"
  allow_with "$2"
}

case "${1:-}" in
  mark)
    if [ -d "$state" ]; then
      # Already a worker. In the desktop app a background reviewer's report arrives as a prompt
      # that the app writes, so the worker cannot fake it.
      if printf '%s' "$input" | grep -qF '[Subagent hand-back]'; then
        text="$(printf '%s' "$input" | sed -n 's/.*The report follows:\(.*\)$/\1/p' \
          | sed 's/<\/agent-message>.*//; s/" *, *"[a-z_]*" *:.*//; s/" *} *$//' | json_unescape)"
        verdict="$(first_verdict "$text")"
        [ -n "$verdict" ] && record_verdict "$verdict" verdict-from-handback "$text"
      fi
      exit 0
    fi

    # The marker may follow text that the app puts before the card, so accept it at the start
    # of the prompt or at the start of any line (\n in the JSON string).
    slug="$(printf '%s' "$input" | grep -o -E '("prompt" *: *"|\\n)\[pronto worker: [A-Za-z0-9._-]+\]' \
      | head -n 1 | sed 's/.*worker: //; s/\]$//')"
    [ -n "$slug" ] || exit 0
    dir="$(session_dir)"

    card=""
    while IFS= read -r d; do
      [ -f "$d/.pronto/$slug.md" ] && { card="$d/.pronto/$slug.md"; break; }
    done < <(card_dirs "$dir")
    # No card, no worker: a session that only mentions the marker is left alone.
    [ -n "$card" ] || exit 0

    clean_old_state
    mkdir -p "$state"
    printf '%s' "$slug" > "$state/slug"
    printf '%s' "$card" > "$state/cardpath"
    date +%s > "$state/seen"
    printf '0' > "$state/fails"
    printf '0' > "$state/rejects"
    printf '0' > "$state/asks"
    root="$(git -C "$dir" rev-parse --show-toplevel 2> /dev/null)"
    printf '%s' "${root:-$dir}" > "$state/root"
    cp "$card" "$state/card.md"
    read_checks "$card" > "$state/checks"
    allow_with "worker for task $slug. $(grep -c . "$state/checks") check(s) saved. It can finish only after they pass and the reviewer accepts."
    ;;

  gate)
    [ -d "$state" ] || exit 0
    date +%s > "$state/seen"
    go_root || exit 0
    report=""

    # The worker is waiting for the user: let it stop this time.
    if printf '%s' "$input" | grep -qF '[pronto waiting]'; then
      write_result "WAITING FOR YOU" "The worker stopped to ask you a question. Answer it in the worker session."
      exit 0
    fi

    # 1. Commands from the task card.
    failed=0
    while IFS= read -r cmd; do
      if out="$(bash -c "$cmd" < /dev/null 2>&1)"; then
        report+="PASS  $cmd"$'\n'
      else
        report+="FAIL  $cmd"$'\n'"$(printf '%s\n' "$out" | tail -n 30)"$'\n'
        failed=1
        break
      fi
    done < "$state/checks"

    if [ "$failed" -eq 1 ]; then
      fails=$(($(count fails) + 1))
      printf '%s' "$fails" > "$state/fails"
      [ "$fails" -ge "$MAX_TRIES" ] && { printf '0' > "$state/fails"; finish_with "NOT DONE" "checks failed $MAX_TRIES times, so the worker was allowed to stop. The task is NOT done."; }
      block "pronto: a check failed (try $fails of $MAX_TRIES). The task is not done yet." \
        "Fix the code, not the tests. If you need the user, start your message with [pronto waiting] and ask." \
        "--- checks ---" "$report"
    fi
    printf '0' > "$state/fails"

    # 2. Independent review of this exact work.
    fingerprint="$(work_fingerprint)"
    reviewed="$(sed -n 1p "$state/review" 2> /dev/null)"
    verdict="$(sed -n 2p "$state/review" 2> /dev/null)"

    if [ "$reviewed" = "$fingerprint" ] && [ "$verdict" = ACCEPT ]; then
      rm -f "$state/review"
      printf '0' > "$state/rejects"
      printf '0' > "$state/asks"
      finish_with "ACCEPTED" "checks passed and the reviewer accepted the work."
    fi

    if [ "$reviewed" = "$fingerprint" ] && [ "$verdict" = REJECT ]; then
      rm -f "$state/review"
      rejects=$(($(count rejects) + 1))
      printf '%s' "$rejects" > "$state/rejects"
      [ "$rejects" -ge "$MAX_TRIES" ] && { printf '0' > "$state/rejects"; finish_with "NOT DONE" "the reviewer rejected the work $MAX_TRIES times, so the worker was allowed to stop. The task is NOT done."; }
      block "pronto: the reviewer rejected the work (try $rejects of $MAX_TRIES)." \
        "Fix every point in its reply, then stop again. Do not argue with the review."
    fi

    # A review was asked for and may still be running in the background: wait for it without
    # using up a try.
    if [ "$(count asks)" -ge 1 ] && printf '%s' "$input" | grep -q -E '"background_tasks" *: *\[ *[^] ]'; then
      finish_with "WAITING FOR REVIEW" "checks passed. Waiting for background work, such as the review, to finish. The task is not verified yet."
    fi

    # No review yet, or the work changed after the last review.
    asks=$(($(count asks) + 1))
    printf '%s' "$asks" > "$state/asks"
    [ "$asks" -gt "$MAX_TRIES" ] && { printf '0' > "$state/asks"; finish_with "NOT VERIFIED" "the worker stopped without a review of its final work. The task is NOT verified."; }
    block "pronto: checks passed. Before you finish, get the independent review of this exact work:" \
      "- Use the Agent tool with subagent_type \"pronto:reviewer\" (if that name is not found, use \"reviewer\")." \
      "- Run it in the foreground and wait for its answer, if your Agent tool lets you choose." \
      "- Prompt: Review the Pronto task card at $(to_native "$state/card.md"). The project is $(to_native "$PWD"). Then add your own short summary of what you did and how you checked it, so the reviewer can check your claims." \
      "- Do not change any file after the review starts. Then stop, and Pronto reads its verdict." \
      "--- checks ---" "$report"
    ;;

  review)
    agent="$(field agent_type)"
    # Field names only (no values), to learn what this Claude Code version sends.
    debug review-agent "agent_type=$agent keys=$(printf '%s' "$input" | grep -o -E '"[a-z_]+" *:' | tr -d '": ' | sort -u | tr '\n' ',')"
    case "$agent" in *reviewer*) ;; *) exit 0 ;; esac
    # The worker's state is keyed by the parent session; fall back to the parent transcript's name.
    transcript="$(to_unix "$(field transcript_path)")"
    if [ ! -d "$state" ]; then
      state="$workers/$(basename "$transcript" .jsonl)"
      [ -d "$state" ] || exit 0
    fi

    text="$(json_string last_assistant_message | json_unescape)"
    verdict="$(first_verdict "$text")"
    if [ -z "$verdict" ]; then
      # In the Claude desktop app a background reviewer ends with a SubagentHandback tool call, so
      # its report is in its own transcript, not in last_assistant_message.
      agent_log="$(to_unix "$(field agent_transcript_path)")"
      [ -f "$agent_log" ] || agent_log="${transcript%.jsonl}/subagents/agent-$(field agent_id).jsonl"
      if [ -f "$agent_log" ]; then
        text="$(grep -o -E '"name" *: *"SubagentHandback" *, *"input" *: *\{ *"message" *: *"([^"\\]|\\.)*"' "$agent_log" \
          | tail -n 1 | sed -E 's/.*"message" *: *"//; s/"$//' | json_unescape)"
        verdict="$(first_verdict "$text")"
      fi
    fi
    [ -n "$verdict" ] && record_verdict "$verdict" verdict-from-review "$text"
    ;;
esac
exit 0
