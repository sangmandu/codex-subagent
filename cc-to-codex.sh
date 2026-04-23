#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────
# cc-to-codex.sh — Config-driven one-way sync: .claude → .codex
#
# Reads .cc-to-codex.yaml config and syncs skills, hooks,
# and CLAUDE.md → AGENTS.md with user-defined exclusions.
#
# Usage: bash cc-to-codex.sh [--dry-run] [--config <path>]
# ─────────────────────────────────────────────────────────

CONFIG_PATH=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --config) CONFIG_PATH="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$CONFIG_PATH" ]]; then
  for candidate in ".cc-to-codex.yaml" "$HOME/.cc-to-codex.yaml"; do
    if [[ -f "$candidate" ]]; then
      CONFIG_PATH="$candidate"
      break
    fi
  done
fi

if [[ -z "$CONFIG_PATH" || ! -f "$CONFIG_PATH" ]]; then
  echo "Error: No config file found. Run the cc-to-codex-config skill to generate one."
  echo "  Searched: .cc-to-codex.yaml, ~/.cc-to-codex.yaml"
  exit 1
fi

echo "Using config: $CONFIG_PATH"
$DRY_RUN && echo "[DRY RUN] No files will be modified."

CHANGED=0
SKIPPED=0

log() { echo "  $1"; }

# ── Parse config via Python ──────────────────────────────

