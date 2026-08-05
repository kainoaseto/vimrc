#!/usr/bin/env bash
# Create <login>/<type>/<slug> off up-to-date origin/main. Types mirror PR
# Title Check; the login prefix is enforced by the sdlc-gate check.
set -euo pipefail

TYPES="feat fix docs style refactor perf test build ci chore revert"

[ $# -ge 2 ] || { echo "usage: new-branch.sh <type> <short description words...>" >&2; echo "types: $TYPES" >&2; exit 2; }

TYPE="$1"; shift
echo "$TYPES" | tr ' ' '\n' | grep -qx "$TYPE" || { echo "invalid type '$TYPE' (want one of: $TYPES)" >&2; exit 2; }

SLUG=$(echo "$*" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//; s/-$//')
[ -n "$SLUG" ] || { echo "empty slug after normalizing '$*'" >&2; exit 2; }

LOGIN=$(gh api user -q .login)
[ -n "$LOGIN" ] || { echo "could not resolve GitHub login (gh auth status?)" >&2; exit 2; }

git fetch origin main
git switch -c "$LOGIN/$TYPE/$SLUG" origin/main
