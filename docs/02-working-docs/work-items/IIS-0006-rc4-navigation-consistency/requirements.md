# Requirements — IIS-0006 RC4 navigation consistency

## Meta

- Created: 2026-07-14
- Flow mode: auto
- Delivery target: `1.0.0-rc.4` engineering-complete candidate
- Baseline: IIS-0005 closeout commit `7dcc5d8`
- Defective candidate: `1.0.0-rc.3` at
  `521c7a4ee939bb96f3f67a75050f71f5d13416a1`
- Branch/worktree: `codex/standards-1.0` in `/private/tmp/ifl-ios-pack-standards-v1`
- Change class: Boardy derived-guidance and candidate-metadata correction
- Verification owner: one joined AI consistency review; no build/test or TDD applies to this
  documentation-only change

## Authority and boundary

- The user authorized uninterrupted full-auto work toward the enterprise standard and scoped local
  stage/commit after each semantic task.
- This work item may correct the Standards payload and active candidate metadata locally. It does not
  authorize push, force-push, history rewrite, branch mutation, tag deletion/creation, publication,
  marketplace change, install, rollout, GA declaration, or organization risk acceptance.
- Canon Rules and accepted ADRs remain normative and unchanged. This is a correction of derived
  guidance, not a new navigation architecture decision.
- Current package content and all new work-item output remain adopter-brand-neutral. Historical remote
  references are outside this candidate correction and require separate destructive-history authority.
- No plugin-owned verifier, script, CI, kernel, receipt/evidence system, or release automation may be
  introduced.

## Trigger and disposition

IIS-0005 stopped RC3 after one joined Q3 rehearsal review found:

- **`F-RC3-QUAL-001` — P1 candidate defect:** several Boardy UI examples call
  `rootViewController.returnHere()` and describe a generic completion bus connected after `show()`.
  Canon `BRD-CTX-001`, ADR-0006, `CONTEXT_NAVIGATION.md`, and the targeted-return checklist require
  explicit current/destination ViewController context. The contradiction can drive incorrect return
  behavior and materially wrong conformance outcomes.
- **`F-RC3-QUAL-002` — P2 consistency defect:** lifecycle descriptions disagree on whether
  `watch(content:)` or bus connection comes first, and a Composable example exposes its element before
  connecting its return bus. The material invariant is one canonical pre-exposure sequence.

Per `RELEASE.md`, the P1 cannot be repaired inside the frozen RC3 qualification result. It requires an
incremented candidate and repetition of affected qualification rows.

## Goal

Produce an immutable `1.0.0-rc.4` candidate whose Boardy UI, bus, context-navigation, composable,
example, compact, and reviewer guidance all express one destination-safe navigation model and one
pre-exposure activation sequence, with no change to Canon/ADR obligations and no open P0/P1 after one
joined review.

## Product decisions

1. `rootViewController.show(_:sender:)` remains the dependency-free outward presentation default.
2. `backToPrevious()` targets the current ViewController; `returnHere()` targets the explicit
   destination/coordinator ViewController. Neither method is called on `rootViewController`.
3. Simple close/back and targeted flow return use purpose-named buses (`cancelBus`/`returnBus`). A
   generic `completeBus` must not hide which navigation destination owns the return.
4. Child boards emit typed output only. The destination/coordinator owns and transports its
   `returnBus` after child completion.
5. The canonical UI activation sequence is: build component → `watch(content:)` → connect buses to
   their concrete target → `putIntoContext` → expose through `show` or composer. Runtime transports
   occur only after connection.
6. Canon `BRD-CTX-001`, ADR-0006, Boardy Foundations, public IO, and Boardy source/distribution remain
   unchanged.
7. RC4 is unpublished. The public marketplace and install guidance remain pinned to published RC1;
   Q1-Q6 reset to not qualified against the new immutable candidate.

## In scope

- Correct the complete derived-guidance surface named by `F-RC3-QUAL-001`:
  `MICROBOARD_UI.md`, `EXAMPLES_VIP_BOARD.md`, `COMMUNICATION.md`, the compact Boardy cheatsheet,
  `BUS_PATTERNS.md`, and `REVIEWER_CHECKLIST.md`.
