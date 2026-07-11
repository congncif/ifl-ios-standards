---
name: brain-execute
description: >-
  Use when implementing an approved plan or making a code change — the 6-step operating loop,
  smallest correct change, real verification signal. Pattern-neutral: applies to any iOS project,
  Boardy or not. Triggers: "implement this", "execute the plan", "make the change", "code it up".
---

# Brain — Execute (operating loop, verify, report)

Pattern-neutral execution stage of the brain rulebook. Runs an approved plan from
`/ifl-ios-standards:brain-plan`; there is no planless small-change bypass. In `brain-flow`, an approved
plan means `USER_APPROVED` in co-working mode or `AUTO_APPROVED` in auto mode.

## Read
- `${CLAUDE_PLUGIN_ROOT}/standards/brain/QUICK_REF.md` — §1 operating loop, §2 the 10 hard rules, §4 pre-completion self-review.
- `${CLAUDE_PLUGIN_ROOT}/standards/brain/rulebook/13-agentic-coding-rules.md` — read-before-write, local reasoning.
- `${CLAUDE_PLUGIN_ROOT}/standards/brain/rulebook/C-verification-commands.md` — canonical verification commands (resolve actual values from project bindings).
- `${CLAUDE_PLUGIN_ROOT}/standards/process/lean-verification.md` — work-slice signals, semantic checkpoint cadence, evidence reuse, and gate ownership.

## The loop (every work slice)
1. **Understand** → 2. **Locate** → 3. **Preserve** → 4. **Implement** → 5. **Causal proof** → 6. **Record**.
The approved Definition of Done is the loop goal: keep iterating until each item is completed,
explicitly deferred, or blocked with a reason.
Skipping understanding → noise. Skipping verification → lies. Empty output ≠ success.

A work slice is an implementation unit inside an approved semantic checkpoint. Run the cheapest
causal signal for its changed behavior; Tier 1 must observe a behavioral RED → GREEN. Do not create a
review, commit, user approval, full build, or full-suite cycle merely because a slice ended.

## Semantic checkpoint boundary

1. After the last planned slice, prospectively subsume or run the accumulated focused proof, then
   freeze one candidate fingerprint.
2. Hand that immutable baseline to the declared collect-all reviewers. Do not mutate while findings
   are still being gathered.
3. Join findings through the aggregator: retain stable lane/finding IDs, root-cause key, severity,
   obligation, evidence, and symptoms; use canonical remediation IDs and dispositions.
4. Before mutation, classify each intake-`ACCEPTED` finding's materiality. Scope/contract divergence
   reopens Requirement, Design, or Architecture as appropriate; owner/boundary/obligation/gate
   divergence reopens Plan. Only findings classified `ACCEPTED_CURRENT_SCOPE` on the current approved
   baseline enter its batch.
5. Add causal regression tests only for behavioral defects at their applicable tier. For mechanical,
   generated, schema, lint, or docs findings, use static/lint/schema/digest proof or Tier 3 as applicable.
6. After the final mutation, run the affected focused proof and the pending checkpoint owning gate.
   Evaluate any higher-gate subsumption before the lower gate would run; never apply it retroactively.
7. Recompute the candidate fingerprint and immutable versioned manifest/diff after that final mutation
   and owning proof, before issuing confirmation assignments.
8. Confirm accepted dispositions and changed surfaces only. Any material finding observed during
   confirmation reopens the appropriate gate, even outside the changed or assigned surface.
9. Commit once only when the final staged manifest byte-matches the candidate fingerprint referenced
   by owning-gate and final-review evidence **and** separate explicit Git authority covers this commit.
   Plan/AUTO approval never supplies Git authority. A byte-identical commit does not require another
   gate run.

If the authoritative post-join initial-register decision is
`DIRECT_CONVERGENCE_NO_ACCEPTED_CURRENT_SCOPE`, skip remediation and confirmation only; do not infer
that path before the join or after accepted findings become `resolved`. Do not skip a pending checkpoint
owning gate unless it equals the accumulated focused proof or was prospectively subsumed.
Apply the complete normative evidence contract in `lean-verification.md` §7: a candidate fingerprint
identifies evaluated content/context, while each attempt/disposition gets a distinct append-only audit
identity. Any relevant mutation to the declared closure invalidates affected evidence and requires a
new candidate fingerprint.

## Post-commit wave failure

Before any corrective mutation, capture the failed wave's complete diagnostics and cluster symptoms by
root cause and affected checkpoint. Plan one coordinated corrective set, preserving mandatory splits
for independent outcomes; execute its focused/checkpoint proofs after the final mutation, then rerun
the failed wave once. Default to a separately traceable corrective checkpoint commit. Commit/amend
requires explicit corrective Git authority; amend only the exact preauthorized unshared commit.

## Guardrails
- Execute only an approved plan. If the plan gate verdict is missing, `CHANGES_REQUIRED`, `USER_INPUT_REQUIRED`, or `BLOCKED`, stop and escalate instead of coding.
- Smallest correct change. No drive-by edits, no speculative abstraction (hard rule 8).
- Preserve naming, layering, dependency direction, access modifiers of surrounding code.
- Keep atomic cascades and coupled rollback states inside one semantic checkpoint even when they need
  many slices or reviewers.
- Independent semantic outcomes stay separate when each boundary can regenerate a valid state. Every
  boundary exception must pass the ordered rules and preserve atomic cascades.
- Verify with real signals at their declared owners; do not multiply gates on an unchanged fingerprint.
- Without scoped commit authority, stop before the commit operation and report the verified candidate;
  do not invent a status or infer authority from plan approval.
- Run the §4 pre-completion self-review and report the final status of every Definition of Done item before claiming done.

## Pattern hook
Project's `CLAUDE.md` binds Boardy+VIP → load the matching task skill for the change at hand:
`/ifl-ios-standards:boardy-new-module`, `:boardy-new-board`, `:boardy-io-interface`,
`:boardy-communication`, `:boardy-service-layer`, `:boardy-plugin-composition`.
