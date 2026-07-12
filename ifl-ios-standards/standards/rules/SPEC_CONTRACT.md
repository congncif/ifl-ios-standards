# SPEC_CONTRACT — 12-section structure for `${CLAUDE_PLUGIN_ROOT}/standards/specs/*.md`

> Applies to **pattern specs** (`MICROBOARD_UI.md`, `COMMUNICATION.md`, `SERVICE_LAYER.md`, …) — anything the agent loads to make a design or coding decision. Index / example / readme files are exempt (see Exemptions below).

Each pattern spec MUST contain the following H2 sections, in this order, with these exact headings:

| # | Heading | Required content |
|---|---------|------------------|
| 1 | `## When to use` | Concrete scenarios this pattern fits. Decision tree welcome. |
| 2 | `## When NOT to use` | Anti-fit scenarios + the pattern they should pick instead. |
| 3 | `## Forces` | Tradeoffs the pattern resolves (perf vs. ergonomics, isolation vs. sharing, …). |
| 4 | `## Files` | Full paths of every file the pattern creates or modifies, with role per file. |
| 5 | `## Naming` | Class/protocol/file/BoardID naming rules — link to QUICK_REF Module-naming table when applicable. |
| 6 | `## Communication` | Direction matrix (who calls whom, via which channel — flow / bus / delegate / interaction). |
| 7 | `## Concurrency` | MainActor rules, `await`, Task lifetime, retain cycles, weak captures. |
| 8 | `## Composition` | How the pattern is wired into a ModulePlugin / ServiceMap / parent board. |
| 9 | `## Lifecycle` | `activate` / `complete` / `detachObject` rules, double-activation guard, attached-object release. |
| 10 | `## Testing` | What to test (Interactor / Presenter / UseCase priorities), what to mock, what to stub. |
| 11 | `## Pitfalls` | Known foot-guns and the specific symptoms each produces. |
| 12 | `## References` | Cross-links to companion specs, ADRs, brain rulebook chapters, example files. |

Optional H2 sections **may** appear, but only **after** §12 (e.g. `## Migration notes`, `## FAQ`). They never replace a required section.

## Authoring rules

- Use H2 (`## `) — not H3 — for the 12 required headings.
- Keep the required headings in order so agents can navigate every pattern consistently.
- A section may be intentionally empty for a spec that has nothing to say (e.g. a pure-domain spec has no `## Concurrency`); leave a single line `_Not applicable — <one-sentence reason>._` so the section is present but explicit.
- Cite, don't repeat. If a rule lives in QUICK_REF or BOARDY_CHEATSHEET, link to it instead of copying.
- Keep examples runnable — every code block must compile against the current Boardy+VIP pin.

## Exemptions

The following non-pattern documents use their own fit-for-purpose structure:

- `README.md`
- `ADOPTION.md`
- `CONVENTIONS.md`
- `EXAMPLES.md` and `EXAMPLES_*.md`
- `PACKAGE_MANAGER.md` (policy / ADR-shaped, not a pattern spec)
- `REVIEWER_CHECKLIST.md` (its own format)
- `DECISION_TREES.md` (navigator / routing index, not a pattern spec)
- `BROWNFIELD_MIGRATION.md` (procedural runbook, not a pattern spec)
- `TROUBLESHOOTING.md` (symptom → fix navigator, not a pattern spec)
- `GREENFIELD_SETUP.md` (procedural runbook for new-app setup, not a pattern spec)
- `REVIEW_PLAYBOOK.md` (procedural runbook for code review, not a pattern spec)
- `REFACTOR_PLAYBOOK.md` (procedural runbook for structural refactors, not a pattern spec)
- Anything under `compact/` (compact specs have their own slim schema)

## Review cadence

The plan's single final AI consistency review checks changed pattern specs for required headings,
ordering, exemptions, cross-references, and runnable examples. Do not add a bundled lint script or a
separate per-spec review loop.
