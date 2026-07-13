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
- `${CLAUDE_PLUGIN_ROOT}/standards/process/full-auto-operating-model.md`

## One review event

Run once after the complete plan's final Task commit. Record the approved authority inputs, exact
baseline and candidate HEAD SHAs, included tracked paths, excluded unrelated paths, and writer freeze.
Review outputs/corrections are outside this input identity. Parallel specialist lanes inspect that
same candidate and form one joined review event. Cover requirements/DoD,
architecture, Boardy+VIP, public APIs, terminology, cross-references, examples/templates, enterprise
chapters, migration, package metadata, and obsolete-tooling references.

For a standalone audit with no implementation plan, freeze the user-requested snapshot/range and path
scope instead. Remain read-only unless remediation is separately requested and planned.

Collect all findings non-fail-fast before remediation. Each finding contains severity, concrete
file/line evidence, affected rule or DoD item, and recommended disposition. Deduplicate by root cause
and return one joined list.

Apply accepted in-scope P0/P1 findings in one corrective batch using the operating model's severity and
disposition ownership. In co-working “review with me” mode, include the user in disposition. Do not run
routine per-finding review, confirmation review, or full re-review. If a correction would materially
change goal, scope, architecture, public contract, security posture, or authority, reopen planning and
treat it as a new plan. If executable code changes in the batch, run only its smallest affected signal.

AI review checks consistency and judgment. It does not replace executable-code tests required by the
consuming project, and it does not require plugin-owned verifier/lint/smoke scripts, manifests,
fingerprints, receipts, or evidence ledgers.

When Boardy+VIP is bound, include the Boardy review checklist in the same final review event.
