---
name: brain-testing
description: >-
  Use when deciding test strategy — what to test, at which tier, with what signal. Pattern-neutral:
  applies to any iOS project, Boardy or not. Triggers: "what should we test", "test strategy",
  "which TDD tier", "is this worth a test".
---

# Brain — Testing (strategy, tiers, signal)

Pattern-neutral testing stage of the brain rulebook.

## Read
- `${CLAUDE_PLUGIN_ROOT}/standards/brain/rulebook/15-testing-philosophy.md` — test what matters, signal over coverage.
- `${CLAUDE_PLUGIN_ROOT}/standards/process/lean-verification.md` — risk-tiered TDD policy + checkpoint cadence.

## Tiering (per lean-verification)
- **Full TDD**: core business logic, public APIs, algorithms, bug fixes that could regress.
- **Test-after, batched**: glue, adapters, UI wiring — after a related group of tasks.
- **No tests required**: config, type declarations, styling, docs, throwaway prototypes.
When unsure which tier applies, ask once.

## Guardrails
- Test behavior through the public seam, not implementation details.
- A test that can't fail is theater — watch new full-TDD tests fail first.
- Run checkpoint verification at plan phase boundaries only; do not add full build/test cycles after every small task.
- Map verification signals back to the approved Definition of Done checklist.
- Run targeted test files during work; full suite once at completion.

## Pattern hook
Project's `CLAUDE.md` binds Boardy+VIP → load `/ifl-ios-standards:boardy-testing` for the
mock/stub/interactor-test skeletons (`TESTING.compact.md`). For the delegated pipeline, the
`ios-tester` agent owns this.
