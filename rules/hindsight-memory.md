# Hindsight Memory

This machine keeps per-repository long-term memory through the `hindsight` MCP server. These rules
apply to subagents and workers too; they never receive the plugin's own tool guide.

## Read Before You Explore

- WHEN a task needs architecture, conventions, or a past decision: call `hindsight_search_knowledge_pages` with the task's key terms BEFORE reading code, then `hindsight_read_knowledge_page` on a match. A page read costs about 4k tokens; re-deriving it from files costs tens of thousands.
- In Claude Code the tools are deferred. Load them first: ToolSearch `select:mcp__hindsight__hindsight_search_knowledge_pages,mcp__hindsight__hindsight_read_knowledge_page`.
- Use `hindsight_reflect` only when the pages are too shallow and you need the WHY. It runs for seconds to minutes.
- WHEN memory informed part of an answer: credit it as `> 🧠 **From Hindsight memory (<page>)** — <facts used>`. Never credit memory that did not contribute.

## Write Less, Write Durable

- `hindsight_capture_initiative` is for features that span sessions. Call it once when the plan is agreed. On a material change, call it again with `relates_to_page_id` so the same page updates. Bug fixes, chores, and single-session work get no initiative.
- `hindsight_ingest_document` is for durable findings: review notes, external documents, corrections. Not progress notes.
- WHEN a served memory is verifiably wrong: ingest a `Correction: <topic>` document stating what memory claimed, what is true now, and the evidence.

## Multi-Agent Sessions

- Only prose and tool CALLS are retained. Tool RESULTS are dropped, so a worker's report or a Codex thread's advice survives only if the lead restates the decision and its reason in its own words.
- WHEN a wave of workers finishes: write one paragraph in the main conversation naming what each worker decided and why, before moving on.
