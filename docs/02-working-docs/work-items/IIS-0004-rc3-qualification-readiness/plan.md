# Plan — IIS-0004 RC3 qualification readiness

## Meta

- Created: 2026-07-14
- Mode: auto
- Requirements: `requirements.md` — `AUTO_APPROVED`
- Baseline: RC2 engineering-complete commit `9a300f246b938337f767f1f826a353b6f71eeb3d`
- Working candidate: `1.0.0-rc.3`
- Execution branch/worktree: `codex/standards-1.0` in `/private/tmp/ifl-ios-pack-standards-v1`
- Integration owner: primary agent; only this owner updates requirements, plan, candidate metadata,
  joined-review record, or final report.

## Execution strategy

- Commit the approved requirements and plan once as the planning baseline.
- Execute one complete semantic implementation task. Do not split the init correction from its
  truthful candidate metadata or add per-file checkpoints.
- Stage only explicit paths and commit once after the complete task under the existing scoped local
  stage/commit authority. Preserve `.superpowers/` and all unrelated files.
- Treat `ifl-init` as executable work after the retained amendment identified its stale placeholder
  mapping. Use one focused generated-output event covering the three affected build-system branches;
  do not add a verifier, test harness, product build, or repeated signal.
- Freeze the exact planning-baseline-to-Task-1 range and run one joined read-only AI consistency
  review. Apply all accepted in-scope P0/P1 corrections in at most one Task-2 batch and do not run a
  routine second review. Task 2 creates the immutable qualification-candidate commit.
- After Task 2, use one closeout-only documentation commit to record the already-observed Task-2 SHA.
  That later reporting HEAD is not the candidate and IIS-0005 must qualify the exact Task-2 SHA.
- Q1-Q6 provider sessions, adopter changes/builds, push, tag, publish, marketplace mutation, install,
  rollout, and GA remain outside this corrective plan.

## DoD coverage

| DoD | Owning task |
|---|---|
| D1-D4 | Task 1 — Profile-neutral init and honest RC3 metadata |
| D5 | Task 2 — One joined review and immutable candidate freeze |
| D6 | Planning baseline and Tasks 1-3 |

## Planning baseline commit

After the Plan Gate is approved, stage and commit only this work item's `requirements.md` and
`plan.md`. This is one semantic planning commit and triggers no build, test, qualification, or review.

## Task 1 — Make project initialization Profile-neutral and identify RC3 truthfully

**Outcome:** every supported init surface keeps Core-only projects pattern-neutral, while all active
candidate metadata identifies the same unpublished RC3 revision and keeps public RC1 unchanged.

**Status:** COMPLETE

**Focused executable signal:** `bash -n` passed. One generated-output event exercised minimal
SwiftPM, CocoaPods, and Bazel fixtures; all three emitted identical CLAUDE/AGENTS twins, populated the
current `{BuildSystem}`/`{BuildIntegration}` contract, retained governed unknowns, routed generally to
Brain Flow, and kept every Boardy mention conditional. No product build/test or repeated signal ran.

### Changes

- Update `skills/init/SKILL.md` so its description, title, intake, Profile selection, confirmation,
  and next-step routing adopt Standards Core by default; route to `brain-flow` generally,
  `enterprise-ios` only for applicable governed concerns, and `boardy-adopt` only when Boardy/VIP is
  selected.
- Inspect `bin/ifl-init`, the bundled portable starter twins, active indexes/readmes, and generated
  bindings as one surface. Update the helper's stale output-token mapping; change no starter or index
  file unless it contains a default Boardy selection or recommendation.
- Change `bin/ifl-init` to substitute `{BuildSystem}` and `{BuildIntegration}` from its existing
  unambiguous Bazel/CocoaPods/SwiftPM detection. Do not infer target patterns, source globs, commands,
  destinations, policy owners, or other governed bindings.
- Bump `VERSION` and both provider manifests to `1.0.0-rc.3`.
- Add an RC3 changelog entry that records the P1 correction and qualification reset; retain RC2 as
  immutable history rather than rewriting its entry.
- Update active root/plugin README, release, governance, compatibility, deployment, roadmap, Brain
  changelog, portable-template changelog, and installation status wording only where they identify
  the current unpublished candidate as RC2. Prefer revision-neutral wording for reusable process
  rules and examples, while exact status fields name RC3.
- Preserve `.codex-plugin/marketplace.json` on published `v1.0.0-rc.1`; do not create or reference a
  nonexistent public RC3 tag as install guidance.
- Mark D1-D4 and Task 1 complete only after the focused output signal and metadata inspection agree.

### Exact mutable-path allowlist

Task 1 may modify only these paths:

- `ifl-ios-standards/skills/init/SKILL.md`
- `ifl-ios-standards/bin/ifl-init`
- `ifl-ios-standards/VERSION`
- `ifl-ios-standards/.claude-plugin/plugin.json`
- `ifl-ios-standards/.codex-plugin/plugin.json`
- `ifl-ios-standards/CHANGELOG.md`
- `README.md`
- `ifl-ios-standards/README.md`
- `ifl-ios-standards/RELEASE.md`
- `ifl-ios-standards/INSTALL.md`
- `ifl-ios-standards/standards/GOVERNANCE.md`
- `ifl-ios-standards/standards/COMPATIBILITY.md`
- `ifl-ios-standards/standards/brain/CHANGELOG.md`
- `ifl-ios-standards/standards/templates/portable-claude/CHANGELOG.md`
- `DEPLOY.md`
- `ROADMAP.md`
- this work item's `requirements.md` and `plan.md`

