# Plan — IIS-0006 RC4 navigation consistency

## Meta

- Created: 2026-07-14
- Mode: auto
- Requirements: `requirements.md` — `AUTO_APPROVED`
- Baseline: `7dcc5d8`
- Working candidate: `1.0.0-rc.4`
- Branch/worktree: `codex/standards-1.0` in `/private/tmp/ifl-ios-pack-standards-v1`
- Integration owner: primary agent; only this owner writes candidate files and this work item

## Execution strategy

- Gate the complete requirements and plan once, then commit them as one planning baseline.
- Execute one coupled documentation/metadata task. File groups are implementation slices, not review
  checkpoints; no review or verification runs between them.
- Stage only explicit paths and create one semantic implementation commit. Preserve `.superpowers/`
  and unrelated/historical files.
- Because no executable code changes, do not use TDD, build, test, provider calls, plugin validation,
  or a scripted consistency signal.
- Freeze planning-baseline-exclusive through implementation-commit-inclusive and run one joined
  read-only AI consistency review. Collect all findings once and apply accepted in-scope corrections
  in at most one batch; do not schedule routine re-review.
- The review/correction commit is the immutable RC4 qualification candidate. A later closeout-only
  commit records its SHA without changing plugin payload.
- Do not run Q1-Q6, publish, push, tag, install, mutate marketplace/configuration, or rewrite history.

## DoD ownership

| DoD | Owning task |
|---|---|
| D1-D5 | Task 1 — navigation guidance and RC4 metadata |
| D6 | Task 2 — one joined review and candidate freeze |
| D7 | Planning baseline and Tasks 1-3 |

## Planning baseline commit

After the combined auto gate approves both artifacts, stage only this work item's `requirements.md`
and `plan.md` and commit once with intent `docs: plan RC4 navigation consistency`.

## Task 1 — Align navigation guidance and identify RC4

**Outcome:** every active derived surface teaches one explicit destination-safe model and all active
candidate metadata identifies the same unpublished RC4 revision.

**Status:** COMPLETE

### Semantic implementation slices

1. **Core pattern:** update `MICROBOARD_UI.md`, `CONTEXT_NAVIGATION.md`, and `BUS_PATTERNS.md` so the
   generic UI path distinguishes current-screen cancel/back from coordinator targeted return and uses
   build → watch → connect → put into context → expose.
2. **Derived consumers:** align `EXAMPLES_VIP_BOARD.md`, `COMMUNICATION.md`, the compact Boardy
   cheatsheet, `REVIEWER_CHECKLIST.md`, `COMPOSABLE_BOARD.md`, and the affected activation snippets in
   `EXAMPLES_COMPOSABLE_BOARD.md` with the same target and ordering.
3. **Candidate identity:** bump active RC3 status/version surfaces to RC4, add the correction and
   qualification reset to changelogs, and preserve public RC1 pins.

These slices are executed continuously by the same writer and produce one Task-1 commit.

### Exact mutable-path allowlist

- `ifl-ios-standards/standards/specs/MICROBOARD_UI.md`
- `ifl-ios-standards/standards/specs/EXAMPLES_VIP_BOARD.md`
- `ifl-ios-standards/standards/specs/COMMUNICATION.md`
- `ifl-ios-standards/standards/specs/compact/BOARDY_CHEATSHEET.compact.md`
- `ifl-ios-standards/standards/specs/BUS_PATTERNS.md`
- `ifl-ios-standards/standards/specs/REVIEWER_CHECKLIST.md`
- `ifl-ios-standards/standards/specs/CONTEXT_NAVIGATION.md`
- `ifl-ios-standards/standards/specs/COMPOSABLE_BOARD.md`
- `ifl-ios-standards/standards/specs/EXAMPLES_COMPOSABLE_BOARD.md`
- `ifl-ios-standards/VERSION`
- `ifl-ios-standards/.claude-plugin/plugin.json`
- `ifl-ios-standards/.codex-plugin/plugin.json`
- `ifl-ios-standards/CHANGELOG.md`
- `README.md`
- `ifl-ios-standards/README.md`
- `ifl-ios-standards/RELEASE.md`
- `ifl-ios-standards/standards/GOVERNANCE.md`
- `ifl-ios-standards/standards/COMPATIBILITY.md`
- `ifl-ios-standards/standards/brain/CHANGELOG.md`
- `ifl-ios-standards/standards/templates/portable-claude/CHANGELOG.md`
- `DEPLOY.md`
- `ROADMAP.md`
- this work item's `requirements.md` and `plan.md`

Inspect-only: Canon/ADR files, `BOARDY_FOUNDATIONS.md`, public marketplace metadata, historical work
items, release tags, Boardy source, scripts, and `.superpowers/`. Any required mutation outside the
allowlist is a plan amendment, not an implicit expansion.

### Completion inspection

- Read the complete Task-1 diff once and confirm no active compliant example contains forbidden
  root-targeted back/return calls, all affected lifecycle text uses the canonical sequence, active
  metadata says RC4, and public RC1 pins are unchanged.
