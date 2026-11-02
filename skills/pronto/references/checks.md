# Writing checks

Read "Strong and weak checks" first. Then read only the section for this project's stack.

- [Strong and weak checks](#strong-and-weak-checks)
- [Node, JavaScript, TypeScript](#node-javascript-typescript)
- [Solidity: Foundry](#solidity-foundry)
- [Solidity: Hardhat](#solidity-hardhat)
- [Rust](#rust)
- [Go](#go)
- [Python](#python)
- [Docs, config and other non-code work](#docs-config-and-other-non-code-work)

## Strong and weak checks

A check is strong when it **fails while the work is missing or wrong**. Before you keep a check, ask: would this check pass on the Base commit, before any work? If yes, it proves nothing about this task.

| Weak | Why it is weak | Strong |
|---|---|---|
| `npm test` alone, when no test covers the change | Passes before the work too | `npm test` plus a "Done when" line for the new test, and a check that runs that test by name |
| `grep -q "Good morning" greet.test.js` | Only shows that a word is in a file | A command that calls the code and compares the result (see the `node -e` check in `examples/time-greeting.md`) |
| `test -f docs/setup.md` | An empty file passes | `test -f docs/setup.md` plus a `grep -q` for each required heading |
| A test filter that may match nothing | Many runners pass when no test matches | Run the filter **and** check that the test exists: `grep -q "test_name" <test file>` |
| A lint command that only warns | Exits 0 even with warnings | Make warnings fail: `--max-warnings 0`, `-D warnings` |

A bare `grep` is fine as an extra check next to a behavior check, for example to show that a test with a given name exists. It should not be the only proof, and grepping a test file for the assert you expect is no stand-in for running the test.

Every check runs each time the worker tries to stop:
- Keep the commands fast and narrow: one test file or test name, plus the build or type check.
- Run the full suite only if it is quick.
- Never deploy, push, publish, write to the network, or delete anything.

## Node, JavaScript, TypeScript

Look at `package.json` "scripts" first, and use the project's own commands.

```
npm test
node --test --test-name-pattern "greeting"      # Node's built-in runner; passes if nothing matches
npx jest src/greet.test.js -t "greeting"        # Jest
npx vitest run src/greet.test.ts -t "greeting"  # Vitest
npx tsc --noEmit                                # when there is a tsconfig.json
npm run lint --if-present
npm run build --if-present
```

To prove behavior without a test runner, use `node -e "..."`: require the module, call it with fixed inputs, and `process.exit(1)` on a wrong answer. Pin clocks, random values and network calls so the check gives the same result every time.

## Solidity: Foundry

```
forge build
forge test --match-contract VaultTest --match-test test_withdrawAfterUnlock
grep -q "function test_withdrawAfterUnlock" test/Vault.t.sol
forge fmt --check
```

- Pair each `--match-test` with a `grep` that the test function exists, so a typo in the name cannot pass silently.
- Never use `--fork-url` with a paid or private RPC in a check. Fork tests belong in "Done when", run by the worker.

## Solidity: Hardhat

```
npx hardhat compile
npx hardhat test test/Vault.test.ts
grep -q "withdraws after unlock" test/Vault.test.ts
```

## Rust

```
cargo build
cargo test greet::tests::morning     # passes with 0 tests if the name matches nothing
grep -q "fn morning" src/greet.rs
cargo clippy -- -D warnings
cargo fmt --check
```

## Go

```
go build ./...
go test ./greet/... -run '^TestMorning$'   # passes with "no tests to run" if nothing matches
grep -q "func TestMorning" greet/greet_test.go
go vet ./...
test -z "$(gofmt -l .)"
```

## Python

```
python -m pytest tests/test_greet.py -k morning   # exits 5 if no test matches, so it fails loudly
ruff check .                                      # if the project uses ruff
python -m mypy src                                # if the project uses mypy
```

Use `python -c "..."` to call a function with fixed inputs, the same way as `node -e` above.

## Docs, config and other non-code work

A grep cannot tell a good doc from a bad one. Keep a few structure checks: the file exists and has the required sections.

```
test -f docs/setup.md
grep -q "^## Install" docs/setup.md
grep -q "^## Troubleshooting" docs/setup.md
! grep -q "TODO" docs/setup.md
python -c "import json; json.load(open('config/app.json'))"   # the JSON parses
```

Put the facts the doc must state in "Done when" (for example "names the NOTES_DIR variable and its default"). The reviewer checks them by reading the doc against the code. Do not turn each fact into a keyword grep:
- a short stub with the right words still passes them all;
- a grep for an exact phrase fails a correct doc that words it differently.

If the project already has a docs linter or link checker in its scripts or CI, add that command too.
