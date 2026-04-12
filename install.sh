#!/usr/bin/env bash
set -euo pipefail

# Resolve the directory where this script lives (the repo root)
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Preflight checks ---
command -v jq >/dev/null 2>&1 || { echo "error: jq is required but not found"; exit 1; }
command -v git >/dev/null 2>&1 || { echo "error: git is required but not found"; exit 1; }

echo "Installing from: $INSTALL_DIR"

# --- Third-party dependencies ---
# bits (https://github.com/abatilo/bits) — task tracking plugin for Claude Code
BITS_DIR="${BITS_DIR:-$INSTALL_DIR/../bits}"
if [ ! -d "$BITS_DIR" ]; then
  echo "Cloning third-party dependency: abatilo/bits -> $BITS_DIR"
  git clone https://github.com/abatilo/bits.git "$BITS_DIR"
fi
BITS_DIR="$(cd "$BITS_DIR" && pwd)" # resolve to absolute path
echo "bits plugin: $BITS_DIR"

# --- Clean up previous install ---
rm -rf \
  ~/.claude/commands \
  ~/.claude/agents \
  ~/.claude/skills \
  ~/.claude/rules \
  ~/.claude/CLAUDE.md \
  ~/.claude/settings.json
rm -f \
  ~/.codex/AGENTS.md \
  ~/.codex/config.toml

# --- Claude Code ---
mkdir -p ~/.claude

# Generate settings.json from template
sed -e "s|__INSTALL_DIR__|${INSTALL_DIR}|g" \
    -e "s|__BITS_DIR__|${BITS_DIR}|g" \
    "$INSTALL_DIR/claude_settings.json" > ~/.claude/settings.json

# Merge local overrides if they exist
if [ -f "$INSTALL_DIR/claude_settings.local.json" ]; then
  echo "Merging local overrides from claude_settings.local.json"
  tmp=$(mktemp)
  jq -s '.[0] * .[1]' ~/.claude/settings.json "$INSTALL_DIR/claude_settings.local.json" > "$tmp" \
    && mv "$tmp" ~/.claude/settings.json
elif [ -f "$INSTALL_DIR/claude_settings.local.json.example" ]; then
  echo "No claude_settings.local.json found."
  echo "  Copy the example to get started:"
  echo "  cp claude_settings.local.json.example claude_settings.local.json"
fi

# Symlink rules (not supported in plugins, must be a direct symlink)
ln -s "$INSTALL_DIR/rules" ~/.claude/rules

# Symlink global instructions
ln -s "$INSTALL_DIR/CLAUDE_global.md" ~/.claude/CLAUDE.md

# Set global MCP servers in ~/.claude.json
[ -f ~/.claude.json ] || echo '{}' > ~/.claude.json
tmp=$(mktemp)
jq '.mcpServers = {
  "codex": {
    "type": "stdio",
    "command": "codex",
    "args": ["mcp-server"],
    "env": {}
  },
  "jira": {
    "type": "http",
    "url": "https://mcp.atlassian.com/v1/mcp"
  }
}' ~/.claude.json > "$tmp" && mv "$tmp" ~/.claude.json

# --- Codex CLI ---
mkdir -p ~/.codex

# Generate codex config from template
sed "s|__INSTALL_DIR__|${INSTALL_DIR}|g" "$INSTALL_DIR/codex_config.toml" > ~/.codex/config.toml

# Symlink codex agent instructions
ln -s "$INSTALL_DIR/AGENTS_global.md" ~/.codex/AGENTS.md

echo ""
echo "Done. Claude Code and Codex CLI configured."
echo ""
echo "Third-party dependencies:"
echo "  bits (abatilo/bits): $BITS_DIR"
echo ""
echo "To customize personal settings (extra directories, hooks, etc.):"
echo "  cp claude_settings.local.json.example claude_settings.local.json"
echo "  # edit claude_settings.local.json, then re-run ./install.sh"
