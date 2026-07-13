# SPEC: Plan Execution Workflow

Canon remains the normative authority. For derived operating guidance, use
`${CLAUDE_PLUGIN_ROOT}/standards/process/lean-verification.md` for execution cadence and
`${CLAUDE_PLUGIN_ROOT}/standards/process/full-auto-operating-model.md` for mode eligibility, authority,
recovery/resume, frozen candidate identity, finding disposition, and the engineering-completion
boundary.

## Delivery contract

- Approve one complete plan for the objective.
- Execute dependency-ordered workstreams without intermediate review gates.
- Use tests only for executable code according to its behavior and risk; do not apply TDD to
  standards text, templates, metadata, or documentation-only schemas.
- Commit complete semantic tasks when separately authorized so history remains traceable.
- After the last planned Task commit, freeze exact baseline/HEAD SHAs and included/excluded paths, then
  run one AI consistency review over that complete candidate.
- Collect all findings first, apply accepted in-scope findings in one corrective batch, and do not
  schedule routine re-review.
- Leave CI and release automation to the consuming organization/DevOps boundary.
- Treat a material goal/scope/public-contract/architecture/security/authority correction as a new
  plan, not as another review loop.

Do not add plugin-owned verifier/lint/smoke scripts, per-checkpoint manifests, fingerprints, receipts,
or a custom workflow state engine. These belong to the post-1.0 tooling backlog.
