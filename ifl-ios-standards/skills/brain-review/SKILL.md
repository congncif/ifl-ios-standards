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

## What to flag (highest-value first)
- Non-negotiable rule violations (chapter 20) — blocking, no exceptions without documented ADR.
- Dependency direction breaks, vendor types in contracts, domain impurity.
- New `public` surface without a named consumer; logic in view code.
- Drift from the approved requirement summary or approved implementation plan.
- Named anti-patterns from chapter 17 — cite the section in the finding.

## Triage
Blocking (rule break) → must fix. Should-fix (drift, naming, placement) → batch. Nit → optional.
In auto `brain-flow`, blocking findings loop back to Execute; material requirement/plan drift escalates to the relevant gate instead of being patched blindly.
State facts with file:line; no theater.

## Pattern hook
Project's `CLAUDE.md` binds Boardy+VIP → also run `/ifl-ios-standards:boardy-review`
(REVIEW_PLAYBOOK + REVIEWER_CHECKLIST + the 14 Boardy rules). For the delegated pipeline, the
`ios-reviewer` + `ios-review-triage` agents own this.
