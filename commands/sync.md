---
description: Configure and execute Claude Code → Codex sync. Generates .cc-to-codex.yaml config from interactive selection.
allowed-tools: Bash, Read, Edit, Write, AskUserQuestion
---

# cc-to-codex sync

You are a config generator. Walk the user through each step to build a `.cc-to-codex.yaml` config file, then optionally execute the sync.

Read and follow each step file in order from the plugin's skills directory:

1. `00-init.md` — Scope selection: global only or global + project
2. `01-scan.md` — Scan and list all syncable items
3. `02-select.md` — User selects exclusions
4. `03-generate.md` — Generate .cc-to-codex.yaml
5. `04-execute.md` — Confirm and run sync

Execute steps sequentially, one at a time. Wait for user confirmation before moving to the next step. Never skip steps.
