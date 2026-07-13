---
name: brain-testing
description: >-
  Use when deciding or implementing test strategy for executable iOS code, including domain logic,
  public contracts, adapters, concurrency, UI behavior, regressions, and integration seams.
---

# Brain — Testing

Testing applies to executable code behavior. Read the project's test bindings and the relevant testing
standard; in Boardy+VIP projects also use `boardy-testing`. Use
`${CLAUDE_PLUGIN_ROOT}/standards/process/full-auto-operating-model.md` for failure and corrective-batch cadence.

## Strategy

- Use strict RED → GREEN for domain behavior, algorithms, regressions, security/data-integrity logic,
  concurrency invariants, and non-obvious public contracts.
- Use focused test-after for ordinary adapters, mappers, and composition wiring.
- Use integration or UI tests only for behavior that cannot be proven reliably below that boundary.
- Test Interactors, Presenters, UseCases, repositories, and navigation contracts before View plumbing.
- Run the smallest relevant code signal after the affected behavior is ready. Reuse that observation at
  semantic-task completion unless executable code or risk changed; do not rerun unchanged code merely
  for a second green signal.

Documentation, standards prose, templates, comments, metadata, examples used only for explanation,
and documentation-only schemas do not require TDD or runtime tests. Review their consistency once in
the plan's final AI review.

Do not create plugin-owned verifier/lint/smoke scripts, checkpoint gates, receipts, manifests, or
duplicate CI. A final-review correction that changes executable code receives only its affected focused
signal. Report only commands actually run and observed results.
