#!/usr/bin/env bash
# Facts the Pronto planner needs for a new task card. Reads only; changes nothing.
#   card-info.sh [slug-idea] [project-dir]
# Prints a free slug, the Base commit and branch, and the build and test commands it finds.
set -u

idea="${1:-task}"
dir="${2:-.}"
cd "$dir" || exit 1
# Cards go in the main checkout, which every worktree of the repo shares, so a worker in any
# worktree finds them. Base is taken from where the planner is now.
common="$(git rev-parse --path-format=absolute --git-common-dir 2> /dev/null)"
if [ -n "$common" ]; then cards="$(dirname "$common")"; else cards="$(pwd)"; fi
here="$(git rev-parse --show-toplevel 2> /dev/null || pwd)"
cd "$here" || exit 1

# A short slug: lowercase letters, digits and hyphens. Add -2, -3 ... if a card already uses it.
base_slug="$(printf '%s' "$idea" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]\{1,\}/-/g; s/^-//; s/-$//' | cut -c1-40)"
base_slug="${base_slug:-task}"
slug="$base_slug"
n=2
while [ -e "$cards/.pronto/$slug.md" ]; do
  slug="$base_slug-$n"
  n=$((n + 1))
done

echo "slug: $slug"
if command -v cygpath > /dev/null 2>&1; then
  echo "card: $(cygpath -w "$cards/.pronto/$slug.md")"
else
  echo "card: $cards/.pronto/$slug.md"
fi
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "base: $(git rev-parse --short HEAD 2> /dev/null || echo 'no commits yet') on branch $(git branch --show-current 2> /dev/null || echo '(detached)')"
  [ -n "$(git status --porcelain 2> /dev/null)" ] && echo "note: there are uncommitted changes. The worker starts from the last commit, not from them."
else
  echo "base: not a git repo"
fi

for f in AGENTS.md CLAUDE.md; do
  [ -f "$f" ] && echo "read first: $f"
done

echo "found:"
if [ -f package.json ]; then
  if command -v node > /dev/null 2>&1; then
    node -e "const s=require('./package.json').scripts||{};for(const [k,v] of Object.entries(s))console.log('  npm run '+k+'  ->  '+v)" 2> /dev/null
  else
    echo "  package.json (open it for the scripts)"
  fi
  [ -f tsconfig.json ] && echo "  tsconfig.json: npx tsc --noEmit"
fi
[ -f foundry.toml ] && echo "  foundry.toml: forge build, forge test --match-test <name>"
ls hardhat.config.* > /dev/null 2>&1 && echo "  hardhat config: npx hardhat compile, npx hardhat test <file>"
[ -f Cargo.toml ] && echo "  Cargo.toml: cargo build, cargo test <name>, cargo clippy -- -D warnings"
[ -f go.mod ] && echo "  go.mod: go build ./..., go test ./... -run '<name>', go vet ./..."
if [ -f pyproject.toml ] || [ -f setup.py ] || [ -f pytest.ini ] || [ -f tox.ini ]; then
  echo "  python project: python -m pytest <file> -k <name>"
  grep -q '^\[tool\.ruff' pyproject.toml 2> /dev/null && echo "  ruff configured: ruff check ."
fi
if [ -f Makefile ]; then
  targets="$(grep -o -E '^[A-Za-z0-9_.-]+:' Makefile | tr -d ':' | grep -v -E '^\.' | head -n 12 | tr '\n' ' ')"
  [ -n "$targets" ] && echo "  Makefile targets: $targets"
fi
for wf in .github/workflows/*.yml .github/workflows/*.yaml .gitlab-ci.yml; do
  [ -f "$wf" ] && echo "  CI file (shows the real commands): $wf"
done
exit 0
