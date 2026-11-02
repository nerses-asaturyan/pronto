# Pronto

Turn a rough request into a clear task, hand it to a fresh Claude Code session, and only let that session finish when the work is proven.

```
/pronto add dark mode to the settings page
```

Or just ask in plain words: "use pronto to add dark mode to the settings page".

## What happens

1. **Pronto plans with you.** It reads your project, then writes a task card: goal, limits, "done when", check commands, what needs your OK, and what is out of scope.
2. **It asks only what matters.** At most 3 questions, with ready options. Small things get safe defaults, listed on the card.
3. **You approve the card.** Nothing starts until you say OK.
4. **A worker session does the job.** It is a new Claude Code session you can watch and talk to.
5. **The work is checked twice before the worker can finish:**
   - the card's **check commands** must pass (for example `forge test --match-test test_DarkMode`);
   - an **independent reviewer**, an agent that did not write the code, reads the card and the changes and tries to find reasons to reject them.
6. If either says no, the worker gets the reason and keeps working. After 3 failed tries it stops and tells you the task is not done.
7. **You get a result file.** `.pronto/<slug>.result.md` says whether the work was accepted, shows the checks, and keeps the reviewer's report, with evidence for each "done when" line and notes on weak checks.

Your own projects need no setup. Pronto writes the checks for each task. If a project has no tests, the card makes the worker write a test for the change, and the check runs it.

It all runs inside Claude Code with your normal login, so it uses your plan's usage. There is no separate API bill.

## Install

In Claude Code:

```
/plugin marketplace add nerses-asaturyan/pronto
/plugin install pronto@pronto
```

Then type `/pronto` (or `/pronto:pronto` if another command already uses the name), or ask Claude to use Pronto. It works in every new session after the install.

To update, run `/plugin marketplace update pronto`. To get updates by itself, open `/plugin`, go to Marketplaces, pick `pronto` and turn on auto-update.

To try it without installing, clone this repo and run `claude --plugin-dir ./pronto` from the folder that contains it.

## What it runs on your machine

Pronto is a plugin with a hook, so it runs code on your computer with your user rights. Here is all of it:

- **One bash script, `hooks/pronto-hook.sh`.** It runs when you send a message, when a session tries to stop, and when a subagent finishes. In a normal session it only looks for the worker line and exits.
- **Your card's check commands.** In a worker session, the script runs the check commands from the card you approved, every time the worker tries to stop. Read them before you say OK.
- **Tools it uses:** bash, git, grep, sed, awk and other basic shell tools. Git is only read, except for a temporary index used to fingerprint the work; your own index and commits are not touched.
- **The planner's helper, `skills/pronto/scripts/card-info.sh`.** It reads git and your project files, and uses `node` (if installed) to list the scripts in `package.json`.
- **Files it writes:** `.pronto/` in your project and a `pronto-workers` folder in your temp folder. Nothing else.
- **Network:** none. Pronto sends and fetches nothing. Your check commands may, if you write them that way.

## How it works

| File | What it does |
|---|---|
| `skills/pronto/SKILL.md` | The `/pronto` command: plain instructions Claude follows to plan the task with you. |
| `skills/pronto/card-template.md` | The task card. Its first line, `[pronto worker: <slug>]`, marks the new session as a worker. |
| `skills/pronto/examples/time-greeting.md` | A real card that a worker finished and the reviewer accepted, for the level of detail. |
| `skills/pronto/references/checks.md` | How to write checks that really prove the work, per stack (Node, Foundry, Hardhat, Rust, Go, Python, docs). |
| `skills/pronto/scripts/card-info.sh` | Prints a free task name, the starting commit, and the project's test commands. |
| `agents/reviewer.md` | The independent reviewer. It can read files and run commands, and it must answer ACCEPT or REJECT. |
| `hooks/pronto-hook.sh` | The gate. See below. |
| `tests/` | Tests for the gate. Run `bash tests/run.sh`. |

The hook runs at three moments:

- **The worker starts:** it saves a copy of the card and its checks. Editing the card later changes nothing.
- **The worker tries to stop:** it runs the saved checks. If they pass, it asks for a review. The worker may only stop after the reviewer accepts this exact version of the work. Any change after the review needs a new review.
- **The reviewer finishes:** the hook records its verdict itself, so the worker never writes it. If the reviewer runs in the background, the worker may stop while it waits. Pronto then says "not verified yet", and the check runs again when the verdict comes back.
- **The worker is allowed to stop:** the hook writes `.pronto/<slug>.result.md` next to the card.

Normal sessions are never touched. A worker that needs to ask you something starts its message with `[pronto waiting]`, so it can stop and wait for your answer.

Task cards and notes live in `.pronto/` in your project. Add `.pronto/` to your `.gitignore`.

## Good to know

- If `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN` or an `apiKeyHelper` setting is present, Claude Code uses that instead of your plan login. Remove them to stay on your plan, and check with `/status`.
- The review uses your plan's usage too, about one extra agent run per finished task.
- The hook needs `bash`. On Windows, install Git for Windows so Claude Code can use Git Bash.
- The planning step is instructions, so Claude follows it well but not perfectly. The checks and the review are enforced by the hook.
- The gate stops honest mistakes, not a worker that tries to cheat on purpose: a worker could, in theory, write the verdict file itself.
- Pronto keeps a little state per worker in your temp folder (`pronto-workers`). State not used for 7 days is deleted when a new worker starts.

## License

MIT, see [LICENSE](LICENSE).
