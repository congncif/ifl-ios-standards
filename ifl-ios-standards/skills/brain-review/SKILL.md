---
name: brain-review
description: >-
  Use when performing the final consistency and architecture review of a completed iOS plan, or when
  the user explicitly requests an architecture audit or pre-merge review.
---

# Brain — Review

Review the final repository state and complete branch diff against the approved plan and Definition of
Done. Read:

- `${CLAUDE_PLUGIN_ROOT}/standards/brain/rulebook/19-architecture-review-checklist.md`
- `${CLAUDE_PLUGIN_ROOT}/standards/brain/rulebook/17-anti-patterns.md`
- `${CLAUDE_PLUGIN_ROOT}/standards/brain/rulebook/20-non-negotiable-rules.md`
- `${CLAUDE_PLUGIN_ROOT}/standards/process/lean-verification.md`

## One review event

Run once after the complete plan's final mutation. Parallel specialist lanes are allowed, but they
inspect the same final candidate and form one joined review event. Cover requirements/DoD,
architecture, Boardy+VIP, public APIs, terminology, cross-references, examples/templates, enterprise
chapters, migration, package metadata, and obsolete-tooling references.

Collect all findings non-fail-fast before remediation. Each finding contains severity, concrete
file/line evidence, affected rule or DoD item, and recommended disposition. Deduplicate by root cause
and return one joined list.

Apply accepted in-scope findings in one corrective batch. Do not run routine per-finding review,
confirmation review, or full re-review. If a correction would materially change scope, architecture,
public contract, or security posture, reopen planning and treat it as a new plan.

AI review checks consistency and judgment. It does not replace executable-code tests required by the
consuming project, and it does not require plugin-owned verifier/lint/smoke scripts, manifests,
fingerprints, receipts, or evidence ledgers.

When Boardy+VIP is bound, include the Boardy review checklist in the same final review event.
