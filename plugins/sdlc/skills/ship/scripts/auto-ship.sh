#!/usr/bin/env bash
# Gated agent merge: squash-merge a PR only when every SDLC check is green.
#
# GitHub-level required-check blocking needs a paid plan on private repos
# (evidence in the adopting repo's SDLC docs), so on the agent path THIS script is the enforcement.
# Humans can still merge from the UI; agents merge through here.
#
# Flag: the AUTO_SHIP repo variable pauses all agent merges instantly:
#   gh variable set AUTO_SHIP --body off
set -euo pipefail

[ $# -eq 1 ] || { echo "usage: auto-ship.sh <pr-number>" >&2; exit 2; }
PR="$1"

FLAG=$(gh variable get AUTO_SHIP 2>/dev/null || echo off)
[ "$FLAG" = "on" ] || {
  echo "AUTO_SHIP is '$FLAG' — agent merges are paused. A maintainer can resume with: gh variable set AUTO_SHIP --body on" >&2
  exit 1
}

HEAD_REF=$(gh pr view "$PR" --json headRefName -q .headRefName)
case "$HEAD_REF" in
  release-please--*)
    echo "refusing: release PRs are the deploy decision — a human merges those (deploy skill)" >&2
    exit 1 ;;
esac

# Self-heal a non-conforming head branch — otherwise the SDLC gate can never
# go green below. fix-branch.sh supersedes the PR (GitHub closes a PR whose
# head branch is renamed, so it recreates the branch + opens a successor);
# follow the successor's number for the rest of the run.
AUTHOR=$(gh pr view "$PR" --json author -q .author.login)
TYPES='feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert'
case "$AUTHOR" in
  *"[bot]"|app/*) ;;
  *)
    if ! printf '%s' "$HEAD_REF" | grep -Eq "^$AUTHOR/($TYPES)/[a-z0-9._-]+$"; then
      echo "head branch '$HEAD_REF' fails the sdlc-gate pattern — fixing it first"
      FIX_OUT=$("$(cd "$(dirname "$0")" && pwd)/fix-branch.sh" "$PR")
      printf '%s\n' "$FIX_OUT"
      NEW_PR=$(printf '%s\n' "$FIX_OUT" | sed -n 's/^NEW_PR=//p' | tail -1)
      if [ -n "$NEW_PR" ] && [ "$NEW_PR" != "$PR" ]; then
        echo "continuing as PR #$NEW_PR (superseded #$PR); the spec-validation walk must name #$NEW_PR"
        PR="$NEW_PR"
      fi
      HEAD_REF=$(gh pr view "$PR" --json headRefName -q .headRefName)
    fi ;;
esac

SHA=$(gh pr view "$PR" --json headRefOid -q .headRefOid)
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
# Override per repo with SDLC_REQUIRED_CHECKS='name1|name2|...' when check names differ.
IFS='|' read -r -a REQUIRED <<< "${SDLC_REQUIRED_CHECKS:-verify|Validate PR title|SDLC gate}"

# Wait for the required checks on the head SHA; fail loudly on any red.
for _ in $(seq 1 40); do
  RUNS=$(gh api "repos/{owner}/{repo}/commits/$SHA/check-runs" -q '[.check_runs[] | {name, conclusion, status}]')
  PENDING=0
  for c in "${REQUIRED[@]}"; do
    CONC=$(printf '%s' "$RUNS" | jq -r --arg n "$c" '[.[] | select(.name==$n)] | .[0] | if . == null then "missing" elif .status != "completed" then "pending" else .conclusion end')
    case "$CONC" in
      success) ;;
      pending|missing) PENDING=1 ;;
      *) echo "refusing: check '$c' concluded '$CONC' on $SHA — fix it; auto-ship merges green PRs only" >&2; exit 1 ;;
    esac
  done
  if [ "$PENDING" -eq 0 ]; then
    # "Done is measurable" is enforced here, not just described: the linked
    # issue must carry the spec-validation walk for THIS PR before the merge.
    ISSUE=$(gh api graphql \
      -f query='query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){pullRequest(number:$n){closingIssuesReferences(first:1){nodes{number}}}}}' \
      -f o="${REPO%/*}" -f r="${REPO#*/}" -F n="$PR" \
      -q '.data.repository.pullRequest.closingIssuesReferences.nodes[0].number // empty')
    [ -n "$ISSUE" ] || { echo "refusing: could not resolve the linked closing issue (the SDLC gate requires one)" >&2; exit 1; }
    WALK=$(gh issue view "$ISSUE" --json comments \
      -q "[.comments[].body | select((test(\"spec validation\"; \"i\")) and (contains(\"#$PR\")))] | length" 2>/dev/null || echo 0)
    if [ "${WALK:-0}" -eq 0 ]; then
      echo "refusing: issue #$ISSUE has no spec-validation comment for PR #$PR." >&2
      echo "Post the walk on issue #$ISSUE — every acceptance criterion marked verified (named evidence) / delivered-differently (what changed + why) / N/A (reasoning) — in a comment containing 'Spec validation' and '#$PR', then rerun." >&2
      exit 1
    fi
    gh pr merge "$PR" --squash
    echo "auto-shipped PR #$PR at $SHA (gates green, spec validation on #$ISSUE)"
    exit 0
  fi
  sleep 15
done
echo "timed out waiting for checks on $SHA — nothing merged" >&2
exit 1
