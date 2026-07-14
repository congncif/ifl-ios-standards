# Plan — IIS-0008 RC4 targeted requalification

## Meta

- Created: 2026-07-14
- Mode: auto
- Requirements: `requirements.md`
- Immutable candidate: `f7cd2cf87711f1a757d2fbdec5be9be02ee69173`
- Integration owner: primary agent; one provider writer per isolated fixture

## Design decisions

- Treat repository Profile bindings as controlled qualification input. Q1 tests RC4 routing with an
  explicit `core`-only consumer instead of inferring a candidate defect from an unbound fixture.
- Retain the Q3 pass because candidate identity and Boardy fixture HEAD are unchanged.
- Treat Q5 as a fixture-test recovery. The provider may change only the failing test assertion seam;
  production, distribution, and transition artifacts remain frozen.
- Do not broaden IIS-0008 into candidate correction or Claude recovery. Either requires a different
  authority/state boundary and a new plan.
- Use outer-plan approval and one final joined review. Provider tasks do not create nested gates or
  reviews.

## Task 1 — Approve plan and prepare guarded baselines

**Outcome:** exact RC4, explicit Q1 `core` binding, frozen Q5 scope, and independent provider state.

**Status:** IN PROGRESS

- Obtain one independent combined requirements/plan auto gate.
- Commit only the approved IIS-0008 requirements/plan.
- Create a new Q1 fixture from exact clean baseline `7871194…`; add minimal identical root bindings,
  confirm no Boardy dependency/source, initialize its new baseline commit, and keep it clean.
- Confirm Q5 starts clean at `3cbf36c…`; record frozen production/CocoaPods paths.
- Prepare separate Full Access Codex state for Q1 and Q5 using the candidate-only marketplace and
  exact RC4 extraction. Do not probe Claude.

**Commit:** `docs: plan RC4 targeted requalification`

## Task 2 — Requalify Q1 Core-only routing

**Outcome:** controlled evidence distinguishes a passing Core-only route from a reproducible routing
failure.

**Status:** PENDING

- Start one fresh provider session on the bound clean Q1 baseline and invoke RC4 Brain Flow.
- Execute the approved delivery-policy task without nested plan/review gates.
- Freeze loaded skills, semantic fixture commits, one final `swift test` result, worktree status, and
  release-authority behavior.
- Stop after the result. Never use a third Q1 attempt in this plan.
- Write `qualification-q1.md` and update only Q1/DoD/task status.

**Commit:** `docs: record RC4 Q1 targeted requalification`

## Task 3 — Requalify Q5 fixture signal

**Outcome:** the known optional-date test seam is corrected once and the package test result is
observed.

**Status:** PENDING

- Start one fresh provider session at Q5 HEAD `3cbf36c…` and invoke RC4 Brain Flow.
- Change only the failing test assertion seam; commit it semantically.
- Run one final `swift test --package-path submodules/SharedPreferences` signal.
- Confirm production source, transition records, neutral Podfile, and podspec are unchanged; record
  organization-policy boundaries without accepting them.
- Write `qualification-q5.md` and update only Q5/DoD/task status.

**Commit:** `docs: record RC4 Q5 targeted requalification`

## Task 4 — One joined review and matrix closeout

**Outcome:** one deduplicated retained/new matrix and the next accountable boundary.

**Status:** PENDING

- Freeze Task-1/2/3 commits and exact fixture identities after both provider writers stop.
- Run one joined independent AI review over Q1/Q5 new evidence, retained Q3, Claude external holds,
  candidate attribution, cadence, security, and authority.
- Apply at most one reporting-only correction batch; no provider/test/review rerun.
- Write `review.md`, `qualification.md`, and `final-report.md`; complete DoD/task statuses.
- Keep release status `NOT QUALIFIED` while any mandatory row is unpassed. No external release action
  follows from this plan.

**Commit:** `docs: close RC4 targeted requalification`

## Plan Gate

- Mode: auto
- Reviewer: independent agent `iis0007_qualification_map`, reassigned as IIS-0008 combined gate
- Rubric: causal isolation, exact candidate, Q1 binding validity, Q5 change minimization, one-signal/
  one-review cadence, retained-result validity, semantic commits, and external boundary
- Verdict: AUTO_APPROVED — no P0/P1

STATUS: APPROVED
