#!/usr/bin/env bash
# One-time machine setup so the SDLC scripts (and an agent driving them) can
# work GitHub end to end: Homebrew + gh installed when missing (macOS), then
# GitHub auth wired for both gh and plain `git push`. Idempotent — safe to
# re-run; interactive only on first login.
set -euo pipefail

if [ "$(uname -s)" = Darwin ]; then
  command -v brew >/dev/null 2>&1 || [ -x /opt/homebrew/bin/brew ] || [ -x /usr/local/bin/brew ] || {
    echo "installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  }
  export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
  command -v gh >/dev/null 2>&1 || brew install gh
else
  command -v gh >/dev/null 2>&1 || { echo "install gh with your package manager first, then re-run" >&2; exit 1; }
fi

# Probe with a real API call — `gh auth status` exits 1 over any stale
# secondary keyring account even when the active one works.
gh api user -q .login >/dev/null 2>&1 || gh auth login --hostname github.com --git-protocol https --web
gh auth setup-git --hostname github.com
echo "setup complete — authenticated as $(gh api user -q .login); gh and git push are wired."
