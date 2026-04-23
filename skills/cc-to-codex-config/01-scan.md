# Step 01: Scan — List All Syncable Items

## Purpose

Scan all skills, hooks, and CLAUDE.md sections to build a complete inventory.

## Procedure

### 1. Scan Skills

List all skill directories in scope:
```bash
# Global
ls -1 ~/.claude/skills/

# Project (if scope == project)
ls -1 .claude/skills/ 2>/dev/null
```

For each skill, extract the name and description from `SKILL.md` frontmatter.

### 2. Scan Hooks

List all hook files:
```bash
# Global
find ~/.claude/hooks -type f ! -name '.DS_Store' ! -path '*__pycache__*' | sort

# Also extract hook commands from settings.json
python3 -c "
import json
with open('$HOME/.claude/settings.json') as f:
    hooks = json.load(f).get('hooks', {})
for event, groups in hooks.items():
    for g in groups:
        for h in g.get('hooks', []):
            print(f'{event}: {h.get(\"command\", \"\")}')
"
```

### 3. Scan CLAUDE.md Sections

Extract all top-level headings:
```bash
# Global
grep -n '^#' ~/.claude/CLAUDE.md 2>/dev/null

# Project (if scope == project)
grep -n '^#' CLAUDE.md 2>/dev/null
```

Also detect inline references like `@RTK.md`, `@*.md`.

### 4. Present Inventory

Display the full list grouped by category:

```
📋 Sync 가능 항목 목록

[Skills] (global)
  1. wf — End-to-end automated dev workflow
  2. code-writing — 코드 작성 규칙
  3. ddd — 복잡한 기술 개념 단계별 설명
  ...

[Hooks] (global)
  1. rtk-rewrite.sh
  2. pre_git_push.py
  3. post_tool_use.py
  ...

[CLAUDE.md sections] (global)
  1. ## Sub-Agent Policy
  2. ## Core Principles
  3. @RTK.md
  ...

[Project] (if applicable)
  ...
```

## Checklist

- [ ] Scan global skills
- [ ] Scan global hooks (files + settings.json commands)
- [ ] Scan CLAUDE.md sections and references
- [ ] Scan project items (if scope == project)
- [ ] Present complete inventory to user