CONFIG_JSON=$(python3 -c "
import yaml, json, sys
with open('$CONFIG_PATH') as f:
    config = yaml.safe_load(f)
json.dump(config, sys.stdout)
")

get_config() {
  echo "$CONFIG_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
keys = '$1'.split('.')
for k in keys:
    if isinstance(data, dict):
        data = data.get(k, '$2')
    else:
        data = '$2'
        break
if isinstance(data, list):
    print('\n'.join(str(x) for x in data))
elif isinstance(data, bool):
    print('true' if data else 'false')
else:
    print(data)
"
}

is_excluded() {
  local item="$1"
  local list_key="$2"
  echo "$CONFIG_JSON" | python3 -c "
import json, sys, fnmatch
data = json.load(sys.stdin)
keys = '$list_key'.split('.')
for k in keys:
    data = data.get(k, []) if isinstance(data, dict) else []
patterns = data if isinstance(data, list) else []
item = '$item'
for p in patterns:
    if fnmatch.fnmatch(item, p):
        sys.exit(0)
sys.exit(1)
" 2>/dev/null
}

SRC_GLOBAL="$HOME/.claude"
DST_GLOBAL="$HOME/.codex"
SCOPE=$(get_config "scope" "global")

# ── Path rewrite helper ──────────────────────────────────

transform_content() {
  sed \
    -e 's|~/.claude|~/.codex|g' \
    -e 's|/\.claude/|/.codex/|g' \
    -e 's|CLAUDE.md|AGENTS.md|g' \
    -e 's|Claude Code|Codex|g'
}

do_copy() {
  if $DRY_RUN; then
    log "[would copy] $1 → $2"
  else
    mkdir -p "$(dirname "$2")"
    cp "$1" "$2"
  fi
  ((CHANGED++))
}

# ── 1. Skills ────────────────────────────────────────────

sync_skills() {
  local src_dir="$1"
  local dst_dir="$2"
  local scope_label="$3"

  echo "=== Syncing skills ($scope_label) ==="

  # Delete codex skills that no longer exist in source (except .system/)
  if [[ -d "$dst_dir" ]]; then
    while IFS= read -r codex_file; do
      rel="${codex_file#$dst_dir/}"
      [[ "$rel" == .system/* ]] && continue
      if [[ ! -f "$src_dir/$rel" ]]; then
        log "[delete] $rel"
        if ! $DRY_RUN; then rm "$codex_file"; fi
        ((CHANGED++))
      fi
    done < <(find "$dst_dir" -type f ! -name '.DS_Store' 2>/dev/null)
  fi

  [[ ! -d "$src_dir" ]] && return

  while IFS= read -r src_file; do
    rel="${src_file#$src_dir/}"
    [[ "$rel" == ".DS_Store" ]] && continue
    [[ "$rel" == *.zip ]] && continue

    # Check exclusion
    local skill_dir="${rel%%/*}"
    if is_excluded "$skill_dir" "exclude.skills"; then
      ((SKIPPED++))
      continue
    fi

    dst_file="$dst_dir/$rel"

    if [[ "$(basename "$rel")" == "SKILL.md" ]]; then
      transformed=$(python3 -c "
import sys, re
try:
    import yaml
except ImportError:
    sys.exit(99)

text = open('$src_file').read()
if not text.startswith('---'):
    print(text, end='')
    sys.exit(0)

m = re.match(r'^---\n(.*?\n)---\n?(.*)', text, re.DOTALL)
if not m:
    print(text, end='')
    sys.exit(0)

front_raw = m.group(1)
body = m.group(2)

data = yaml.safe_load(front_raw)
if not isinstance(data, dict):
    print(text, end='')
    sys.exit(0)

if 'description' not in data and 'trigger' in data:
    trigger = data['trigger']
    if isinstance(trigger, str):
        data['description'] = trigger.strip('\"')

front_out = yaml.dump(data, default_flow_style=False, allow_unicode=True, sort_keys=False)
print('---')
print(front_out.rstrip())
print('---')
print(body, end='')
")
      transformed=$(printf '%s\n' "$transformed" | transform_content)
      if [[ -f "$dst_file" ]] && [[ "$transformed" == "$(cat "$dst_file")" ]]; then
        ((SKIPPED++))
        continue
      fi
      log "[skill] $rel"
      if ! $DRY_RUN; then
        mkdir -p "$(dirname "$dst_file")"
        echo "$transformed" > "$dst_file"
      fi
      ((CHANGED++))
    else
      content=$(transform_content < "$src_file")
      if [[ -f "$dst_file" ]] && [[ "$content" == "$(cat "$dst_file")" ]]; then
        ((SKIPPED++))
        continue
      fi
      log "[copy] $rel"
      if $DRY_RUN; then
        log "[would copy] $src_file → $dst_file"
      else
        mkdir -p "$(dirname "$dst_file")"
        printf '%s\n' "$content" > "$dst_file"
        [[ -x "$src_file" ]] && chmod +x "$dst_file"
      fi
      ((CHANGED++))
    fi
  done < <(find "$src_dir" -type f ! -name '.DS_Store' ! -name '*.zip' 2>/dev/null | sort)
}

# ── 2. Hooks ─────────────────────────────────────────────

sync_hooks() {
  local src_dir="$1/hooks"
  local dst_dir="$2/hooks"
  local scope_label="$3"

  echo "=== Syncing hooks ($scope_label) ==="

  [[ ! -d "$src_dir" ]] && return

  while IFS= read -r src_file; do
    rel="${src_file#$src_dir/}"
    [[ "$rel" == ".DS_Store" ]] && continue
    [[ "$rel" == *__pycache__* ]] && continue

    if is_excluded "$rel" "exclude.hooks"; then
      ((SKIPPED++))
      continue
    fi

    dst_file="$dst_dir/$rel"

    if [[ "$rel" == *.py ]]; then
      content=$(sed \
        -e 's|"\.claude"|".codex"|g' \
        -e "s|'\.claude'|'.codex'|g" \
        -e 's|/\.claude/|/.codex/|g' \
        -e 's|claude_hook|codex_hook|g' \
        -e 's|CLAUDE.md|AGENTS.md|g' \
        -e 's|GLOBAL_CLAUDE_MD|GLOBAL_AGENTS_MD|g' \
        -e 's|load_merged_claude_md|load_merged_agents_md|g' \
        "$src_file")
      if [[ -f "$dst_file" ]] && [[ "$content" == "$(cat "$dst_file")" ]]; then
        ((SKIPPED++))
        continue
      fi
      log "[hook] $rel"
      if ! $DRY_RUN; then
        mkdir -p "$(dirname "$dst_file")"
        echo "$content" > "$dst_file"
      fi
      ((CHANGED++))
    else
      if [[ -f "$dst_file" ]] && diff -q "$src_file" "$dst_file" >/dev/null 2>&1; then
        ((SKIPPED++))
        continue
      fi
      log "[copy] $rel"
      do_copy "$src_file" "$dst_file"
    fi
  done < <(find "$src_dir" -type f ! -name '.DS_Store' ! -path '*__pycache__*' 2>/dev/null | sort)
}

# ── 3. hooks.json (codex hook config) ────────────────────

sync_hooks_json() {
  local src_settings="$1/settings.json"
  local dst_hooks_json="$2/hooks.json"
  local scope_label="$3"

  echo "=== Syncing hooks.json ($scope_label) ==="

  [[ ! -f "$src_settings" ]] && return

  local excluded_hooks_json
  excluded_hooks_json=$(echo "$CONFIG_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
excluded = data.get('exclude', {}).get('hooks', [])
json.dump(excluded, sys.stdout)
")

  new_hooks_json=$(python3 -c "
import json

with open('$src_settings') as f:
    settings = json.load(f)

hooks = settings.get('hooks', {})
if not hooks:
    print('{}')
    raise SystemExit(0)

excluded = json.loads('$excluded_hooks_json')

def rewrite(obj):
    if isinstance(obj, str):
        return obj.replace('/.claude/', '/.codex/')
    if isinstance(obj, list):
        return [rewrite(x) for x in obj]
    if isinstance(obj, dict):
        return {k: rewrite(v) for k, v in obj.items()}
    return obj

converted = rewrite(hooks)

import fnmatch
def is_excluded_hook(hook):
    if not isinstance(hook, dict):
        return False
    command = hook.get('command', '')
    if not isinstance(command, str):
        return False
    for pattern in excluded:
        if fnmatch.fnmatch(command, '*' + pattern + '*'):
            return True
    return False

for event_name, groups in list(converted.items()):
    if not isinstance(groups, list):
        continue
    filtered_groups = []
    for group in groups:
        if not isinstance(group, dict):
            filtered_groups.append(group)
            continue
        hook_entries = group.get('hooks')
        if not isinstance(hook_entries, list):
            filtered_groups.append(group)
            continue
        kept = [h for h in hook_entries if not is_excluded_hook(h)]
        if not kept:
            continue
        group = dict(group)
        group['hooks'] = kept
        filtered_groups.append(group)
    converted[event_name] = filtered_groups

print(json.dumps({'hooks': converted}, indent=2, ensure_ascii=False))
")

  if [[ -f "$dst_hooks_json" ]] && [[ "$new_hooks_json" == "$(cat "$dst_hooks_json")" ]]; then
    log "[skip] hooks.json (unchanged)"
    ((SKIPPED++))
  else
    log "[update] hooks.json"
    if ! $DRY_RUN; then echo "$new_hooks_json" > "$dst_hooks_json"; fi
    ((CHANGED++))
  fi
}

# ── 4. CLAUDE.md → AGENTS.md ────────────────────────────

sync_claude_md() {
  local src_md="$1"
  local dst_md="$2"
  local scope_label="$3"

  echo "=== Syncing CLAUDE.md → AGENTS.md ($scope_label) ==="

  [[ ! -f "$src_md" ]] && return

  local excluded_sections_json
  excluded_sections_json=$(echo "$CONFIG_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
sections = data.get('exclude', {}).get('claude_md_sections', [])
json.dump(sections, sys.stdout)
")

  agents_content=$(python3 -c "
import sys, re, json

with open('$src_md') as f:
    text = f.read()

# Path rewrites
text = text.replace('/.claude/', '/.codex/')
text = text.replace('~/.claude/', '~/.codex/')

# Remove CLAUDE_ONLY blocks
text = re.sub(r'<!-- CLAUDE_ONLY_START -->.*?<!-- CLAUDE_ONLY_END -->\n?', '', text, flags=re.DOTALL)

# Remove excluded sections by heading
excluded = json.loads('$excluded_sections_json')
for section in excluded:
    # Remove ## Section heading and everything until next ## or EOF
    pattern = r'^(#{1,6})\s+' + re.escape(section) + r'\s*\n.*?(?=^#{1,6}\s|\Z)'
    text = re.sub(pattern, '', text, flags=re.MULTILINE | re.DOTALL)

# Remove excluded line patterns (e.g. @RTK.md)
excluded_lines = json.loads('$excluded_sections_json')
for line_pat in excluded_lines:
    text = re.sub(r'^' + re.escape(line_pat) + r'\n?', '', text, flags=re.MULTILINE)

print(text, end='')
")

  if [[ -f "$dst_md" ]] && [[ "$agents_content" == "$(cat "$dst_md")" ]]; then
    log "[skip] AGENTS.md (unchanged)"
    ((SKIPPED++))
  else
    log "[update] AGENTS.md"
    if ! $DRY_RUN; then echo "$agents_content" > "$dst_md"; fi
    ((CHANGED++))
  fi
}

# ── Execute sync ─────────────────────────────────────────

# Global sync
sync_skills "$SRC_GLOBAL/skills" "$DST_GLOBAL/skills" "global"
sync_hooks "$SRC_GLOBAL" "$DST_GLOBAL" "global"
sync_hooks_json "$SRC_GLOBAL" "$DST_GLOBAL" "global"
sync_claude_md "$SRC_GLOBAL/CLAUDE.md" "$DST_GLOBAL/AGENTS.md" "global"

# Project sync (if scope includes project)
if [[ "$SCOPE" == "project" ]]; then
  PROJECT_SRC=$(get_config "project.claude_dir" "")
  PROJECT_DST=$(get_config "project.codex_dir" "")

  if [[ -n "$PROJECT_SRC" && -n "$PROJECT_DST" ]]; then
    sync_skills "$PROJECT_SRC/skills" "$PROJECT_DST/skills" "project"
    sync_hooks "$PROJECT_SRC" "$PROJECT_DST" "project"

    # Project CLAUDE.md → AGENTS.md
    PROJECT_ROOT=$(dirname "$PROJECT_SRC")
    if [[ -f "$PROJECT_ROOT/CLAUDE.md" ]]; then
      sync_claude_md "$PROJECT_ROOT/CLAUDE.md" "$PROJECT_ROOT/AGENTS.md" "project"
    fi
  fi
fi

# ── Summary ──────────────────────────────────────────────

echo ""
echo "=== Done ==="
echo "  Changed: $CHANGED"
echo "  Skipped (unchanged): $SKIPPED"
