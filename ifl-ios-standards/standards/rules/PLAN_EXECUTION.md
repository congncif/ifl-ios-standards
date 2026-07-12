# SPEC: Plan Execution Workflow

The normative cadence is defined by
`${CLAUDE_PLUGIN_ROOT}/standards/process/lean-verification.md`.

## Delivery contract

- Approve one complete plan for the objective.
- Execute dependency-ordered workstreams without intermediate review gates.
- Use tests only for executable code according to its behavior and risk; do not apply TDD to
  standards text, templates, metadata, or documentation-only schemas.
- Commit complete semantic tasks when separately authorized so history remains traceable.
- After all planned mutations, run one AI consistency review over the complete branch diff.
- Collect all findings first, apply accepted in-scope findings in one corrective batch, and do not
  schedule routine re-review.
- Leave CI and release automation to the consuming organization/DevOps boundary.

Do not add plugin-owned verifier/lint/smoke scripts, per-checkpoint manifests, fingerprints, receipts,
or a custom workflow state engine. These belong to the post-1.0 tooling backlog.