- Align `CONTEXT_NAVIGATION.md`, `COMPOSABLE_BOARD.md`, and the affected activation examples in
  `EXAMPLES_COMPOSABLE_BOARD.md` with the canonical pre-exposure sequence. Change only the coupled
  activation snippets; do not absorb unrelated example cleanup.
- Use purpose-named current/destination buses in examples and ensure wording distinguishes outward
  presentation root from navigation target.
- Bump active candidate metadata/status from unpublished RC3 to unpublished RC4, add a concise
  changelog entry, preserve historical RC3 records, and leave the public RC1 marketplace pin intact.
- Run one joined read-only AI consistency review over the complete correction. Apply all accepted
  in-scope findings in at most one corrective batch, without routine re-review.
- Record the immutable RC4 candidate SHA and qualification handoff in a later closeout-only commit.

## Out of scope

- Changing Canon rule/ADR meaning, Boardy source, public IO, package/build integration, or adding a
  new navigation abstraction.
- Executing provider qualification rows, adopter migration/build/test, or reusing RC3 rehearsal
  results as RC4 passes.
- Editing historical completed work items, old release snapshots, remote branches/tags, or unrelated
  files.
- Build/test/TDD for Markdown and metadata; scripted consistency checks; plugin validation; CI.
- Push, PR, merge, tag, publish, install/update, marketplace mutation, rollout, GA, or destructive Git
  history operations.

## Risks and controls

- **Semantic overcorrection:** keep root presentation and top-presented modal use valid; change only
  back/return targets and activation ordering.
- **Ambiguous generic skeleton:** use explicit simple-back and targeted-return examples instead of a
  bus name that hides destination semantics.
- **Derived-document drift:** edit the coupled guidance as one semantic batch and review it once as a
  complete set.
- **Version drift:** update all active candidate-status surfaces together; retain RC1 public pins and
  historical work items.
- **Process/tooling drift:** no new verifier, script, receipt, intermediate gate, build, or test.

## Definition of Done

- [x] **D1 — Return targets are unambiguous.** Every active Boardy example routes simple back to the
  current ViewController and targeted return to the explicit destination ViewController; no compliant
  example calls `rootViewController.returnHere()` or `rootViewController.backToPrevious()`.
- [x] **D2 — Lifecycle is coherent.** UI, context-navigation, bus, composable, compact, example, and
  reviewer guidance agree on build → watch → connect → put into context → expose, with purpose-named
  buses connected before any transport or UI exposure.
- [x] **D3 — Canon and contracts are preserved.** `BRD-CTX-001`, ADR-0006, other Canon records,
  Boardy source/distribution, public IO, and framework-neutral Core remain unchanged.
- [x] **D4 — RC4 metadata is truthful.** Active version/manifests/status/changelogs identify
  unpublished `1.0.0-rc.4`; public RC1 pins remain unchanged; Q1-Q6 are not qualified for RC4.
- [x] **D5 — Content boundary is safe.** New/current Standards output contains no adopter brand
  identity or protected source; historical/remote refs and `.superpowers/` remain untouched.
- [ ] **D6 — Review is conclusive and lean.** One frozen-range joined AI review has no open P0/P1
  after at most one corrective batch; no routine re-review, build/test, verifier, script, CI, or
  duplicate signal runs.
- [ ] **D7 — History is traceable.** Planning, implementation, review/candidate-freeze, and closeout
  are semantic commits using explicit paths; no external release or destructive Git effect occurs.

## Requirement gate

- Mode: auto
- Gate owner: independent AI reviewer
- Approval rubric:
  - The P1 trigger and canonical destination semantics are explicit without changing Canon.
  - The correction covers the full coupled derived surface and no unrelated architecture/tooling.
  - Version, brand, qualification, Git, and release boundaries are safe and observable.
  - DoD can be completed with one semantic implementation batch and one final joined review.
- Verdict: AUTO_APPROVED with retained amendment A
- Reviewer: independent combined gate agent `iis0006_combined_gate`
- Retained amendment A: include affected `EXAMPLES_COMPOSABLE_BOARD.md` activation snippets in the
  same pre-exposure-sequence correction; P0/P1/P2 after retention = `0/0/0`.
- Open material questions: none

STATUS: READY_FOR_JOINED_REVIEW