Both portable starter twins, Boardy routing/index files, and
`.codex-plugin/marketplace.json` are inspect-only under this plan because the pre-plan audit found no
default Boardy selection in them. Any newly discovered required mutation outside
the allowlist is a plan amendment, not an implicit expansion.

### Bounded signal

- Run one focused signal event: `bash -n` once, then `ifl-init` once against each of three temporary
  minimal Core-only fixtures representing SwiftPM, CocoaPods, and Bazel.
- Observe that every generated `CLAUDE.md`/`AGENTS.md` pair is identical, each fixture emits its
  detected `{BuildSystem}` and `{BuildIntegration}` values, governed unknowns remain placeholders,
  Brain Flow is the general route, and every Boardy mention is explicitly conditional rather than a
  selected/default next step.
- Inspect candidate-version fields and the unchanged public marketplace ref once. No build, test,
  plugin validation, provider model run, or repeated signal.

### Commit boundary

- Explicit paths: changed init skill and active RC3 metadata/status documents, plus this work item's
  requirements/plan task state.
- Commit intent: `fix: make project init profile-neutral for RC3`.

## Task 2 — Run one joined review and freeze the RC3 qualification candidate

**Outcome:** the correction has one conclusive independent review, one bounded disposition event, and
one immutable Task-2 commit for the separate field-qualification work item.

**Status:** PENDING

### Review input

- Authority inputs: approved `requirements.md` and `plan.md` in the planning-baseline commit.
- Frozen range: planning-baseline SHA exclusive through exact Task-1 HEAD inclusive.
- Included paths: only the explicit tracked paths changed by Task 1.
- Excluded paths: `.superpowers/`, historical work items, and unrelated/untracked files.
- All writers stop before reviewers start. Review outputs and any accepted corrective batch are not
  part of the frozen input range.

### Joined review lanes

- Core/Profile selection, init skill, helper/template/generated-output agreement, and Q1/Q3 support
  boundary.
- RC3 version/status consistency, RC1 marketplace preservation, release authority, and qualification
  reset semantics.
- Scope/YAGNI, unchanged Canon/ADR/Q1-Q6 obligations, no hidden tooling/build integration, and
  explicit-path Git history.

The integration owner joins and deduplicates all findings once, records severity and disposition,
and applies all accepted in-scope P0/P1 corrections in at most one batch. Any finding requiring a new
architecture, support, security, authority, or qualification decision starts a new approved plan;
it is not absorbed here. No routine second review is scheduled.

### Artifacts and candidate freeze

- Write `review.md` with exact input SHAs/path boundary, joined findings, dispositions, and the Task-1
  output signal.
- Complete D5 and the candidate-related portion of D6 from the joined disposition.
- Commit the review record, accepted corrective files, and requirement/plan state. The resulting
  commit is the immutable RC3 qualification candidate and is reported externally immediately after
  commit; it cannot embed its own SHA.

### Commit boundary

- Explicit paths: accepted corrective files only within Task 1's allowlist, `review.md`,
  `requirements.md`, and `plan.md`.
- Commit intent: `docs: close RC3 qualification-readiness review`.

## Task 3 — Record the immutable candidate identity and qualification handoff

**Outcome:** repository history contains a concise closeout record that names the already-created
Task-2 SHA without changing the candidate being qualified.

**Status:** PENDING

### Changes

- Read the exact Task-2 commit SHA after that commit succeeds.
- Write `final-report.md` with DoD status, planning/implementation/review commits, the exact Task-2
  candidate SHA, unchanged public RC1 baseline, remaining `not qualified` Q1-Q6 state, and the IIS-0005
  boundary.
- State explicitly that IIS-0005 qualifies the Task-2 SHA, not this later reporting commit/HEAD.
- Mark Task 3, D6, and this corrective plan complete. Do not change any plugin payload, candidate
  metadata, qualification claim, or review disposition.

### Bounded checks

- Compare the SHA written in `final-report.md` once with `git rev-parse <Task-2 commit>` and inspect
  that Task 3 changes only closeout work-item documents. No build, test, review, or qualification.

### Commit boundary

- Exact paths: this work item's `final-report.md`, `requirements.md`, and `plan.md` only.
- Commit intent: `docs: record RC3 qualification candidate`.

## Plan Gate

- Mode: auto
- Gate owner: independent AI reviewer who did not author this plan
- Approval rubric:
  - Every approved DoD item has one owning task and an observable completion signal.
  - The semantic boundary is large enough to avoid repeated loops and narrow enough for coherent
    commits and one final review.
  - Review-input identity, writer ownership, candidate identity, and external authority are explicit.
  - The immutable candidate SHA can be recorded without self-reference, and qualification is bound to
    that SHA rather than a later reporting commit.
  - No task weakens qualification, modifies Boardy distribution, rebuilds tooling/CI, or touches
    adopter/unrelated files.
  - The plan can execute continuously without routine human approval.
- Verdict: AUTO_APPROVED
- Reviewer: independent Plan Gate agent (`iis0004_plan_gate`)
- Findings resolved:
  - Added an exact Task-1 mutable-path allowlist and made every other audited surface inspect-only.
  - Made Task 2 the immutable candidate-freeze commit and Task 3 the later closeout record, with
    IIS-0005 bound to Task 2 rather than reporting HEAD.
- Retained amendment:
  - Reclassified the observed stale helper/template token mapping as executable P1
    `F-RC2-QUAL-002`, added `bin/ifl-init` to the exact allowlist, and bounded one three-branch
    generated-output signal.
  - Verdict: AUTO_APPROVED by independent agent `iis0004_amendment_gate_fast`; no P0/P1/P2 remained.
- Open material questions: none

STATUS: READY_FOR_EXECUTION
