# IIS-0011 implementation plan

## Operating boundary

- Complete one documentation/standards plan, then one joined final AI review.
- Integration owner and sole shared-file writer: primary agent. Disjoint read-only audit lanes may
  advise but never mutate. Shared paths are serialized through the integration owner.
- Final technical finding-disposition authority comes from the user's retained auto-mode direction and
  scoped IIS-0011 approval. It covers only in-scope technical documentation/standards text. Release,
  organization sign-off, external operations, and user-owned residual-risk decisions remain external.
- Treat Q4/Q6 verification waiver as an explicit user-owned qualification decision, not an inferred
  green signal.
- Do not run builds/tests, inspect additional project configurations, invoke Claude rows again, or add
  tooling.
- Preserve frozen RC4 `f7cd2cf…`; payload edits in this plan form a later standards delta.

## Task 1 — Freeze inputs and approve the complete plan

**Outcome:** requirements/DoD, exact result identities, authority, candidate boundary, and all edit
paths receive independent Requirement and Plan gate decisions.

**Commit:** `docs: plan RC4 qualification closeout`

## Task 2 — Ingest direct qualification and transport results

**Outcome:** IIS-0009 records the corrected Claude CLI transport and final Q2/Q4/Q6 evidence; IIS-0010
records the deduplicated feedback state and promotion-readiness matrix.

**Allowed edit/staging paths:**

- `docs/02-working-docs/work-items/IIS-0009-rc4-claude-local-qualification/`:
  `CLAUDE-CLI-RUNBOOK.md`, `requirements.md`, `plan.md`, `review.md`, `qualification.md`,
  `qualification-claude.md`, `final-report.md`, `prompts/q4.md`, and `prompts/q6.md`;
- `docs/02-working-docs/work-items/IIS-0010-rc4-promotion-readiness/feedback-register.md` and
  `promotion-handoff.md`;
- this work item's `requirements.md`, `plan.md`, and new `qualification.md`.

- Record only bounded provider facts and semantic commit identities.
- Classify Q4/Q6 as passed under the explicit representative-signal waiver, with target-specific
  compilation/test risk retained.
- For each Q4/Q6 waiver, name the accepted retained Q3 native iOS signal, state that it does not prove
  Q4/Q6 target-specific compilation/test execution, record the direct-result commit identity and
  residual risk owner, and keep the pre-existing/nonstandard build-graph defect separate from RC4
  candidate defects.
- Remove `--setting-sources ""` from both runbook commands. State that operator settings may route the
  local model but cannot supply Standards authority.
- Retain Q1/Q3/Q5; do not rerun or manufacture another green signal.

**Commit:** `docs: close RC4 qualification matrix`

## Task 3 — Optimize Brain Flow verification scope

**Outcome:** Brain Flow requires a risk-selected representative/impacted configuration set, not every
configuration permutation.

**Allowed edit/staging paths:**

- `ifl-ios-standards/skills/brain-flow/SKILL.md`;
- `ifl-ios-standards/standards/process/lean-verification.md`;
- `ifl-ios-standards/standards/process/full-auto-operating-model.md`;
- `ifl-ios-standards/standards/brain/rulebook/C-verification-commands.md`;
- `ifl-ios-standards/RELEASE.md` for the matching qualification-selection boundary;
- this work item's `plan.md`.

- Put the normative selection rule in `standards/process/lean-verification.md`, which Brain Flow
  already loads.
- Add only the concise execution reminder needed in `skills/brain-flow/SKILL.md` and portable command
  guidance.
- Use observable expansion triggers: changed build logic, platform/toolchain behavior, policy or
  release risk, or a failure that proves the current representative set insufficient.
- iOS example: affected/common scheme, destination, package/build-system path. Android example:
  affected/common build type and product flavor. Do not create Android architecture requirements.
- Permit a nonstandard configuration waiver only when an accepted representative platform signal
  exists, the waived boundary and residual risk are recorded, and no P0/P1 evidence is hidden.

**Commit:** `docs: scope verification to representative configurations`

## Task 4 — Run one joined review and close the handoff

**Outcome:** one frozen review of the whole IIS-0011 result returns a deduplicated finding list and a
truthful release-readiness boundary.

- Freeze the post-Task-3 candidate identity and included paths; exclude unrelated `.superpowers/`.
- Record three distinct identities: (1) qualified frozen RC4 `f7cd2cf…`; (2) the exact post-Task-3
  review input with standards-worktree baseline, HEAD, included tracked paths, and excluded unrelated
  paths; and (3) the post-correction engineering-complete commit in the completion handoff. Q1-Q6
  qualification does not silently transfer from `f7…` to the post-freeze standards delta.
- Review requirements/DoD, matrix evidence, waiver wording, candidate identity, Brain Flow/portable
  consistency, transport truth, feedback, sign-offs, and external authority.
- Apply accepted in-scope findings once in one non-executable documentation/standards correction
  batch. A material goal, scope, public-contract, architecture, security, or authority change requires
  a new plan. Do not re-review.
- Write `review.md` and `final-report.md`; update DoD and task statuses.

**Allowed edit/staging paths:** every Task 2/3 path plus this work item's `requirements.md`, `plan.md`,
`qualification.md`, `review.md`, and `final-report.md`.

**Commit:** `docs: close RC4 qualification ingestion`

## Plan Gate

- Mode: auto
- Reviewer: independent read-only agent `iis0011_auto_gate`
- Initial verdict: `CHANGES_REQUIRED` for ownership/authority, exact paths, three identities, and
  correction-scope clarity.
- Retained amendment: applied once without changing goal, scope, or external authority.
- Final verdict: `AUTO_APPROVED`

STATUS: APPROVED — TASK 1 COMPLETE
