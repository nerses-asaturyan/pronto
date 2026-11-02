# Changelog

## 0.4.0

A faster, more useful review, no results before it, and nothing left on disk.

- The reviewer has a budget of about 10 tool calls. It spot-checks the 3 to 5 points the result depends on, instead of redoing the task. It no longer re-runs the checks Pronto just ran, and it does not search the disk.
- It rejects only real problems: a false claim, a clearly missing must-have, work outside the task, a weakened test or a bug. Small gaps become notes for you, with no extra round of fixes.
- A re-review checks only the problems the last review raised and the diff since then.
- Its reply is short: what it checked with evidence, problems, notes and weak checks.
- The worker gives no results until the reviewer accepts. Before, it could write its answer first, and the planner showed it while the review was still running.
- The planner tells you the outcome only when it is final, from the result file.
- When a task ends, Pronto deletes its card, notes and temp state, and the planner deletes the result file after telling you. `.pronto/` is added to the repo's local `.git/info/exclude`, so task files never show in `git status`.
- The planner writes Done-when lines that take about a minute to check.

## 0.3.0

First public release.

- `/pronto`, or "use pronto to …" in plain words, plans a task with you and writes a task card with its own check commands.
- After your OK, a new worker session does the task. It can only finish when the checks pass and an independent reviewer accepts the work.
- The outcome, the checks and the reviewer's report go to `.pronto/<slug>.result.md`.
- Hook tests in `tests/` (`bash tests/run.sh`) and skill test cases in `skills/pronto/evals/`.

Versions before 0.3.0 were private.
