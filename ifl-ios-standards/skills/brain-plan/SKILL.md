---
name: brain-plan
description: >-
  Use when turning a design/architecture decision into an executable implementation plan —
  defining semantic checkpoints, work slices, verification ownership, and sequencing. Pattern-neutral:
  applies to any iOS project, Boardy or not. Triggers: "plan this feature", "break this into
  phases", "write the implementation plan", "how should we sequence this".
---

# Brain — Plan (semantic checkpoints, work slices, sequencing)

Pattern-neutral planning stage of the brain rulebook. Consumes the output of
`/ifl-ios-standards:brain-design` + `/ifl-ios-standards:brain-architect` when they ran first.

## Read
- `${CLAUDE_PLUGIN_ROOT}/standards/brain/rulebook/13-agentic-coding-rules.md` — local reasoning, read-before-write discipline.
- `${CLAUDE_PLUGIN_ROOT}/standards/brain/rulebook/18-decision-heuristics.md` — sizing/split heuristics.
- `${CLAUDE_PLUGIN_ROOT}/standards/rules/PLAN_EXECUTION.md` — plan format + execution contract.
- `${CLAUDE_PLUGIN_ROOT}/standards/process/lean-verification.md` — TDD tiers + checkpoint economics and evidence ownership.
- `${CLAUDE_PLUGIN_ROOT}/standards/process/approval-modes.md` — co-working vs auto gate semantics.

## Plan shape

- Use **phases/waves** only as sequencing containers. Inside them, group work into **semantic
  checkpoints**: complete domain invariants, user-story outcomes, or DoD outcomes that are
  independently valid, reviewable, and rollbackable.
- Divide a checkpoint into **work slices** small enough for causal implementation signals. A slice is
  not automatically a review, commit, approval, or full-gate boundary.
- Map every checkpoint to approved Definition of Done obligations; uncovered obligations are blockers
  or explicit deferrals.
- For every checkpoint, declare: semantic outcome; atomic cascade/exact scope; work slices and TDD
  tiers; validity/rollback boundary; impact/reviewer coverage and review budget; review-readiness proof
  (ID, command/selector, minimum causal/static/schema obligations); accumulated focused signal (ID,
  command/selector, obligations); checkpoint owning gate (ID, command/selector, complete obligations);
  owning-gate timing `POST_JOIN_DEFAULT` or justified `PRE_REVIEW_REQUIRED`; whether the focused signal
  and owner are exactly `EQUAL` or `DISTINCT`; higher wave/release owner (ID, schedule, complete
  obligations); intended prospective subsumption; the complete normative evidence record from
  `lean-verification.md` §7; Product RED return policy; capability/preflight failure policy;
  post-commit wave/release failure-set policy; and commit boundary plus separate scoped Git-authority
  reference or `NONE`.
- Choose boundaries by semantic completeness → validity → rollback → coherent impact/ownership, using
  cognitive size only as a tie-breaker. Independent semantic outcomes MUST split when each can produce
  a complete valid/rollbackable state, even if they share a gate, reviewer, tool, or digest. Never split
  merely by file, LOC, layer, or task count.
- Keep schema/wire, fixture, generated, digest/provenance, migration/compatibility, and verifier
  artifacts together when they jointly establish one canonical invariant.
- If an indivisible cascade exceeds review capacity, include its split-minimality proof and compensate
  with smaller causal slices, non-overlapping risk lanes, deterministic artifact checks, or more
  reviewer capacity; never create an invalid boundary to meet a review budget.
- Default to one verified/reviewed commit per semantic checkpoint when separately authorized. Every
  checkpoint/commit exception must pass all ordered boundary rules and preserve atomic cascades.
  Plan/AUTO approval never grants Git authority.
- Declare one owner for each expensive full-suite/build/integration obligation. A scheduled higher gate
  may subsume a lower gate only under `lean-verification.md`; evaluate it before the lower gate would
  run, otherwise both remain explicit.
- Default to `POST_JOIN_DEFAULT`: freeze after review-readiness proof, join collect-all review, apply at
  most one remediation batch, then run an equal focused/owning command once on the final fingerprint.
  Use `PRE_REVIEW_REQUIRED` only when an observable meaningful-review or prior human/effect prerequisite
  is recorded; reviewer preference for a green candidate is not sufficient.
- Get plan approval before execution:
  - co-working mode → human/user approval;
  - auto mode → AI gate approval through configured reviewers/subagents;
  - always ask the user for material product/scope ambiguity, missing bindings, or blockers.

## Guardrails
- Smallest correct semantic checkpoint, with causal work slices; no drive-by edits in the plan.
- A plan is executable only after the Plan Gate verdict is `USER_APPROVED` or `AUTO_APPROVED`.
- Treat `lean-verification.md` §7 as the complete evidence schema: candidate fingerprint and append-only
  audit-ledger identity are separate, and no consumer may omit normative fields.
- A post-commit wave-failure policy must capture all diagnostics before mutation, cluster root causes
  by checkpoint, coordinate the corrective set, and name a single wave rerun. Corrective commit/amend
  authority is separate and explicit; amend may target only a preauthorized unshared commit.
- Product RED and capability/preflight failures must have separate declared returns; infrastructure
  failure never satisfies behavioral RED or justifies blind product mutation/rerun.
- If a binding value (scheme, commands, module root) is missing from the project's `CLAUDE.md`, stop and ask — don't guess.

## Pattern hook
Project's `CLAUDE.md` binds Boardy+VIP → sequence work along Boardy seams (IO first, then Sources,
then Plugins) and reference the matching `boardy-*` skills. Do not turn each seam into a checkpoint
unless it independently passes the semantic, validity, and rollback rules.
