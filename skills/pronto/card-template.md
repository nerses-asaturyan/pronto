[pronto worker: <slug>]
# Task: <short title>

## Original request
The user's exact words. If anything below disagrees with this, this wins: stop and ask.

> <copy the request word for word>

## Goal
<one or two sentences: the result the user wants>

## Limits
- <limit> (said | guess | default)

## Deliverable
<what the user gets at the end, e.g. "the change and its tests committed on your work branch, ready to review. Not pushed.">

## Base
Work starts from commit <commit> on branch <branch>.

## Done when
- [ ] <a result someone can see or verify>
- [ ] <another result>

## Checks
Commands that must all pass before you can finish. They run from the project root.
Pronto runs its own saved copy of this list, so editing it here changes nothing.
Never delete, skip or weaken a test to make a check pass.

```pronto-checks
<one command per line>
```

## Ask the user before
- pushing, deploying, publishing or sending anything
- deleting data or files outside this task
- touching secrets, keys or .env files
- <anything else risky for this task>

## Not in this task
- <ideas that came up but the user did not ask for>

## Assumptions
Safe defaults picked for you. If one turns out wrong, tell the user.
- <assumption> (default)

## How to work
- Commit on a work branch, never on the main branch. If you are already on your own branch or worktree (for example one the app made for you), that is your work branch. Otherwise create `pronto/<slug>`.
- Read AGENTS.md or CLAUDE.md first if there is one. Open only the docs this task needs.
- Keep short notes in `.pronto/<slug>.notes.md`: current step, decisions and why, next action. Do not commit files in `.pronto/`.
- If the same error happens twice, stop and try a different approach. After 3 failed tries, stop and report what you tried.
- If you are stuck or need the user, start your message with `[pronto waiting]`, ask your question, and stop.
- When you think you are done, just stop. Pronto then runs the checks and asks for an independent review. Follow what it tells you.
