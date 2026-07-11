---
name: brain-review
description: >-
  Use when reviewing or auditing code against the architecture rulebook — pre-merge review,
  anti-pattern lookup, non-negotiable rule check. Pattern-neutral: applies to any iOS project,
  Boardy or not. Triggers: "review this against the rulebook", "architecture audit", "is this
  an anti-pattern", "pre-merge check".
---

# Brain — Review (checklist, anti-patterns, non-negotiables)

Pattern-neutral review stage of the brain rulebook.

## Read
- `${CLAUDE_PLUGIN_ROOT}/standards/brain/rulebook/19-architecture-review-checklist.md` — work it section by section.
- `${CLAUDE_PLUGIN_ROOT}/standards/brain/rulebook/17-anti-patterns.md` — known bad patterns to flag by name.
- `${CLAUDE_PLUGIN_ROOT}/standards/brain/rulebook/20-non-negotiable-rules.md` — violations here are always blocking.
- `${CLAUDE_PLUGIN_ROOT}/standards/process/lean-verification.md` — collect-all lanes, finding identity, aggregation, and confirmation contract.

## What to flag (highest-value first)
- Non-negotiable rule violations (chapter 20) — blocking, no exceptions without documented ADR.
- Dependency direction breaks, vendor types in contracts, domain impurity.
- New `public` surface without a named consumer; logic in view code.
- Drift from the approved requirement summary, Definition of Done, or approved implementation plan.
- Named anti-patterns from chapter 17 — cite the section in the finding.

## Collect-all lane contract

- Review only the assigned non-overlapping risk/obligation lane against one frozen candidate
  fingerprint. Collect all findings non-fail-fast; do not mutate while lanes are open.
- Emit for every finding: stable lane ID, lane-local finding ID, root-cause key, severity, mapped
  obligation, concrete evidence, and all observed symptoms. State facts with file:line; no theater.
- Return lane findings to the aggregator. The aggregator—not the lane—deduplicates root causes, assigns
  canonical remediation IDs, and records `ACCEPTED`, `DEFERRED`, `REJECTED`, or
  `DUPLICATE_OF:<remediation-id>`. It applies the Plan's root-cause grammar and alias vocabulary before
  grouping, records provisional aliases, and never merges uncertain equivalence by guesswork.
- Classify accepted-finding materiality before any mutation. Scope/contract divergence reopens the
  appropriate Requirement/Design/Architecture gate; owner/boundary/obligation/gate divergence reopens
  Plan. Only accepted in-scope findings proceed to the one remediation batch.
- Blocking rule breaks remain blocking; should-fix findings are dispositioned for the batch; nits are
  optional. This review skill is a collect-all lane and MUST NOT directly loop to Execute.
- Confirmation verifies canonical dispositions and changed surfaces only. Any material finding
  observed during confirmation reopens the appropriate upstream gate, regardless of whether it is
  inside or outside the changed/assigned surface.

Behavioral accepted defects require causal regression proof at the applicable tier. Mechanical,
generated, schema, lint, and docs defects use static/lint/schema/digest proof or Tier 3 as applicable;
do not demand a fake behavioral regression test.

## Pattern hook
Project's `CLAUDE.md` binds Boardy+VIP → also run `/ifl-ios-standards:boardy-review`
(REVIEW_PLAYBOOK + REVIEWER_CHECKLIST + the 14 Boardy rules). For the delegated pipeline, the
`ios-reviewer` + `ios-review-triage` agents own this.
