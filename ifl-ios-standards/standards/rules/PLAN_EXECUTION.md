# SPEC: Plan Execution Workflow

> **Superseded — single source of truth is the process standard.**
> Plan-execution cadence (TDD tiering, semantic checkpoints, evidence ownership, review economics) is
> defined by `${CLAUDE_PLUGIN_ROOT}/standards/process/lean-verification.md`. Read that. This file
> remains only as a stable routing target.

## TL;DR (full detail in lean-verification.md)

- **Tier affected behavior**: Tier 1 strict causal RED → GREEN; Tier 2 test-after inside the semantic
  checkpoint; Tier 3 no runtime test when the policy permits it.
- **Plan semantic checkpoints, not task-count checkpoints**: each outcome must be complete, independently
  valid/reviewable/rollbackable, and mapped to DoD. Keep coupled schema/generated/digest/migration
  cascades atomic; divide implementation into work slices. Independent outcomes MUST split when each
  can regenerate a valid boundary, even if they share a gate/reviewer/digest. Every exception passes
  all ordered rules and preserves atomic cascades.
- **Own each verification obligation once**: work-slice causal signal → accumulated checkpoint proof →
  checkpoint owning gate → declared wave/release owner. The plan records each signal/obligation set,
  their equality, and intended subsumption separately; evaluate subsumption before a lower run.
- **Review once per frozen fingerprint**: non-overlapping collect-all reviewers → deduplicate → one
  remediation batch → pending owning gate after final mutation → bounded confirmation. Findings carry
  stable lane/root-cause/obligation/evidence identity; the aggregator assigns canonical remediation
  IDs/dispositions and classifies intake-`ACCEPTED` findings before mutation. Only
  `ACCEPTED_CURRENT_SCOPE` (wire `accepted_current_scope`) enters remediation. Only the immutable
  post-join initial-register decision `DIRECT_CONVERGENCE_NO_ACCEPTED_CURRENT_SCOPE` skips remediation
  and confirmation; it never skips a still-pending checkpoint owning gate and is never inferred from
  incomplete inventories or later `resolved` state.
- **Use the full evidence contract**: `lean-verification.md` §7 is normative. Candidate fingerprint and
  append-only audit-ledger identity are distinct; the final staged manifest matches the reviewed and
  verified candidate fingerprint.
- **Commit by semantic checkpoint only when separately authorized**: a work slice, layer, file,
  generated artifact, or evidence artifact does not create a commit merely to reduce diff size.
  Plan/AUTO approval never grants Git authority. Post-commit wave correction captures all diagnostics,
  clusters root causes, applies one coordinated corrective set, and reruns the wave once; corrective
  commit/amend needs its own scoped authority.

For canonical verification scripts and project targets, see the consuming project's bindings.
