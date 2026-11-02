# Shared helpers for the hook tests. Source it from a test file: . "$(dirname "$0")/lib.sh"
# Each test gets its own temp folder, its own TMPDIR (so Pronto's state stays inside it) and
# fake hook inputs shaped like the JSON Claude Code sends.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
H="$ROOT/hooks/pronto-hook.sh"
T="$(mktemp -d)"
export TMPDIR="$T/tmp"
mkdir -p "$TMPDIR"
W="$TMPDIR/pronto-workers"
unset CLAUDE_PROJECT_DIR
trap 'rm -rf "$T"' EXIT
PASSES=0
FAILS=0

# A path the way Claude Code writes it in hook JSON: native, with backslashes escaped.
jpath() {
  if command -v cygpath > /dev/null 2>&1; then
    local w
    w="$(cygpath -w "$1")"
    printf '%s' "${w//\\/\\\\}"
  else
    printf '%s' "$1"
  fi
}

# git in the test repo $R, with a fixed identity.
g() { git -C "$R" -c user.email=t@t -c user.name=t -c core.autocrlf=false -c commit.gpgsign=false "$@"; }

# hook <mode> <json>: run the hook and keep its exit code, stdout and stderr in $code, $out, $err.
hook() {
  printf '%s' "$2" | bash "$H" "$1" > "$T/out" 2> "$T/err"
  code=$?
  out="$(cat "$T/out")"
  err="$(cat "$T/err")"
}

pass() { PASSES=$((PASSES + 1)); printf 'ok    %s\n' "$1"; }
fail() {
  FAILS=$((FAILS + 1))
  printf 'FAIL  %s\n' "$1"
  [ -n "${2:-}" ] && printf '      %s\n' "$2"
  return 0
}

# expect <name> <exit code> [text]: the last hook call exited with that code, and its output has the text.
expect() {
  if [ "$code" != "$2" ]; then
    fail "$1" "exit $code, want $2: $(printf '%s%s' "$err" "$out" | head -n 1)"
  elif [ -n "${3:-}" ] && ! printf '%s\n%s\n' "$out" "$err" | grep -qF -- "$3"; then
    fail "$1" "output lacks: $3"
  else
    pass "$1"
  fi
}

# check <name> <command...>: the command succeeds.
check() {
  local name="$1"
  shift
  if "$@"; then pass "$name"; else fail "$name"; fi
}

finish() {
  printf -- '-- %s: %d ok, %d failed\n\n' "$(basename "$0")" "$PASSES" "$FAILS"
  [ "$FAILS" -eq 0 ]
}
