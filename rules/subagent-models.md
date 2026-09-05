# Subagent Models

Fable is the session's core model: judgment, planning, design, filing. It is never a subagent's model unless the user approves that spawn explicitly. The mechanism is config + a hook, not this prose -- this file says how to work with it.

## What the config does

- `CLAUDE_CODE_SUBAGENT_MODEL=sonnet` in `~/.claude/settings.json`: a spawn that omits `model:` lands on the `[sonnet]` tier, never on the session model. Tags still route: an explicit `model:` on the Agent call wins over the pin (Claude Code >= 2.1.251; measured 2026-09-04 on 2.1.261).
- Tiers are aliases resolved by the `ANTHROPIC_DEFAULT_*_MODEL` remaps in the same file (2026-09: `haiku` -> Sonnet 5, `sonnet` -> Opus 4.6, `opus` -> Opus 5). Edit the remap, never the callers.
- A project `.claude/settings.json` overrides the user pin per key, and the sdlc init template seeds `CLAUDE_CODE_SUBAGENT_MODEL=inherit` into every adopting repo (measured 2026-09-04 in an sdlc-adopting repo: the hook sees `inherit` there, `sonnet` elsewhere). Inside such a repo an omitted `model:` means Fable again, which is why the hook reads the effective value instead of trusting the user setting.
- `hooks/gate-fable-subagents.sh` (PreToolUse on `Agent|Workflow`) turns every remaining path to Fable into a permission prompt: `subagent_type: fork`, `model: fable|claude-fable-*|inherit`, a general-purpose spawn with no `model:` while the effective pin is unset or `inherit`, a custom or `Plan` agent spawned with no `model:`, a Workflow script that names fable. The prompt IS the approval; nothing else counts.

## Rules

- ALWAYS pass `model:` on an Agent call: `sonnet` for routine implementation and prose (the default when unsure), `opus` for security- or architecture-sensitive work, `haiku` only for mechanical tasks whose verify step is itself mechanical. This is the sdlc plugin's tier ladder applied everywhere, not only inside `/sdlc:issue` fan-out.
- NEVER spawn `fork`, `model: fable`, or `model: inherit` on your own judgment. When a task genuinely needs Fable in a subagent, say why in one sentence and let the hook's prompt collect the approval -- do not work around the prompt with a different spawn shape.
- Agent definitions (`agents/*.md` in plugins, `.claude/agents/`) name a tier (`sonnet`/`opus`/`haiku`), never `inherit`: an `inherit` definition runs on Fable the moment a Fable session spawns it.
- Workflow scripts name a tier per stage for the same reason.
- A hook prompt in a headless (`-p`) run is a deny. That is the safe default; do not "fix" it by removing the hook.
