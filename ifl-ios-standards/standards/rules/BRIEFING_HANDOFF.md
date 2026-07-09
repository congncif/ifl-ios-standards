# Briefing handoff — single artifact, append-only

The **briefing** is a single Markdown file passed between stages/sub-agents during one task. It
replaces re-loading the same specs / re-running the same `find`/`git diff` across every hop. Each
hop **reads** the briefing as its primary context and **appends** a typed section for the next hop. No
agent re-reads files the previous hop already cited.

The briefing is also the audit trail for `/ifl-ios-standards:brain-flow` gates: requirement intake,
plan approval, implementation, testing, review, and final report.

## File location

> **Optional, in-repo workspace.** The multi-agent pipeline (orchestrator → sub-agents) writes its
> handoff artifacts into the project's working-docs tree, per
> `${CLAUDE_PLUGIN_ROOT}/standards/process/docs-organization.md` — **default
> `docs/02-working-docs/handoffs/`** (handoffs bucket), archived to `docs/99-archive/handoffs/`.
> This is **optional** for very small single-agent tasks, but any `brain-flow` run that passes through
> a requirement or plan gate should write a lightweight briefing/spec. If the project's `CLAUDE.md`
> declares a different working-docs root, substitute it for `docs/02-working-docs/` throughout this
> file.

```text
docs/02-working-docs/handoffs/{task-slug}/briefing.md
```

- `{task-slug}` is the kebab-case feature name (same slug used for the git branch — `feature/{task-slug}`).
- One briefing per task. Survives the duration of the task; archived to `docs/99-archive/handoffs/` after PR merge.
- Sibling files allowed: `discovery.cache.json`, `diff.patch`, `build.log`. Briefing references them by relative path.

## Required top sections (written by orchestrator or brain-flow Stage 1)

```markdown
# Briefing — {task-slug}

## Meta
- Created: {YYYY-MM-DD HH:MM}
- Flow mode: {co-working|auto}
- Scale: {trivial|small|medium|large|critical}
- Pattern binding: {none|Boardy+VIP|...}
- Orchestrator / runner: {agent, model, workflow, or N/A}
- Base branch: {from the project's configuration — see the consuming repo's CLAUDE.md}
- Branch: {branch name or N/A}
- Project execution target: {workspace/scheme/destination, package target, app target, or N/A}

## Requirement summary
- Ticket/work item ID and title: {ID + title, or N/A with reason}
- Business/user goal: {one paragraph or bullets}
- In scope: {list}
- Out of scope: {list}
- UI/design requirements: {list or N/A}
- API/backend/data requirements: {list or N/A}
- Source code areas likely affected: {paths/modules/components}
- Risks and assumptions: {list, may be empty}
- Open questions: {list, may be empty after approval}

## Requirement gate
- Mode: {co-working|auto}
- Verdict: {USER_APPROVED|AUTO_APPROVED|USER_INPUT_REQUIRED|BLOCKED}
- Reviewer(s): {human user, self-review, subagent roles}
- User confirmation, if any: {summary or N/A}
- Assumptions accepted: {list}
- Open questions resolved: {list}

## Task scope
- Goal: {one paragraph}
- Affected areas: {list}
- New modules / components / services: {list}
- Risks / ambiguities: {list, may be empty}

## Context cache
- Path: {optional cache path or N/A}
- Fields: {pattern/project-specific fields or N/A}

## Acceptance criteria
- [ ] {…}
```

`## Task scope` may be a normalized subset of `## Requirement summary`; keep it for compatibility with
existing specialist agents. `## Context cache` is optional; a bound pattern may define a concrete cache
schema below.

## Plan gate sections

When `/ifl-ios-standards:brain-plan` runs, append an implementation plan and a gate record before any
execution begins:

