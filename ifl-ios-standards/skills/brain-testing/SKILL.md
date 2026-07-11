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
- **Tier 1 — strict test-first**: core business logic, public/wire APIs, algorithms, security/data
  integrity, and bug fixes that could regress. Observe a behavioral and causal RED → GREEN.
- **Tier 2 — test-after, batched**: glue, adapters, mappers, ordinary wiring, and composition without
  business rules — within the semantic checkpoint.
- **Tier 3 — no runtime test required**: config, type declarations, styling, docs, and explicit
  throwaway prototypes.
When unsure which tier applies, ask once.

## Signal ladder and ownership

- During a work slice, run only its causal/static/schema signal. A missing tool, stale cache, sandbox
  failure, helper compile error, or invalid fixture is not a Tier-1 behavioral RED.
- Before freezing a semantic checkpoint, run one accumulated focused seam/module proof after its last
  planned slice; do not rerun unrelated targeted tests after every slice.
- Treat the accumulated focused signal and checkpoint owning gate as separate plan fields. Execute one
  receipt only when the plan declares them `EQUAL` and their command, obligations, and candidate
  fingerprint still match; otherwise the checkpoint owner remains pending.
- Run full suite/build/integration at the one declared wave/release owner after the final relevant
  mutation. Project bindings provide canonical commands and targets.
- A higher gate may replace a lower one only when every gate-subsumption condition in
  `lean-verification.md` holds. Evaluate before the lower gate would run, then record
  `SUBSUMED_BY:<gate-id>`; never subsume retroactively. A higher green gate cannot replace an unobserved
  Tier-1 RED.
- Apply the complete normative evidence schema in `lean-verification.md` §7 without omitting fields.
  Candidate fingerprints identify evaluated inputs/context/obligations; unique append-only audit-ledger
  identities identify individual attempts and dispositions. Reuse a receipt only while every normative
  field matches; invalidate affected evidence after a relevant change.

## Guardrails
- Test behavior through the public seam, not implementation details.
- A test that can't fail is theater — watch new full-TDD tests fail first.
- Add causal regression tests for behavioral defects only. Prove mechanical/generated/schema/lint/docs
  corrections with static, lint, schema/digest signals, or Tier 3 as applicable.
- Treat semantic checkpoints—not task/file/phase counts—as verification boundaries.
- Do not add review, commit, or full build/test cycles after every work slice.
- Map verification signals back to the approved Definition of Done checklist.
- Run the accumulated checkpoint proof once after its last planned slice and each expensive gate once
  per current fingerprint at its declared owner, unless a real failure or invalidation requires rerun.
- Zero review findings never closes a distinct pending checkpoint owner. Before commit/completion, the
  staged candidate manifest must match the fingerprint referenced by current owning-gate and final
  review/confirmation evidence.

## Pattern hook
Project's `CLAUDE.md` binds Boardy+VIP → load `/ifl-ios-standards:boardy-testing` for the
mock/stub/interactor-test skeletons (`TESTING.compact.md`). For the delegated pipeline, the
`ios-tester` agent owns this.
