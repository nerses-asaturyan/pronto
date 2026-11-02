---
type: llm
focus: trace
weight: 1
---

The pronto-checks block checks that docs/setup.md exists and has install, configuration and troubleshooting sections (for example with test -f and grep). It has at most 8 commands, does not turn every fact into its own keyword grep, and does not use code test commands as the proof.
