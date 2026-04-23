# Step 00: Init — Scope Selection

## Purpose

Determine what to sync: global config only, or global + current project.

## Procedure

1. Detect if the user is inside a git repository with a `.claude/` directory:
   ```bash
   git rev-parse --show-toplevel 2>/dev/null
   ls -d .claude 2>/dev/null
   ```

2. Present the options:

   **If project `.claude/` exists:**
   ```
   Sync 범위를 선택해주세요:

   1. Global only — ~/.claude → ~/.codex
   2. Global + Project — ~/.claude + ./.claude → ~/.codex + ./.codex

   현재 프로젝트: <detected project root>
   ```

   **If no project `.claude/`:**
   ```
   프로젝트 .claude/ 디렉토리가 없어서 글로벌만 sync합니다.
   → ~/.claude → ~/.codex
   ```
   (Auto-select global only)

3. Save the selection for use in subsequent steps:
   - `scope`: "global" or "project"
   - `project_root`: path (if project scope)

## Checklist

- [ ] Detect project context
- [ ] Present scope options
- [ ] User selects scope
- [ ] Record scope selection
