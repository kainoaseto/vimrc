#!/usr/bin/env bash
# Repair an OPEN PR whose head branch can't satisfy the sdlc-gate pattern
# (<author>/<type>/<slug>) — typically a GitHub-web `<login>-patch-1`
# branch, where the web UI won't honor a chosen branch name.
#
# GitHub CLOSES an open PR when its head branch is renamed (verified live), so never rename in place. Instead: recreate the branch under a
# conforming name at the same commit, open a fresh PR carrying the title/body
# (and with it the issue linkage), close the old PR as superseded, and delete
# the old branch so a stale push fails loudly instead of landing beside a
# dead PR.
#
# Last line of output is machine-readable: NEW_PR=<n> — the same number when
# nothing needed fixing, the successor PR's number when it did.
set -euo pipefail

[ $# -eq 1 ] || { echo "usage: fix-branch.sh <pr-number>" >&2; exit 2; }
PR="$1"
TYPES='feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert'

DATA=$(gh pr view "$PR" --json headRefName,headRefOid,baseRefName,author,title,body,state,isDraft)
HEAD_REF=$(printf '%s' "$DATA" | jq -r .headRefName)
AUTHOR=$(printf '%s' "$DATA" | jq -r .author.login)
TITLE=$(printf '%s' "$DATA" | jq -r .title)
STATE=$(printf '%s' "$DATA" | jq -r .state)
BASE=$(printf '%s' "$DATA" | jq -r .baseRefName)
SHA=$(printf '%s' "$DATA" | jq -r .headRefOid)
DRAFT=$(printf '%s' "$DATA" | jq -r .isDraft)

[ "$STATE" = "OPEN" ] || { echo "PR #$PR is $STATE — nothing to fix" >&2; exit 1; }
case "$HEAD_REF" in
  release-please--*) echo "release-please branch — exempt from the gate"; echo "NEW_PR=$PR"; exit 0 ;;
esac
case "$AUTHOR" in
  *"[bot]"|app/*) echo "bot author — exempt from the gate"; echo "NEW_PR=$PR"; exit 0 ;;
esac
if printf '%s' "$HEAD_REF" | grep -Eq "^$AUTHOR/($TYPES)/[a-z0-9._-]+$"; then
  echo "branch '$HEAD_REF' already conforms — nothing to do"
  echo "NEW_PR=$PR"
  exit 0
fi

TYPE=$(printf '%s' "$TITLE" | sed -E 's/^([a-z]+)(\([^)]*\))?!?:.*/\1/')
printf '%s' "$TYPE" | grep -Eqx "($TYPES)" || TYPE=chore
SLUG=$(basename "$HEAD_REF" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._-' '-' | sed 's/^-*//; s/-*$//')
case "$SLUG" in
  ''|*patch-[0-9]*|"$AUTHOR"*)  # GitHub-web default names carry no signal — slug from the title instead
    SLUG=$(printf '%s' "${TITLE#*:}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-*$//' | cut -c1-40 | sed 's/-*$//') ;;
esac
NEW="$AUTHOR/$TYPE/$SLUG"

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
gh api -X POST "repos/$REPO/git/refs" -f ref="refs/heads/$NEW" -f sha="$SHA" >/dev/null
echo "created branch '$NEW' at $SHA"

BODY=$(printf '%s' "$DATA" | jq -r '.body // ""')
BODY="$BODY

Supersedes #$PR — its head branch \`$HEAD_REF\` cannot satisfy the sdlc-gate name pattern, so the same commit continues here on \`$NEW\`."
ARGS=(--base "$BASE" --head "$NEW" --title "$TITLE" --body "$BODY")
[ "$DRAFT" = "true" ] && ARGS+=(--draft)
NEW_URL=$(gh pr create "${ARGS[@]}")
NEW_NUM=${NEW_URL##*/}

gh pr comment "$PR" --body "Superseded by #$NEW_NUM — head branch \`$HEAD_REF\` recreated as \`$NEW\` to satisfy the sdlc-gate; this PR is closed, the old branch deleted." >/dev/null
gh pr close "$PR" >/dev/null
ENC=$(printf '%s' "$HEAD_REF" | jq -sRr @uri)
gh api -X DELETE "repos/$REPO/git/refs/heads/$ENC" >/dev/null \
  || echo "note: could not delete old branch '$HEAD_REF' — remove it by hand" >&2

if ! printf '%s' "$BODY" | grep -Eiq '(close[sd]?|fix(e[sd])?|resolve[sd]?) #[0-9]+'; then
  echo "note: the PR body names no closing issue — the gate's linked-issue rule will still fail; add one with: gh pr edit $NEW_NUM --body '... Closes #<issue>'" >&2
fi

echo "PR #$PR (branch '$HEAD_REF') superseded by PR #$NEW_NUM on '$NEW' at $SHA"
echo "NEW_PR=$NEW_NUM"
