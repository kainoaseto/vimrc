# code-reviewer

Multi-agent code and spec review plugin for Claude Code. Forked from [@djenriquez](https://github.com/djenriquez)'s [`djenriquez-core`](https://github.com/djenriquez/claude-plugins).

## Skills

### /spec-review

Multi-agent spec review that catches ambiguity, missing edge cases, architectural infeasibility, API design gaps, operational blindspots, and scope risks — before a single line of code is written.

```
/spec-review path/to/spec.md
/spec-review #42                   # GitHub issue or PR (auto-detected)
/spec-review https://docs.google.com/...
/spec-review staged
/spec-review                       # uses conversation context
```

Spawns a team of specialist reviewers, dynamically selected based on what the spec covers:

| Specialist | Focus |
|------------|-------|
| clarity-reviewer | Ambiguity, contradictions, undefined terms, testable acceptance criteria |
| completeness-reviewer | Missing edge cases, error behavior, NFRs, state transitions |
| product-reviewer | Goal alignment, user value, success criteria, scope-to-value ratio |
| feasibility-reviewer | Technical feasibility, architectural fit, hidden complexity |
| api-reviewer | API surface, backward compat, protobuf conventions, idempotency |
| operations-reviewer | Failure modes, observability, rollback, SLO impact, on-call burden |
| scope-reviewer | Incremental delivery, dependency risks, timeline, scope creep |
| complexity-reviewer | Premature abstractions, over-engineering, speculative generality |

Review rigor scales with risk:

- **L0 (Minor)**: Typo fixes, small clarifications — clarity + completeness only
- **L1 (Significant)**: New features, API additions — dynamic agent selection, self-critique, cross-review
- **L2 (Strategic)**: Architecture changes, new services — full review with all relevant specialists

Three phases: parallel specialist review → lead-mediated cross-review → deduplicated synthesis with binary verdict (APPROVED / REVISIONS NEEDED).

### /issue-to-spec

Takes a GitHub issue through exploration, user interview, spec authoring, complexity assessment, and conditional `/spec-review` — producing a hardened spec ready for implementation.

```
/issue-to-spec #42
/issue-to-spec 42
```

Workflow:
1. Retrieves the issue and explores the relevant codebase
2. Interviews the user to fill gaps (uses `/interview` from `kainoaseto-core` if available, otherwise asks directly)
3. Authors a spec at `docs/specs/<name>.md`
4. Assesses complexity (trivial vs complex)
5. For complex specs, launches `/spec-review` and incorporates feedback

### /handle-pr-feedback

Reads unresolved review comments on a GitHub PR, triages each one, makes code changes, pushes a commit, replies to every comment, and resolves each thread.

```
/handle-pr-feedback #42
/handle-pr-feedback 42
```

1. Checks out the PR branch and fetches unresolved review threads via GitHub GraphQL API
2. For each thread, decides whether to **address** (make a code change) or **skip** (with explanation)
3. Commits and pushes all changes in a single commit
4. Replies to each comment thread with the action taken or reason for skipping
5. Resolves every thread

### /self-review-loop

Iterative self-improvement loop for PRs. Launches a fresh, context-free sub-agent each turn to run a code review, evaluates and applies feedback. Loops until only minor feedback remains or 5 turns complete.

```
/self-review-loop #42
/self-review-loop 42
```

1. Auto-discovers the available code review skill (prefers official `code-review` plugin, falls back to `kainoaseto-core:code-review`)
2. Spawns a fresh sub-agent with no prior context to run the review
3. Triages each finding (address or skip)
4. Runs tests/linters to verify changes, commits and pushes
5. Repeats with a new fresh agent until clean or 5 turns reached
6. Reports a full changelog across all turns

Requires one of: `code-review` from `claude-code-marketplace` or `kainoaseto-core`.

## Agents

All 8 specialist agents share a common review protocol (comment taxonomy, self-critique, cross-review) and each adds domain-specific checklists. They use `memory: local` to persist learnings across sessions.

Agents are not invoked directly — they're spawned by `/spec-review` as needed.

## Dependencies

- `gh` CLI for GitHub API access
- `kainoaseto-core` plugin (optional, for `/interview` skill and `code-review` fallback)

## Acknowledgments

Forked from [@djenriquez](https://github.com/djenriquez)'s [`djenriquez-core`](https://github.com/djenriquez/claude-plugins). The multi-agent architecture (three-phase orchestration, specialist agents, risk lanes, cross-review) is adapted from [@abatilo](https://github.com/abatilo)'s [`abatilo-core` code-review skill](https://github.com/abatilo/vimrc).
