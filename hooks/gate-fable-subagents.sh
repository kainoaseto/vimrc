#!/bin/bash
# gate-fable-subagents.sh -- PreToolUse hook on Agent|Workflow (claude_settings.json).
#
# Rule: a subagent never runs on the session's core model (Fable) without the
# user's explicit approval. CLAUDE_CODE_SUBAGENT_MODEL=sonnet makes an omitted
# model land on the [sonnet] tier, and an explicit model: still wins over that
# pin (measured 2026-09-04 on Claude Code 2.1.261 -- precedence changed in
# 2.1.251; before that the pin overrode every tag). So the only paths left to
# Fable are the ones this script turns into a permission prompt:
#   * subagent_type "fork"                      -- a fork always runs on the session model
#   * model "fable" / "claude-fable-*" / "inherit"
#   * no model on an agent whose DEFINITION decides -- a custom/plugin agent
#     may say `model: inherit`, and the built-in Plan agent inherits too
#   * no model while the EFFECTIVE pin is unset/inherit -- a project
#     .claude/settings.json overrides the user pin per key
#   * a Workflow script that names fable for a stage
# Anything else: exit 0 with no decision, the normal permission flow applies.
# "ask" forces a prompt even in auto mode; headless (-p) has nobody to ask and
# denies, which is the safe default. Prose: ~/.claude/rules/subagent-models.md

set -u
input=$(cat)
tool=$(jq -r '.tool_name // ""' <<<"$input")

ask() {
  jq -n --arg r "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}'
  exit 0
}

case "$tool" in
  Agent)
    model=$(jq -r '.tool_input.model // ""' <<<"$input")
    type=$(jq -r '.tool_input.subagent_type // ""' <<<"$input")
    if [ "$type" = "fork" ]; then
      ask "Fable gate: a fork always runs on the session model (Fable). Approve, or spawn a fresh agent with model: sonnet|opus|haiku."
    fi
    case "$model" in
      fable*|claude-fable*|inherit)
        ask "Fable gate: model '$model' resolves to the session model (Fable). Approve, or re-spawn with model: sonnet|opus|haiku." ;;
    esac
    if [ -z "$model" ]; then
      # The pin the runtime will actually use. A project .claude/settings.json
      # overrides the user-level pin per key (the sdlc init template seeds
      # `inherit`, measured 2026-09-04 in an sdlc-adopting repo), and hooks see the
      # effective value -- so read it here instead of trusting the user setting.
      pin="${CLAUDE_CODE_SUBAGENT_MODEL:-}"
      case "$pin" in
        ""|inherit|fable*|claude-fable*) pin_safe=no ;;
        *) pin_safe=yes ;;
      esac
      case "$type" in
        # built-ins that never reach Fable whatever the pin: Explore is capped
        # at Opus, claude-code-guide/statusline-setup are fixed tiers
        Explore|claude-code-guide|statusline-setup) ;;
        ""|general-purpose)
          [ "$pin_safe" = yes ] || ask "Fable gate: no model: and CLAUDE_CODE_SUBAGENT_MODEL is '${pin:-unset}' here (a project .claude/settings.json overrides the user pin), so this would run on the session model (Fable). Pass model: sonnet|opus|haiku, or approve." ;;
        # custom/plugin agents and the built-in Plan: the definition decides, and
        # `inherit` (or Plan's built-in behaviour) means the session model
        *) ask "Fable gate: '$type' spawned with no model: -- its definition decides, and 'inherit' means Fable. Approve, or pass model: sonnet|opus|haiku." ;;
      esac
    fi
    ;;
  Workflow)
    script=$(jq -r '.tool_input.script // ""' <<<"$input")
    path=$(jq -r '.tool_input.scriptPath // ""' <<<"$input")
    if [ -z "$script" ] && [ -n "$path" ] && [ -r "$path" ]; then
      script=$(cat "$path")
    fi
    if printf '%s' "$script" | grep -qiE 'fable'; then
      ask "Fable gate: the workflow script names fable for a stage. Approve, or use sonnet|opus|haiku."
    fi
    ;;
esac
exit 0
