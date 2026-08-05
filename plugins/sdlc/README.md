# sdlc

The shared issue-first SDLC machinery, extracted from `drawdownhq/drawdown-landing` so every repo consumes one copy instead of embedding drift-prone clones.

## What's inside

- **`skills/ship`** — the ship flow: `setup.sh` (machine bootstrap: brew + gh + GitHub auth wired for git push), `new-branch.sh` (`<login>/<type>/<slug>` off origin/main), `open-pr.sh` (auto-files a linkage issue, renames a non-conforming branch pre-PR), `fix-branch.sh` (repairs an open PR's bad branch by superseding it — GitHub closes PRs on head-branch rename, so rename-in-place is impossible), `auto-ship.sh` (gated agent squash-merge: required checks green + spec-validation walk on the linked issue + `AUTO_SHIP` flag; self-heals branches; never touches release PRs).
- **`templates/sdlc-gate.yaml`** — the enforcement workflow (branch pattern + linked closing issue; exempts `release-please--*`, bots, and the `sdlc-exempt` label). Copy into the adopting repo's `.github/workflows/` — GitHub only runs workflows from the repo itself.

## Adopting in a repo

1. Copy `templates/sdlc-gate.yaml` to `.github/workflows/sdlc-gate.yaml`.
2. Create the `sdlc-exempt` label; set the flag: `gh variable set AUTO_SHIP --body on` (or `off` to keep merges human).
3. Reference this plugin (repo `.claude/settings.json`) so collaborators get the skill:
   ```json
   {
     "extraKnownMarketplaces": {
       "kainoaseto-plugins": { "source": { "source": "github", "repo": "kainoaseto/vimrc" } }
     },
     "enabledPlugins": { "sdlc@kainoaseto-plugins": true }
   }
   ```
4. If the repo's required check names differ from `verify` / `Validate PR title` / `SDLC gate`, set `SDLC_REQUIRED_CHECKS='name1|name2|...'` where `auto-ship.sh` runs.

## Updating this plugin

Edits happen **here, on branches** — never by patching a consuming repo's embedded copy. Multiple agents work this repo concurrently: always use a `git worktree` off `origin/master` (`git worktree add <dir> -b <login>/<type>/<slug> origin/master`) so checkouts never collide, and land through a PR. Bump `version` in `.claude-plugin/plugin.json` on every change; consuming repos pick it up on plugin update.