```markdown
## Implementation plan
- Mode: {co-working|auto}
- Phase summary: {short list}
- Verification strategy: {checkpoint levels per phase, final gate}
- TDD tiers: {Tier 1/2/3 notes per phase}
- Pattern forwarding: {Boardy IO/Sources/Plugins seams or N/A}
- Risks / rollback: {list}

### Phase 1: {name} [verify: L0|L1|L2]
- [ ] T1.1 {task} — Tier {1|2|3}
- [ ] T1.2 {task} — Tier {1|2|3}
Checkpoint:
- Command: {canonical command or binding reference}
- Expected signal: {what success looks like}
- Failure loop: {where to return if red}

## Plan gate
- Mode: {co-working|auto}
- Verdict: {USER_APPROVED|AUTO_APPROVED|CHANGES_REQUIRED|USER_INPUT_REQUIRED|BLOCKED}
- Reviewer(s): {human user or AI reviewer roles}
- User approval, if any: {summary or N/A}
- Findings resolved: {list}
- Deferred non-blocking work: {list or none}
```

## Reviewer verdict format

Requirement and plan reviewers must use this format so the orchestrator/brain-flow runner can merge
results deterministically:

```markdown
## {Requirement|Plan} review verdict

Reviewer: {role}
Verdict: APPROVED | CHANGES_REQUIRED | USER_INPUT_REQUIRED | BLOCKED

Findings:
- Severity: blocking | material | non-blocking
- Standard/rule:
- Finding:
- Required action:
```

Gate aggregation rules:

- any `BLOCKED` → gate verdict `BLOCKED`;
- any `USER_INPUT_REQUIRED` → gate verdict `USER_INPUT_REQUIRED`;
- `CHANGES_REQUIRED` only → revise the artifact and rerun review if the change stays within approved scope;
- all `APPROVED`, or only non-blocking findings recorded/deferred → `AUTO_APPROVED` in auto mode;
- explicit human approval → `USER_APPROVED` in co-working mode.

## Per-hop appended sections

Each specialist appends **its own** section using a typed heading. **Never edit a prior section.** If
a fact in a prior section is wrong, append a new section titled `## Correction — {section being corrected}`.

| Hop | Heading the hop must append |
|-----|-----------------------------|
| `brain-flow` Stage 1 | `## Requirement summary` + `## Requirement gate` |
| `brain-plan` / plan gate | `## Implementation plan` + `## Plan gate` |
| architect stage/agent | `## Architecture decision` — contracts/types chosen, boundaries, visibility, ADR refs |
| implementer stage/agent | `## Implementation report` — files created/modified, build status, deferred TODOs |
| tester stage/agent | `## Test report` — files created, coverage or signal table |
| reviewer stage/agent | `## Review report` — verdict, blockers, warnings, suggestions |
| researcher stage/agent | `## Lookup result — {short label}` — paths + line numbers only (no source dump) |
| docs stage/agent | `## Docs report` — changelog / ADR / generated-doc status |
| final reporter | `## Final report` — changed files, commands run, results, remaining work |

## Reading rules (every hop)

1. **Read briefing.md first.** If absent or missing the sections required for the current hop, return
   `STATUS: BRIEFING_REQUIRED` and stop. Do not discover the task from the user prompt yourself.
2. **Read only the files cited in prior sections.** If you need additional files, call `ios-researcher`
   — do not run your own `grep`/`find`.
3. **Use compact specs by default** (`${CLAUDE_PLUGIN_ROOT}/standards/specs/compact/*.compact.md`).
   Load full `${CLAUDE_PLUGIN_ROOT}/standards/specs/{NAME}.md` only when the compact subset is
   insufficient for the hop's responsibility.
4. In auto mode, a gate verdict of `AUTO_APPROVED` is enough to proceed. Do not ask the user again
   unless the current hop discovers material ambiguity, missing bindings, destructive action, or a
   blocker.

## Writing rules (every hop)

1. **Append, never edit.** Each section is immutable once written.
2. **Write long artifacts section-by-section.** Follow
   `${CLAUDE_PLUGIN_ROOT}/standards/process/long-document-writing.md`: create a skeleton first,
   append one major section per chunk, and write final status only after final verification.
