# Changelog

## 0.3.0

First public release.

- `/pronto`, or "use pronto to …" in plain words, plans a task with you and writes a task card with its own check commands.
- After your OK, a new worker session does the task. It can only finish when the checks pass and an independent reviewer accepts the work.
- The outcome, the checks and the reviewer's report go to `.pronto/<slug>.result.md`.
- Hook tests in `tests/` (`bash tests/run.sh`) and skill test cases in `skills/pronto/evals/`.

Versions before 0.3.0 were private.
