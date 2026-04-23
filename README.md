# codex-subagent

Use Codex as sub-agents in Claude Code.

## What's included

| Command | Description |
|---|---|
| `/codex-subagent:subagent` | Sub-agent dispatch protocol — context injection rules, CLI reference, multi-agent patterns |
| `/codex-subagent:sync` | Configure and sync Claude Code settings to Codex (`.claude` → `.codex`) |
| `/codex-subagent:setup` | Install `cx-read`/`cx-write` and configure Agent deny |

## Quick Start

### 1. Install the plugin

```bash
claude plugin add /path/to/codex-subagent
```

### 2. Run setup

```bash
bash /path/to/codex-subagent/setup.sh
```

This installs `cx-read` / `cx-write` to `~/.local/bin/` and configures the Agent tool deny in Claude Code settings.

### 3. Use sub-agents

```bash
cx-read "Explain the main function in main.py"
cx-write -C /path/to/repo "Add type hints to all functions in utils.py"
cx-read --name reviewer "Review the plan at .workflow/plan.md"
```

## Prerequisites

- [Codex CLI](https://github.com/openai/codex) (`npm install -g @openai/codex`)
- [jq](https://jqlang.github.io/jq/) (`brew install jq`)

## How it works

`cx-read` and `cx-write` are thin wrappers around `codex exec` that:
- Run Codex in read-only or workspace-write sandbox
- Strip intermediate output, returning only the final agent message
- Support named sessions for follow-up queries
- Auto-prepend a sub-agent guard to keep tasks focused

The `subagent` command provides the dispatch protocol that Claude Code follows when sending work to sub-agents — ensuring proper context injection and avoiding information asymmetry.
