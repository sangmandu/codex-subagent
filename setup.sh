#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

info()  { printf "${GREEN}✓${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}!${NC} %s\n" "$1"; }
error() { printf "${RED}✗${NC} %s\n" "$1"; }

echo ""
echo -e "${BOLD}cx-read/cx-write Sub-Agent Setup${NC}"
echo "================================="
echo ""

# 1. Check prerequisites
MISSING=()
command -v codex >/dev/null 2>&1 || MISSING+=("codex (npm install -g @openai/codex)")
command -v jq >/dev/null 2>&1    || MISSING+=("jq (brew install jq)")

if [ ${#MISSING[@]} -gt 0 ]; then
  error "Missing prerequisites:"
  for m in "${MISSING[@]}"; do
    echo "  - $m"
  done
  exit 1
fi
info "Prerequisites OK (codex, jq)"

# 2. Install cx-read / cx-write
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

PLUGIN_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_SRC="$PLUGIN_DIR/bin"

if [ ! -d "$SCRIPT_SRC" ]; then
  error "bin/ directory not found at $SCRIPT_SRC"
  exit 1
fi

cp "$SCRIPT_SRC/cx-read" "$BIN_DIR/cx-read"
cp "$SCRIPT_SRC/cx-write" "$BIN_DIR/cx-write"
chmod +x "$BIN_DIR/cx-read" "$BIN_DIR/cx-write"
info "Installed cx-read, cx-write to $BIN_DIR"

if ! echo "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
  warn "$BIN_DIR is not in PATH. Add to your shell profile:"
  echo "  export PATH=\"$BIN_DIR:\$PATH\""
fi

# 3. Configure Agent deny
echo ""
echo "Where should the Agent tool be denied?"
echo "  1) Global  (~/.claude/settings.json) — blocks Agent in all projects"
echo "  2) Project (.claude/settings.json)    — blocks Agent in current repo only"
echo ""
read -rp "Choose [1/2]: " CHOICE

case "$CHOICE" in
  1) SETTINGS_FILE="$HOME/.claude/settings.json" ;;
  2) SETTINGS_FILE=".claude/settings.json" ;;
  *)
    error "Invalid choice: $CHOICE"
    exit 1
    ;;
esac

mkdir -p "$(dirname "$SETTINGS_FILE")"

if [ ! -f "$SETTINGS_FILE" ]; then
  echo '{}' > "$SETTINGS_FILE"
fi

if jq -e '.permissions.deny // [] | map(select(. == "Agent")) | length > 0' "$SETTINGS_FILE" >/dev/null 2>&1; then
  info "Agent already denied in $SETTINGS_FILE"
else
  TEMP=$(mktemp)
  jq '.permissions.deny = ((.permissions.deny // []) + ["Agent"]) | .permissions.deny |= unique' "$SETTINGS_FILE" > "$TEMP"
  mv "$TEMP" "$SETTINGS_FILE"
  info "Added Agent to deny list in $SETTINGS_FILE"
fi

echo ""
echo -e "${BOLD}Done!${NC} You can now use cx-read / cx-write as sub-agents."
echo "  cx-read \"your prompt here\""
echo "  cx-write \"your prompt here\""
