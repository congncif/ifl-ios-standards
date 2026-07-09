---
name: brain-plan
description: >-
  Use when turning a design/architecture decision into an executable implementation plan —
  phasing tasks, placing verification at phase boundaries, sizing the change. Pattern-neutral:
  applies to any iOS project, Boardy or not. Triggers: "plan this feature", "break this into
  phases", "write the implementation plan", "how should we sequence this".
---

# Brain — Plan (phases, checkpoints, sequencing)

Pattern-neutral planning stage of the brain rulebook. Consumes the output of
`/ifl-ios-standards:brain-design` + `/ifl-ios-standards:brain-architect` when they ran first.

## Read
- `${CLAUDE_PLUGIN_ROOT}/standards/brain/rulebook/13-agentic-coding-rules.md` — local reasoning, read-before-write discipline.
- `${CLAUDE_PLUGIN_ROOT}/standards/brain/rulebook/18-decision-heuristics.md` — sizing/split heuristics.
- `${CLAUDE_PLUGIN_ROOT}/standards/rules/PLAN_EXECUTION.md` — plan format + execution contract.
- `${CLAUDE_PLUGIN_ROOT}/standards/process/lean-verification.md` — TDD tiers + checkpoint levels.
- `${CLAUDE_PLUGIN_ROOT}/standards/process/approval-modes.md` — co-working vs auto gate semantics.

## Plan shape
- Group tasks into **phases**; verification steps at **phase boundaries only** — not per task.
- Each phase maps back to one or more approved Definition of Done items; uncovered DoD items are blockers or explicit deferrals.
- Each phase names: files touched, the cheapest sufficient check (typecheck → targeted test → build), and its TDD tier per lean-verification.
- Full build + full suite exactly once, before reporting completion.
- Get plan approval before execution:
  - co-working mode → human/user approval;
  - auto mode → AI gate approval through configured reviewers/subagents;
  - always ask the user for material product/scope ambiguity, missing bindings, or blockers.

## Guardrails
- Smallest correct change per phase; no drive-by edits in the plan.
- A plan is executable only after the Plan Gate verdict is `USER_APPROVED` or `AUTO_APPROVED`.
- If a binding value (scheme, commands, module root) is missing from the project's `CLAUDE.md`, stop and ask — don't guess.

## Pattern hook
Project's `CLAUDE.md` binds Boardy+VIP → phase the work along Boardy seams (IO first, then Sources,
then Plugins) and reference the matching `boardy-*` skills per phase.
