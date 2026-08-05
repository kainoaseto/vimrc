---
name: ship
description: Start and ship a change through the issue-first SDLC - <login>/<type>/<slug> branch off main, conventional commits, PR with semantic title, gated squash merge. Use when starting a feature, bug fix, or chore, or when the user says "new feature", "fix X", "start a branch", "open a PR", or "ship this".
---

# Ship a Change (feat / fix / chore / ...)

Every script here lives in `scripts/` under this skill's base directory and assumes `gh` is installed and authenticated (git push included). If it isn't — fresh machine, `gh auth status` failing, `Permission denied (publickey)` on push — stop and have the user run `scripts/setup.sh` in their own terminal (interactive on first run: installs Homebrew + gh if missing on macOS, wires GitHub auth for gh and git push; repos may wrap it as `make setup`).

Feature-PR flow only; release promotion stays with the repo's deploy process. **Every PR closes an issue** (enforced by the repo's `sdlc-gate` check — a copy ships in this plugin's `templates/sdlc-gate.yaml` for new repos): non-trivial work starts as an issue; standalone use auto-files a one-line linkage issue when none is passed.

## 1. Branch

```
scripts/new-branch.sh <type> <short description words>
```

Types (the same set the PR title check accepts): `feat fix docs style refactor perf test build ci chore revert`.
Creates `<login>/<type>/<slug>` off fresh `origin/main` — the gate requires the login prefix to match the PR author.

**A wrongly-named branch gets fixed, not failed.** If work already lives on a non-conforming branch (a GitHub-web `<login>-patch-1`, a bare `feat/x`), don't restart and never merge around the red gate:

- No PR yet — just proceed to `open-pr.sh`; it renames the branch to conform before the PR exists.
- PR already open — `scripts/fix-branch.sh <N>`. GitHub **closes** a PR whose head branch is renamed (verified live), so the script recreates the branch under a conforming name at the same commit, opens a successor PR carrying the title/body (and with it the issue linkage), closes the old PR as superseded, and deletes the old branch so stale pushes fail loudly. Its last line is `NEW_PR=<n>` — continue there; the spec-validation walk must name the successor.

## 2. Implement and verify

The repo's verification gate (`make verify` or equivalent) must pass before the PR is opened for review.

## 3. Commit

Atomic, conventional-format commits: `<type>: <subject>`. They stay on the branch — squash merging means only the PR title lands on main, so the title (step 4) is what release tooling reads.

## 4. Open the PR

```
scripts/open-pr.sh "<type>: <semantic title>" [issue-number] [body-file] [--draft]
```

- Passing an issue number links it via `Closes #N`; omitting it auto-files a one-line linkage issue.
- Editing the PR body later? Preserve the `Closes #N` line — replacing the body wholesale silently unlinks the issue and fails the gate (learned live).

## 5. Merge (agents: auto-ship)

```
scripts/auto-ship.sh <N>
```

Squash-merges only when the required checks are green on the head SHA — default names `verify`, `Validate PR title`, `SDLC gate`; override per repo with `SDLC_REQUIRED_CHECKS='name1|name2|...'`.

- The `AUTO_SHIP` repo variable is the kill switch (`gh variable set AUTO_SHIP --body off` pauses agent merges; `on` resumes; unset reads as off).
- Refuses to merge until the linked issue carries the **spec-validation comment** for this PR (contains `Spec validation` and `#<pr>`, walking every acceptance criterion: verified with named evidence / delivered-differently with why / N/A with reasoning).
- **Never auto-ships `release-please--*` PRs** — that merge is the deploy decision and stays human.
- Self-heals a non-conforming head branch via `fix-branch.sh` and follows the successor PR number automatically.
