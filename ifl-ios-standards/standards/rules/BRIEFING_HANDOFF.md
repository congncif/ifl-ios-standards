# Briefing handoff — single artifact, append-only

The **briefing** is a single Markdown file passed between sub-agents during one task. It replaces re-loading the same specs / re-running the same `find`/`git diff` across every hop. Each hop **reads** the briefing as its primary context and **appends** a typed section for the next hop. No agent re-reads files the previous hop already cited.

## File location

> **Optional, in-repo workspace.** The multi-agent pipeline (orchestrator → sub-agents) writes its
> handoff artifacts into the project's working-docs tree, per
> `${CLAUDE_PLUGIN_ROOT}/standards/process/docs-organization.md` — **default
> `docs/02-working-docs/handoffs/`** (handoffs bucket), archived to `docs/99-archive/handoffs/`.
> This is **optional**: only the delegated orchestrator pipeline needs it; a single-agent task can
> skip the briefing entirely. If the project's `CLAUDE.md` declares a different working-docs root,
> substitute it for `docs/02-working-docs/` throughout this file.

```
docs/02-working-docs/handoffs/{task-slug}/briefing.md
```

- `{task-slug}` is the kebab-case feature name (same slug used for the git branch — `feature/{task-slug}`).
- One briefing per task. Survives the duration of the task; archived to `docs/99-archive/handoffs/` after PR merge.
- Sibling files allowed: `discovery.cache.json`, `diff.patch`, `build.log`. Briefing references them by relative path.

## Required top sections (written by orchestrator step 1)

```markdown
# Briefing — {task-slug}

## Meta
- Created: {YYYY-MM-DD HH:MM}
- Orchestrator model: {opus}
- Base branch: {from the project's configuration — see the consuming repo's CLAUDE.md}
- Branch: feature/{task-slug}
- Workspace / Scheme / Destination: {from the project's configuration}

## Task scope
- Goal: {one paragraph}
- Affected modules: {list}
- New modules / boards / services: {list}
- Risks / ambiguities: {list, may be empty}

## Discovery cache
- Path: docs/02-working-docs/handoffs/{task-slug}/discovery.cache.json
- Fields: module_roots, boardid_index, service_map_classes, base_branch

## Acceptance criteria
- [ ] {…}
```

## Per-hop appended sections

Each specialist appends **its own** section using a typed heading. **Never edit a prior section.** If a fact in a prior section is wrong, append a new section titled `## Correction — {section being corrected}`.

| Hop | Heading the hop must append |
|-----|-----------------------------|
| `ios-architect` | `## Architecture decision` — IO files created, BoardIDs chosen, InOut shapes, ADR refs |
| `ios-coder` | `## Implementation report` — files created/modified, build status, deferred TODOs |
| `ios-tester` | `## Test report` — files created, coverage table |
| `ios-reviewer` | `## Review report` — verdict, blockers, warnings, suggestions |
| `ios-researcher` | `## Lookup result — {short label}` — paths + line numbers only (no source dump) |
| `ios-doc-scribe` | `## Docs report` — CHANGELOG / VI parity / compact regen status |

## Reading rules (every hop)

1. **Read briefing.md first.** If absent or missing the "Task scope" section, return `STATUS: BRIEFING_REQUIRED` and stop. Do not discover the task from the user prompt yourself.
2. **Read only the files cited in prior sections.** If you need additional files, call `ios-researcher` — do not run your own `grep`/`find`.
3. **Use compact specs by default** (`${CLAUDE_PLUGIN_ROOT}/standards/specs/compact/*.compact.md`). Load full `${CLAUDE_PLUGIN_ROOT}/standards/specs/{NAME}.md` only when the compact subset is insufficient for the hop's responsibility.

## Writing rules (every hop)

1. **Append, never edit.** Each section is immutable once written.
2. **Cite, don't repeat.** Reference paths + line numbers; never paste full source.
3. **Mark deferred work explicitly** with `DEFERRED: {what} — owner: {agent}`. The next hop is responsible for picking it up or escalating.
4. **End your section with `STATUS:`** — one of:
   - `READY_FOR_{NEXT_AGENT}` — happy path.
   - `BLOCKED — {reason}` — escalate to orchestrator.
   - `CORRECTION_NEEDED — {prior hop} — {reason}` — escalate to orchestrator.
   - `INFO_REQUIRED — {what}` — only if the user must answer.

## Orchestrator delegation pattern

When invoking a specialist via the `Task` tool:

```
You are {agent-name}. Read docs/02-working-docs/handoffs/{task-slug}/briefing.md and follow the rules in ${CLAUDE_PLUGIN_ROOT}/standards/rules/BRIEFING_HANDOFF.md. Append your typed section to the briefing. Do not echo prior sections in your reply — return only your STATUS line plus a one-paragraph summary of what you appended.
```

No additional context paste. The briefing is the entire context.

## Discovery cache schema

`docs/02-working-docs/handoffs/discovery.cache.json` is project-wide (one file across tasks), not task-scoped. Owned by `ios-researcher`; read by every agent that needs structural facts.

```jsonc
{
  "config_hash": "sha256 of PROJECT_CONFIG.md + PROJECT_STRUCTURE.md",
  "generated_at": "2026-05-23T10:00:00Z",
  "module_roots": ["submodules/Modules", "submodules/Shared"],
  "base_branch": "develop",
  "git_remote": "origin",
  "workspace": "{Workspace}.xcworkspace",
  "main_scheme": "{MainScheme}",
  "xcodebuild_destination": "platform=iOS Simulator,name=iPhone 17,OS=latest",
  "service_map_classes": [
    { "module": "Cart", "class": "CartServiceMap", "accessor": "modCart" }
  ],
  "boardid_index": [
    { "id": "pub.mod.Cart.Checkout", "visibility": "public", "module": "Cart" },
    { "id": "mod.Cart.LineItem", "visibility": "internal", "module": "Cart" }
  ],
  "podspecs": ["submodules/Modules/Cart/Cart.podspec", "..."]
}
```

### Invalidation rules

The cache is **invalid** (must be rebuilt by `ios-researcher`) whenever any of these is true:
1. `config_hash` no longer matches a fresh hash of `PROJECT_CONFIG.md` + `PROJECT_STRUCTURE.md`.
2. A new `*.podspec` appears or `submodules/` adds/removes a directory.
3. `generated_at` is older than 7 days.
4. The current task is `module-creation` — always rebuild after the architect appends.

### How agents consume it

- **Orchestrator (step 1):** check existence + hash; if invalid, delegate to `ios-researcher` with `{ "action": "rebuild-cache" }`, then read.
- **Architect:** consume `module_roots`, `boardid_index` to avoid collisions; never edits.
- **Coder:** consume `service_map_classes` for the import-and-extend pattern.
- **Researcher:** the **only** writer. Writes via `Write` tool; never edits in place from another agent.
- **Reviewer / Tester / Doc-scribe:** read-only consumers.

## Archival

After PR merge, the orchestrator moves the task folder to `docs/99-archive/handoffs/{YYYY-MM-DD}-{task-slug}/` for traceability. Do not delete — the briefing is the audit trail for the change.

## Why this exists

Before: every specialist re-read `QUICK_REF.md` + relevant specs + `PROJECT_CONFIG.md` + ran its own `find`/`git diff`. Across 4 hops, the same ~5 KB of context was re-tokenized ~16 times.

After: the orchestrator pays the discovery cost once; each specialist pays only its own delta. Estimated token savings per task: 55–70% on the specialist hops, 30–40% end-to-end.
