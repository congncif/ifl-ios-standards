---
name: boardy-review
description: >-
  Use when reviewing Boardy+VIP iOS code against the architecture standard — running the review
  procedure, triaging findings, or applying the exhaustive rule checklist. Triggers: "review this
  code", "check against Boardy rules", "architecture review", "PR review for the iOS standard".
---

# Code review — Boardy+VIP

## Read
- `${CLAUDE_PLUGIN_ROOT}/standards/specs/REVIEW_PLAYBOOK.md` — procedure, triage, comment templates (start here).
- `${CLAUDE_PLUGIN_ROOT}/standards/specs/REVIEWER_CHECKLIST.md` — exhaustive rule reference; work it section by section.
- `${CLAUDE_PLUGIN_ROOT}/standards/specs/compact/REVIEWER_COMPACT.md` if present (preferred — derived subset).

## What to flag (highest-value first)
- The 14 non-negotiable rules (see `/ifl-ios-standards:boardy-vip` §2).
- Visibility leaks: cross-module import of `{Name}Plugins`; non-`public` IO; logic in the View.
- BoardID strings not matching the `pub.mod.…` naming table.
- Buses: retrieved controller refs instead of buses; missing identity-filter on round-trips; double-`complete()`.

For the delegated pipeline, the `ios-reviewer` + `ios-review-triage` agents own this.