3. **Cite, don't repeat.** Reference paths + line numbers; never paste full source.
4. **Mark deferred work explicitly** with `DEFERRED: {what} — owner: {agent}`. The next hop is
   responsible for picking it up or escalating.
5. **End your section with `STATUS:`** — one of:
   - `READY_FOR_{NEXT_AGENT}` — happy path.
   - `BLOCKED — {reason}` — escalate to orchestrator.
   - `CORRECTION_NEEDED — {prior hop} — {reason}` — escalate to orchestrator.
   - `INFO_REQUIRED — {what}` — only if the user must answer.

## Orchestrator delegation pattern

When invoking a specialist via the `Task` tool:

```text
You are {agent-name}. Read docs/02-working-docs/handoffs/{task-slug}/briefing.md and follow the rules in ${CLAUDE_PLUGIN_ROOT}/standards/rules/BRIEFING_HANDOFF.md. Append your typed section to the briefing. Do not echo prior sections in your reply — return only your STATUS line plus a one-paragraph summary of what you appended.
```

No additional context paste. The briefing is the entire context.

For any task delegated by `brain-flow`, pass the detected flow mode in the briefing `## Meta`. The
orchestrator must preserve the same gate semantics:

- co-working mode → user confirms requirements and approves the plan;
- auto mode → AI gate reviewers approve requirements and plan; user is asked only for escalation cases.

## Optional context cache

A context cache is optional and pattern-specific. Use it when discovery is expensive or reused by
multiple hops. Keep the cache project-wide only when it is safe to share across tasks; otherwise keep
it under the task handoff folder.

```jsonc
{
  "config_hash": "sha256 of project binding/config files",
  "generated_at": "2026-05-23T10:00:00Z",
  "base_branch": "main",
  "project_targets": ["workspace/scheme/package target/app target"],
  "module_roots": ["path/to/modules"],
  "contract_index": [
    { "id": "contract-or-entrypoint-id", "visibility": "public|internal", "owner": "module/component" }
  ],
  "composition_roots": ["path/or/type names"],
  "verification_commands": ["targeted test/build commands"]
}
```

### Invalidation rules

The cache is **invalid** (must be rebuilt by the owning researcher/discovery stage) whenever any of
these is true:
1. `config_hash` no longer matches the project binding/config files used to build it.
2. A module/component target appears, disappears, or changes ownership.
3. `generated_at` is older than the pattern's cache TTL, defaulting to 7 days.
4. The current task creates or renames modules/components/contracts included in the cache.

### How stages consume it

- **Orchestrator / runner:** checks existence + hash; if invalid, delegates rebuild to the owning
  researcher/discovery stage, then reads.
- **Architect:** consumes module roots and contract indexes to avoid collisions; never edits.
- **Implementer:** consumes composition roots and project targets for wiring/build context.
- **Researcher/discovery stage:** the **only** writer. Writes via tool-supported file writes; never edits
  in place from another stage.
- **Reviewer / tester / docs stage:** read-only consumers.

### Boardy+VIP cache extension

A Boardy+VIP binding may extend the generic cache with fields such as:

```jsonc
{
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

## Archival

After PR merge, the orchestrator moves the task folder to
`docs/99-archive/handoffs/{YYYY-MM-DD}-{task-slug}/` for traceability. Do not delete — the briefing is
the audit trail for the change.

## Why this exists

Before: every specialist re-read `QUICK_REF.md` + relevant specs + `PROJECT_CONFIG.md` + ran its own
`find`/`git diff`. Across 4 hops, the same ~5 KB of context was re-tokenized ~16 times.

After: the orchestrator pays the discovery cost once; each specialist pays only its own delta. The new
requirement/plan gates add traceability without reintroducing repeated discovery. Estimated token
savings per task remain 55–70% on specialist hops, 30–40% end-to-end.
