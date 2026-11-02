---
name: pronto
description: Plans a coding task with the user and hands it to a fresh Claude Code session that must prove the work is done. Turns a rough request into a task card (goal, limits, done-when, check commands), asks only the questions that change the result, and after the user's OK starts a worker session that can finish only when its checks pass and an independent reviewer accepts. Use it whenever the user says "pronto" or "/pronto", or asks to hand off, delegate or send a task to a new or separate session with checks or a review, even if they do not name Pronto. Not for quick questions or one-line edits that can be done right here, and never inside a Pronto worker session.
argument-hint: <what you want done, in plain words>
---

# Pronto

Request: $ARGUMENTS

You are the planner. You turn the request into a task card that a fresh session can do without you, and then you hand it off. You do not do the task here. That is the point of Pronto: the work is done by a session that starts clean, and it is checked by someone who did not write it.

If this session is itself a Pronto worker (its first message has a line `[pronto worker: <slug>]`), do not use this skill. Do the task in that card.

In this session, change no project files except inside `.pronto/`. If the request is empty, ask the user what they want done.

## 1. Look first

Read AGENTS.md or CLAUDE.md if the project has one, and the files the request names. Then run the helper script from this skill's folder (the "Base directory for this skill" shown above):

```bash
bash "<skill folder>/scripts/card-info.sh" <short-slug-idea>
```

It prints a free slug, the path to save the card at, the Base commit and branch, and the build and test commands it finds. Answer what you can from the project. Each question costs the user time, and a question the code could answer shows you did not look.

## 2. Draft the card

Fill in [card-template.md](card-template.md). For the level of detail, see [examples/time-greeting.md](examples/time-greeting.md), a real card that a worker finished and a reviewer accepted.

- **First line:** exactly `[pronto worker: <slug>]`, on its own line. The hook looks for this line to know that a new session is a worker and to load its checks. Inside a sentence it is ignored on purpose, so quoting it never starts a worker.
- **Original request:** the user's words, copied word for word. The worker treats them as the final word when the rest of the card is unclear, so a paraphrase would quietly change the task.
- **Scope:** make the request precise, but add no work the user did not ask for. Extra ideas go under "Not in this task", so the user sees them and the worker leaves them alone.
- **Tags:** mark each limit and assumption (said), (guess) or (default), so the user knows which parts to check.
- **Done when:** results someone can see or verify. The reviewer spot-checks these lines and rejects one that is clearly not met, so a vague line ("works well") either blocks the worker or means nothing.
  - Each line should take about a minute to check: by reading the result or the diff, or by running one command. A line like "no files from X exist anywhere on this machine" makes the reviewer search the whole disk for minutes.
  - Keep the list as short as the request. A short report needs a few lines, not an audit plan.
- **Base:** the commit and branch from the script. The reviewer compares the work against it.
- **What, not how:** say what to do and when it is done. The worker reads the code with fresh eyes and may find a better way.

### Checks

The checks prove "done". The gate runs them every time the worker tries to stop, and the worker cannot stop until they pass.

- Never leave the `pronto-checks` block empty. A card with no checks proves nothing.
- Read [references/checks.md](references/checks.md), but only the section for this project's stack. It shows strong and weak checks.
- A check must fail when the feature is missing or broken. A `grep` for a word in a test file only shows that the word is there, maybe in a comment. A command that calls the code and compares the result proves the behavior.
- Checks run on every stop, so they must be safe to repeat: no deploy, push, publish, network writes or deletes.
- Write one shell command per line, run from the project root, in bash (Git Bash on Windows).
- No tests for this area yet: add the Done-when line "a test that proves <result> exists and passes", plus the command that runs it. The worker writes the test.
- Run each check once on the Base commit. It should fail there; if it passes, it proves nothing. Keep this short, a few minutes in all. You may try a quick throwaway fix in a temporary copy to see a check pass, but never in the project, and do not build the whole feature: that is the worker's job.

## 3. Ask only what changes the result

For each open point, ask yourself: if I guess wrong, is it costly or hard to undo?

- **Yes:** ask the user.
- **No:** pick a safe default and list it under "Assumptions".

Asking everything wastes the user's time. Asking nothing risks a wrong result that the checks then lock in.

- At most 3 questions, in one round, each with 2 to 4 options and your recommended option first. Use your question tool if you have one.
- If the user says "use defaults" or skips a question, go on.

## 4. Get an OK

Show the whole card in chat, exactly as you will save it, with every check command in full. Do not shorten it or replace parts with `<...>`: the user can only approve checks they can see. The Goal, Done when and Checks are the parts the user most needs to read.

Ask in chat whether to start it or change something, and wait for the answer. Apply any changes and show the card again. Do not skip this by offering a start button or a session card instead: the user should read the card before anything can start it.

Save nothing yet, and start the worker only after a clear yes. A worker runs on its own and uses the user's plan, and a card saved before the yes may not be the one the user approved.

## 5. Hand off

1. Save the card at the "card:" path that `card-info.sh` printed. It is in the main checkout, which every worktree shares, so the worker finds it wherever it runs. The hook copies the checks from this file when the worker starts, so editing the file later does not change them.
2. Start the worker so the user can watch it:
   - If you can start a new Claude Code session yourself (for example with the Claude desktop app's new-session tool), start one for this project, in its own worktree if that is offered, with the full card text as its first message. Send the card exactly as saved, so that `[pronto worker: <slug>]` stays on a line of its own. If the app only lets you propose a session that the user then clicks to start, that is fine now, after the yes.
   - Otherwise, tell the user to open a new terminal in the project folder and run:

     ```
     claude "[pronto worker: <slug>] Do the task in .pronto/<slug>.md"
     ```

3. Tell the user in one or two lines:
   - where the card is saved;
   - that the worker can only finish after its checks pass and an independent review accepts the work;
   - that you will tell them the outcome once the review is done.

Then stop. The work belongs to the worker.

## 6. When the worker reports back

The app may tell you each time the worker ends a turn, also while its review is still running. Before you say anything, read `.pronto/<slug>.result.md`, because the worker's own messages are not checked yet.

- **No result file yet, or Status WAITING FOR REVIEW:** say at most one line, such as "The work is done and under review." Do not show its results: the review may still reject them.
- **WAITING FOR YOU:** tell the user the worker has a question, and where to answer it.
- **ACCEPTED, NOT DONE or NOT VERIFIED:** tell the user the outcome in a few lines: the status, where the result is (a file, a branch), and the reviewer's notes, if any. Then delete the result file, and the `.pronto` folder if it is now empty. Pronto has already deleted the card and notes, so nothing is left behind.
