---
type: llm
focus: trace
weight: 1
---

The pronto-checks block runs that new test (for example `node --test <file>` or a test script the worker adds) and has at least one command that calls slugify with an accented input and compares the result.
