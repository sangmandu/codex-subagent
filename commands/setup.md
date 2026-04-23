---
description: "Install cx-read/cx-write and configure Agent deny — run once to set up Codex sub-agent environment"
allowed-tools: Bash, Read, Write, AskUserQuestion
---

# codex-subagent setup

Run the setup script to install cx-read/cx-write binaries and configure Agent deny.

```bash
bash "$(dirname "$(claude plugin path codex-subagent 2>/dev/null || echo "$HOME/.claude/plugins/marketplaces/codex-subagent")")/setup.sh"
```

If `claude plugin path` is not available, run directly:

```bash
bash ~/.claude/plugins/marketplaces/codex-subagent/setup.sh
```

The script will:
1. Check prerequisites (codex, jq)
2. Install `cx-read` and `cx-write` to `~/.local/bin/`
3. Ask where to deny the Agent tool (global or project settings)
