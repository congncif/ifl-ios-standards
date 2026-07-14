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

For the delegated pipeline, Claude uses `ios-reviewer` + `ios-review-triage`; Codex uses the
spawn-safe equivalents `ios_reviewer` + `ios_review_triage`.

## Cadence inside Brain Flow

Apply this checklist inside the one joined final review event. Review the complete candidate and
collect every finding before editing. A large diff or a missing/failing project-owned executable
signal is a risk/finding, not a reason to stop the architecture review or create another gate. After
the joined disposition, use at most one corrective batch and no routine confirmation or re-review.
A correction that materially changes scope, architecture, a public contract, or security reopens
planning as a new plan rather than extending the review loop.
