#!/usr/bin/env bash
# Push the current branch and open a PR with a semantic title.
set -euo pipefail

[ $# -ge 1 ] || { echo 'usage: open-pr.sh "<type>: <title>" [issue-number] [body-file] [--draft]' >&2; exit 2; }

TITLE="$1"
ISSUE="${2:-}"
BODY_FILE="${3:-}"
DRAFT="${4:-}"

BRANCH=$(git branch --show-current)
[ "$BRANCH" != "main" ] || { echo "refusing to open a PR from main — create a branch first (new-branch.sh)" >&2; exit 2; }

# sdlc-gate requires <author-login>/<type>/<slug>. Fix a non-conforming
# branch here, while no PR exists yet, instead of failing the gate after.
TYPES='feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert'
LOGIN=$(gh api user -q .login)
[ -n "$LOGIN" ] || { echo "could not resolve GitHub login (gh auth status? run 'make setup')" >&2; exit 2; }
if ! printf '%s' "$BRANCH" | grep -Eq "^$LOGIN/($TYPES)/[a-z0-9._-]+$"; then
  TYPE=$(printf '%s' "$TITLE" | sed -E 's/^([a-z]+)(\([^)]*\))?!?:.*/\1/')
  printf '%s' "$TYPE" | grep -Eqx "($TYPES)" || TYPE=chore
  SLUG=$(printf '%s' "${BRANCH##*/}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._-' '-' | sed 's/^-*//; s/-*$//')
  case "$SLUG" in
    ''|*patch-[0-9]*|"$LOGIN"*)  # GitHub-web default names carry no signal — slug from the title instead
      SLUG=$(printf '%s' "${TITLE#*:}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-*$//' | cut -c1-40) ;;
  esac
  NEW="$LOGIN/$TYPE/$SLUG"
  echo "branch '$BRANCH' does not match the sdlc-gate pattern — renaming to '$NEW'"
  git branch -m "$NEW"
  if git ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
    git push origin --delete "$BRANCH" || echo "note: stale remote branch '$BRANCH' left behind — delete it by hand" >&2
  fi
  BRANCH="$NEW"
fi

# Every PR closes an issue (enforced by sdlc-gate). When none is passed,
# file a one-line issue so even trivial changes leave an issue trail.
if [ -z "$ISSUE" ]; then
  ISSUE=$(gh issue create --title "$TITLE" \
    --body "Auto-filed by /ship for SDLC linkage — every PR closes an issue. See the linked PR for the change itself." \
    | grep -oE '[0-9]+$')
  [ -n "$ISSUE" ] || { echo "failed to auto-file the linkage issue" >&2; exit 1; }
  echo "auto-filed issue #$ISSUE for SDLC linkage"
fi

BODY="Closes #$ISSUE"
if [ -n "$BODY_FILE" ]; then
  [ -f "$BODY_FILE" ] || { echo "body file not found: $BODY_FILE" >&2; exit 2; }
  BODY="${BODY:+$BODY

}$(cat "$BODY_FILE")"
fi

git push -u origin "$BRANCH"
if [ "$DRAFT" = "--draft" ]; then
  gh pr create --base main --title "$TITLE" --body "$BODY" --draft
else
  gh pr create --base main --title "$TITLE" --body "$BODY"
fi
