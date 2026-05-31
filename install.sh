#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="$HOME"
DRY_RUN=false

usage() {
  cat <<'EOF'
Usage: bash install.sh [OPTIONS]

Options:
  --dry-run          Print the install plan without writing files
  --home-dir PATH    Use PATH as the target home directory
  --help, -h         Show this help message

EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --home-dir) HOME_DIR="${2:?missing path for --home-dir}"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

SCRIPT_SRC="$ROOT/context-bar.sh"
CLAUDE_DIR="$HOME_DIR/.claude"
HUD_DIR="$CLAUDE_DIR/hud"
SCRIPT_DEST="$HUD_DIR/context-bar.sh"
SETTINGS="$CLAUDE_DIR/settings.json"
if [[ "$HOME_DIR" == "$HOME" ]]; then
  COMMAND='bash "$HOME/.claude/hud/context-bar.sh"'
else
  COMMAND="bash \"$SCRIPT_DEST\""
fi

[[ -f "$SCRIPT_SRC" ]] || { printf 'Missing %s\n' "$SCRIPT_SRC" >&2; exit 1; }

if [[ "$DRY_RUN" == "true" ]]; then
  printf 'DRY RUN: Claude Code HUD installer\n'
  printf '  HUD script: %s -> %s\n' "$SCRIPT_SRC" "$SCRIPT_DEST"
  printf '  Settings:   %s\n' "$SETTINGS"
  printf '  Command:    %s\n' "$COMMAND"
  exit 0
fi

command -v jq >/dev/null 2>&1 || {
  printf 'jq is required to update %s safely.\n' "$SETTINGS" >&2
  exit 1
}

mkdir -p "$HUD_DIR"
install -m 755 "$SCRIPT_SRC" "$SCRIPT_DEST"

if [[ -f "$SETTINGS" ]]; then
  cp "$SETTINGS" "$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
else
  mkdir -p "$(dirname "$SETTINGS")"
  printf '{}\n' > "$SETTINGS"
fi

tmp_settings="$(mktemp "${TMPDIR:-/tmp}/claude-hud-settings.XXXXXX")"
jq --arg cmd "$COMMAND" '.statusLine = {"type":"command", "command": $cmd}' "$SETTINGS" > "$tmp_settings"
mv "$tmp_settings" "$SETTINGS"

printf 'Claude Code HUD installed.\n'
printf '  %s\n' "$SCRIPT_DEST"
printf 'Restart Claude Code or open a new session to see the statusline.\n'
