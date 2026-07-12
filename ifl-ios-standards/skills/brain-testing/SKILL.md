---
name: brain-testing
description: >-
  Use when deciding or implementing test strategy for executable iOS code, including domain logic,
  public contracts, adapters, concurrency, UI behavior, regressions, and integration seams.
---

# Brain — Testing

Testing applies to executable code behavior. Read the project's test bindings and the relevant testing
standard; in Boardy+VIP projects also use `boardy-testing`.

## Strategy

- Use strict RED → GREEN for domain behavior, algorithms, regressions, security/data-integrity logic,
  concurrency invariants, and non-obvious public contracts.
- Use focused test-after for ordinary adapters, mappers, and composition wiring.
- Use integration or UI tests only for behavior that cannot be proven reliably below that boundary.
- Test Interactors, Presenters, UseCases, repositories, and navigation contracts before View plumbing.
- Run the smallest relevant code test while implementing, then the consuming project's applicable
  code-test command once after the semantic task is complete.

Documentation, standards prose, templates, comments, metadata, examples used only for explanation,
and documentation-only schemas do not require TDD or runtime tests. Review their consistency once in
the plan's final AI review.

Do not create plugin-owned verifier/lint/smoke scripts, checkpoint gates, receipts, manifests, or
duplicate CI. Report only commands actually run and observed results.
