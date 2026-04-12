# vimrc

Opinionated Claude Code and Codex CLI configuration, plus a Claude Code plugin
with skills and review agents. Originally a personal dotfiles repo — now
structured so anyone can clone and install.

## Prerequisites

- [jq](https://jqlang.github.io/jq/download/)
- [git](https://git-scm.com/)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)

Optional (configured by install but not required):

- [Codex CLI](https://github.com/openai/codex) — OpenAI's CLI agent
- [Atlassian MCP](https://mcp.atlassian.com/) — Jira integration (configured as a global MCP server)

## Quick Start

```bash
git clone https://github.com/kainoaseto/vimrc.git
cd vimrc
./install.sh
```

The install script will:

1. Clone the [bits](https://github.com/abatilo/bits) third-party plugin if not already present
2. Generate `~/.claude/settings.json` from the core config template
3. Merge your local overrides (if `claude_settings.local.json` exists)
4. Symlink rules and global instructions into `~/.claude/`
5. Configure global MCP servers (Codex, Jira) in `~/.claude.json`
6. Generate `~/.codex/config.toml` and symlink agent instructions

Re-run `./install.sh` any time you pull changes or update your local config.

## Configuration

Settings are split into two layers:

### Core config (`claude_settings.json`)

Shared defaults that everyone gets. Includes:

- **Model**: Opus with 1M context
- **Env tuning**: max effort, extended output tokens, autocompact at 60%
- **Permissions**: pre-approved common CLI tools (git, go, helm, kubectl, terraform, etc.)
- **Plugins**: kainoaseto-core, bits, wakatime, gopls-lsp, skill-creator
- **Features**: agent teams, LSP tool, tool search, always-think, dangerous mode

Edit this file to change defaults for all users. Paths use `__INSTALL_DIR__`
and `__BITS_DIR__` placeholders — the install script substitutes them.

### Local overrides (`claude_settings.local.json`)

Machine-specific settings that get deep-merged on top of the core config. This
file is git-ignored so your personal settings stay local.

To get started:

```bash
cp claude_settings.local.json.example claude_settings.local.json
```

Then edit to your needs. The example includes:

- **`permissions.additionalDirectories`** — extra directories Claude can access (e.g. `~/Workspace`)
- **`hooks.Stop`** — play a sound when Claude finishes (macOS `afplay` example)

Any key from the [Claude Code settings schema](https://json.schemastore.org/claude-code-settings.json)
can be overridden here. The merge is recursive — object keys are merged, arrays
and scalars are replaced.

### Rules (`rules/`)

Global rules symlinked to `~/.claude/rules/`. These define agent behavior:

| File | Purpose |
|---|---|
| `simple.md` | Simplicity-first engineering principles |
| `task-tracking.md` | Eager task list usage |
| `agent-teams.md` | Agent team lifecycle and shutdown protocol |
| `codex-mcp.md` | Codex MCP for collaborative planning |
| `gopls-lsp.md` | Go LSP usage guidance (scoped to `*.go` files) |

## Third-Party Dependencies

### bits ([abatilo/bits](https://github.com/abatilo/bits))

Task and work-item tracking plugin for Claude Code. Cloned automatically by the
install script as a sibling directory (`../bits` relative to this repo).

Override the location with the `BITS_DIR` environment variable:

```bash
BITS_DIR=~/my/bits/path ./install.sh
```

## Plugin: kainoaseto-core

Bundled in `plugins/kainoaseto-core/`. Installed automatically via the
`extraKnownMarketplaces` config — no manual plugin commands needed.

### Skills

| Skill | Description |
|---|---|
| `git-commit` | Atomic commits with conventional commit messages |
| `git-spice` | Branch and PR management via git-spice |
| `kubernetes` | kubectl, Helm, and kustomize operations |
| `repo-explore` | Clone and explore external GitHub repos |
| `diataxis-documentation` | Documentation following the Diataxis framework |
| `interview` | Deep probing questions before implementation |
| `socratic` | Exhaustive collaborative debate via Claude + Codex |
| `code-review` | Structured code review |

### Review Agents

Specialized agents for thorough PR review:

- `architecture-reviewer` — design and structure
- `correctness-reviewer` — logic and bugs
- `security-reviewer` — vulnerabilities and auth
- `performance-reviewer` — efficiency and scaling
- `maintainability-reviewer` — readability and evolvability
- `testing-reviewer` — test coverage and quality
- `governance-reviewer` — change risk and compliance

## What Gets Installed Where

| Source | Destination | Method |
|---|---|---|
| `claude_settings.json` | `~/.claude/settings.json` | Generated (template + sed) |
| `claude_settings.local.json` | Merged into above | jq deep-merge |
| `CLAUDE_global.md` | `~/.claude/CLAUDE.md` | Symlink |
| `rules/` | `~/.claude/rules` | Symlink |
| MCP servers | `~/.claude.json` | jq write |
| `codex_config.toml` | `~/.codex/config.toml` | Generated (template + sed) |
| `AGENTS_global.md` | `~/.codex/AGENTS.md` | Symlink |