- This is author inspection, not a review gate or scripted verifier. Do not build/test or repeat a
  green signal for documentation-only work.

### Commit boundary

- Stage only changed paths from the allowlist plus Task-1 state in requirements/plan.
- Commit intent: `fix: align Boardy navigation guidance for RC4`.

### Observed completion

- The complete coupled guidance surface now uses concrete current/destination ViewController targets,
  source identity for View-originated back, typed-output-only child completion, and pre-exposure bus
  wiring. The only root-targeted back/return strings are explicit prohibited examples.
- Active candidate identity is `1.0.0-rc.4` in `VERSION` and both provider manifests; public
  marketplace source remains `v1.0.0-rc.1`; Q1-Q6 are explicitly not qualified for RC4.
- Current payload paths and filenames contain no protected adopter-brand string or local adopter
  identity. Canon/ADR, public marketplace metadata, historical refs, and `.superpowers/` are unchanged.
- Author inspection found no whitespace error or mutable-path escape. No build, test, verifier,
  provider call, CI, or duplicate green signal was run for this documentation/metadata task.

## Task 2 — Run one joined review and freeze the RC4 candidate

**Outcome:** the complete correction has one conclusive disposition and one immutable candidate SHA.

**Status:** COMPLETE

### Frozen input

- Authority: approved IIS-0006 requirements and plan in the planning-baseline commit.
- Review range: planning-baseline commit exclusive through exact Task-1 commit inclusive.
- Included: only changed allowlist paths.
- Excluded: `.superpowers/`, historical work items, raw provider data, unrelated history, and later
  review outputs.
- All writers stop before review begins.

### Joined review lanes

- Canon/ADR fidelity; explicit current/destination target semantics; no root-targeted back/return.
- Lifecycle ordering and agreement across full, compact, example, bus, composable, and reviewer
  surfaces.
- RC4 metadata, RC1 pin preservation, Q1-Q6 reset, adopter-brand/source protection, authority, and
  YAGNI/process conformance.

One independent AI event joins and deduplicates the lanes. Apply accepted in-scope P0/P1/P2 findings
in at most one corrective batch, record all dispositions in `review.md`, and do not run a routine
second review. A finding that changes architecture, Canon, security, release authority, or scope starts
a new plan.

### Observed joined review and disposition

- Independent reviewer `iis0006_joined_final_review` inspected frozen range `f910326..7ecc0c6` once,
  read-only, and collected `P0/P1/P2 = 0/2/1` without fail-fast behavior.
- Both P1 findings and the P2 finding were accepted: constrain Board-originated `Bus<Void>` to
  intentional fan-out/one-live-target cases and require typed identity for targeted concurrency;
  genericize one protected-brand status line; synchronize two compact-cheatsheet statements.
- All accepted findings were applied together to `BUS_PATTERNS.md`, `COMMUNICATION.md`, the compact
  Boardy cheatsheet, and this work item. No finding changed Canon, ADR, public contracts, security,
  authority, or approved scope; planning did not reopen.
- Post-disposition open `P0/P1/P2 = 0/0/0`. This status follows the exact accepted correction list;
  no routine re-review, build, test, verifier, script, CI, provider call, or duplicate signal ran.

### Candidate freeze and commit

- Mark D1-D6 and Task 2 truthfully.
- Commit `review.md`, accepted corrective allowlist files, and requirements/plan state.
- The resulting commit is the immutable RC4 qualification candidate.
- Commit intent: `docs: close RC4 navigation consistency review`.

## Task 3 — Record immutable RC4 identity

**Outcome:** a closeout record names the Task-2 candidate without changing its payload.

**Status:** PENDING

### Changes and boundary

- Read the exact Task-2 SHA after commit.
- Write `final-report.md` with DoD, planning/implementation/review commits, immutable RC4 candidate,
  unchanged public RC1, remaining Q1-Q6 not-qualified state, provider-policy hold, and next
  qualification boundary.
- Mark D7 and the plan complete. Do not edit candidate payload or qualification claims.
- Commit only this work item's `final-report.md`, `requirements.md`, and `plan.md` with intent
  `docs: record RC4 qualification candidate`.

## Plan gate

- Mode: auto
- Gate owner: independent AI reviewer
- Approval rubric:
  - Every DoD item has one semantic owner and observable boundary.
  - The full contradiction surface is corrected together without changing Canon or adding tooling.
  - Review cadence is one frozen event with at most one correction batch and no duplicate signal.
  - Version, brand, public pin, qualification, Git, and release boundaries are explicit.
- Verdict: AUTO_APPROVED with retained amendment A
- Reviewer: independent combined gate agent `iis0006_combined_gate`
- Retained amendment A: the active composable example joins the coupled lifecycle surface and exact
  allowlist; P0/P1/P2 after retention = `0/0/0`.
- Open material questions: none

STATUS: READY_FOR_TASK_3
