---
description: "Sub-agent dispatch protocol — governs cx-read/cx-write CLI usage, context injection, and parallel execution patterns"
allowed-tools: Bash, Read
---

# Sub-Agent Dispatch Protocol

## CLI Reference

Do NOT use the `Agent` tool. Use `cx-read` / `cx-write` wrappers via Bash for all sub-agent work. These wrappers call `codex exec --json` internally and strip intermediate output, returning only the final agent message.

### Commands

| Command | Purpose |
|---|---|
| `cx-read "<prompt>"` | Read-only task |
| `cx-write "<prompt>"` | Task that creates/modifies files |
| `-C <DIR>` | Set working directory (e.g. `cx-read -C /path/to/repo "..."`) |
| `--name <handle>` | Named session — can be resumed after completion |

### Session Resumption

Reusing `--name <handle>` after the previous run has **completed** automatically resumes that codex session (no need to re-explain prior context). If it is still running, the call is rejected.

**In-progress sub-agents cannot be observed.** There is no way to inspect intermediate state while running — wait for completion, then re-invoke with the same handle to ask a follow-up.

### Parallel Execution

Claude Code runs Bash tool calls sequentially, even when placed in the same response block. For true parallel sub-agents, use `run_in_background: true` on each `cx-read` / `cx-write` call, then wait for the completion notifications — read the `output-file` path from the notification via `Read`. Do not poll.

---

## Context Injection Protocol

Sub-agents (codex) start with zero context — they know nothing about your conversation, your decisions, or the codebase you've been exploring. There is a fundamental **information asymmetry** between you (the orchestrator, who has full context) and the sub-agent (who has none).

Your job is to bridge this gap. Every prompt must be written so that **a completely fresh agent encountering the task for the first time can fully understand the situation and execute without guessing**. If the sub-agent has to assume or infer anything you already know, you haven't shared enough.

### The Rule: Inline the Essentials, Reference the Rest

Every sub-agent prompt MUST have these 3 sections:

```
## Shared Context (inline)
- WHAT: what is being worked on (1-2 sentences)
- WHY: the motivation, constraint, or decision that led here
- KEY FACTS: core decisions already made, constraints, non-obvious requirements

## Files to Read
- path/to/plan.md — the implementation plan
- path/to/relevant_code.py (lines 50-120) — the function being modified
(sub-agent reads these itself; listing them is guidance, not injection)

## Your Task
{agent-specific instructions — role, angle, deliverable}
```

### Anti-Patterns

| Don't | Why | Do Instead |
|---|---|---|
| Dump entire file contents into the prompt | Token waste, obscures the point | Inline a 3-5 line summary, reference the file path |
| List file paths with no shared context | Sub-agent may not read them, or reads without understanding why | Always include inline essentials |
| Copy-paste identical 2000-char blocks across 3 agents | 6K wasted chars for content they could read from a file | Inline the essentials (~500 chars), reference the file |
| Assume the sub-agent "knows" what you know | It starts from zero every time | State assumptions explicitly |

### When to Write a Shared Context File Instead

If the shared context is going to be long (multi-file code excerpts, long decision logs, detailed specs), write it to a file once and reference it. If it's a short summary that fits naturally in the prompt, just inline it.

```bash
# Long context → write to file once, reference from each agent
cx-read --name debate-pro "Read .workflow/debate-context.md for full context.

Summary: We're deciding whether to use strategy A (extend existing resolver)
or strategy B (new service layer) for DEFAULT_AGENT_ID resolution.

Your role: PRO — defend the plan in debate-context.md. Cite code evidence."
```

Even when using a file, always include a short inline summary so the agent knows what it's about before reading the file.

---

## Multi-Agent Patterns

### Debate / Review (3 agents)

Multiple agents reviewing the same topic from different angles. Each agent needs:
- **Same**: shared context (what's being reviewed, why, key decisions)
- **Different**: role/angle (pro/neutral/con, or free-form perspectives)

Each agent gets the full context inlined directly — do NOT use shell variables (`SHARED=...` / `$SHARED`). Duplicating a few lines of context is fine; indirection makes prompts fragile and harder to read.

Use `run_in_background: true` on each Bash tool call for true parallel execution. Do NOT use shell `&` — it does not work with Claude Code's Bash tool.

```bash
cx-read --name debate-pro "## Shared Context
We're reviewing a plan to add virtual agent resolution to web_api.
Key decision: extend resolve_agent_inner() vs. new fallback layer.
Plan is at .workflow/plan.md, spec at .workflow/spec.md.
Core code: apps/web_api/.../agent_execution_service.py (resolve_agent_inner, line 136-190).

## Files to Read
- .workflow/plan.md
- .workflow/spec.md
- apps/web_api/web_api/apps/rest/services/agent_execution_service.py

## Your Task
You are PRO. Defend this plan. Cite codebase precedent and evidence."

cx-read --name debate-con "## Shared Context
We're reviewing a plan to add virtual agent resolution to web_api.
Key decision: extend resolve_agent_inner() vs. new fallback layer.
Plan is at .workflow/plan.md, spec at .workflow/spec.md.
Core code: apps/web_api/.../agent_execution_service.py (resolve_agent_inner, line 136-190).

## Files to Read
- .workflow/plan.md
- .workflow/spec.md
- apps/web_api/web_api/apps/rest/services/agent_execution_service.py

## Your Task
You are CON. Attack this plan. Find fundamental flaws, missed alternatives, over-engineering."
```

### Delegated Implementation (1 agent)

Single agent doing focused work. Needs richer context since there's no synthesis step.

```bash
cx-write --name impl-task "## Context
We're adding a /agents/default endpoint to web_api. This returns the default
chat virtual agent. Pattern follows chat_agent_view.py precedent.

## Files to Read
- apps/web_api/web_api/apps/rest/views/chat_agent_view.py — existing pattern to follow
- apps/web_api/web_api/shared/types.py — DEFAULT_CHAT_AGENT_ID constant
- apps/web_api/web_api/apps/rest/urls.py — where to register the route

## Your Task
Create the endpoint. Follow the chat_agent_view.py pattern exactly.
Return the agent document with agentType='chat' as JSON.
Add type hints to all functions."
```

### Plan / Spec Generation (1 agent)

```bash
cx-read --name plan-ticket "## Context
Linear ticket AI-1234: Add rate limiting to A2A endpoints.
Current state: no rate limiting exists. All A2A endpoints go through
AgentExecutionService.handle_a2a_stream().

## Files to Read
- apps/web_api/web_api/apps/rest/views/agents_view.py — A2A endpoint definitions
- apps/web_api/web_api/apps/rest/services/agent_execution_service.py — core handler

## Your Task
Generate an implementation plan. Include: approach, affected files,
test strategy, and risks. Write to .workflow/plan.md."
```
