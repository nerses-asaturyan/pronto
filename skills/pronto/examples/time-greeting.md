[pronto worker: time-greeting]
# Task: Time-of-day greeting in greet

## Original request
The user's exact words. If anything below disagrees with this, this wins: stop and ask.

> make greet say "Good morning" before noon and "Good evening" after 6 pm

## Goal
`greet(name)` in `greet.js` picks its greeting from the current local time: "Good morning" before noon, "Good evening" from 6 pm on, and the current "Hello" in between.

## Limits
- Before 12:00 the greeting is "Good morning" (said)
- From 18:00 on the greeting is "Good evening" (said; 18:00 itself counts as evening is a default)
- Between 12:00 and 17:59 the greeting stays "Hello" (default)
- The rest of the message keeps its current shape: `<greeting>, <name>!`, e.g. "Good morning, Ana!" (guess)
- "Time" means the machine's local time when `greet` is called (default)
- `greet("Ana")` with only a name keeps working; no new required arguments (default)
- No new packages; keep using Node's built-in test runner (default)

## Deliverable
The change and its tests committed on your work branch, ready to review. Not pushed (there is no remote).

## Base
Work starts from commit c449f1e on branch master.

## Done when
- [ ] `greet("Ana")` returns "Good morning, Ana!" from 00:00 to 11:59 local time
- [ ] `greet("Ana")` returns "Hello, Ana!" from 12:00 to 17:59 local time
- [ ] `greet("Ana")` returns "Good evening, Ana!" from 18:00 to 23:59 local time
- [ ] `greet.test.js` has tests for all three time windows and the edges 11:59, 12:00, 17:59 and 18:00
- [ ] `npm test` passes no matter what time of day it is run (tests do not depend on the real clock)
- [ ] The existing "greets by name" test still checks "Hello, Ana!"; it may pin a midday time so it stays true at any hour, but it is not deleted or loosened
- [ ] The change is committed on the work branch; master is unchanged

## Checks
Commands that must all pass before you can finish. They run from the project root.
Pronto runs its own saved copy of this list, so editing it here changes nothing.
Never delete, skip or weaken a test to make a check pass.

```pronto-checks
npm test
grep -q "Good morning" greet.test.js
grep -q "Good evening" greet.test.js
node -e "const R=Date;let t;global.Date=class extends R{constructor(...a){super(...(a.length?a:[t]))}static now(){return t}};const {greet}=require('./greet');for(const [h,m,want] of [[0,0,'Good morning, Ana!'],[9,0,'Good morning, Ana!'],[11,59,'Good morning, Ana!'],[12,0,'Hello, Ana!'],[17,59,'Hello, Ana!'],[18,0,'Good evening, Ana!'],[23,59,'Good evening, Ana!']]){t=new R(2026,0,1,h,m).getTime();const got=greet('Ana');if(got===want)continue;console.error(h+':'+m,JSON.stringify(got),'expected',JSON.stringify(want));process.exit(1)}"
```

## Ask the user before
- pushing, deploying, publishing or sending anything
- deleting data or files outside this task
- touching secrets, keys or .env files
- changing what `greet` returns between 12:00 and 17:59, or the `<greeting>, <name>!` shape

## Not in this task
- A "Good afternoon" greeting for 12:00 to 17:59
- Time zone options, other languages, or a configurable schedule
- Changes to package.json, CLAUDE.md or other docs

## Assumptions
Safe defaults picked for you. If one turns out wrong, tell the user.
- 12:00 to 17:59 keeps "Hello", since the request names no greeting for that window (default)
- 18:00 exactly counts as "after 6 pm", so it is evening (default)
- Midnight to noon is all "before noon", so 00:00 to 11:59 is "Good morning" (default)
- Only the first word(s) change: "Good morning, Ana!", not "Good morning Ana" or similar (guess)
- The machine's local time is used (default)

## How to work
- Commit on a work branch, never on the main branch. If you are already on your own branch or worktree (for example one the app made for you), that is your work branch. Otherwise create `pronto/time-greeting`.
- Read AGENTS.md or CLAUDE.md first if there is one. Open only the docs this task needs.
- Keep short notes in `.pronto/time-greeting.notes.md`: current step, decisions and why, next action. Do not commit files in `.pronto/`.
- If the same error happens twice, stop and try a different approach. After 3 failed tries, stop and report what you tried.
- If you are stuck or need the user, start your message with `[pronto waiting]`, ask your question, and stop.
- When you think you are done, just stop. Pronto then runs the checks and asks for an independent review. Follow what it tells you.
