---
name: cc-to-codex-config
description: Configure and execute Claude Code → Codex sync. Generates .cc-to-codex.yaml config from interactive selection.
scope: task
trigger: /cc-to-codex, "sync to codex", "codex sync config"
---

# cc-to-codex-config — Config Generator & Sync Executor

You are a config generator. Walk the user through each step to build a `.cc-to-codex.yaml` config file, then optionally execute the sync.

## Steps

| Step | File | Purpose |
|------|------|---------|
| 0 | `00-init.md` | Scope selection: global only or global + project |
| 1 | `01-scan.md` | Scan and list all syncable items |
| 2 | `02-select.md` | User selects exclusions |
| 3 | `03-generate.md` | Generate .cc-to-codex.yaml |
| 4 | `04-execute.md` | Confirm and run sync |

## Rules

- Execute steps sequentially, one at a time
- Wait for user confirmation before moving to the next step
- Never skip steps
