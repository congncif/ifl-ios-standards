# Plan — IIS-0005 RC3 field qualification

## Meta

- Created: 2026-07-14
- Mode: auto
- Requirements: `requirements.md` — `AUTO_APPROVED`
- Immutable qualification candidate: `521c7a4ee939bb96f3f67a75050f71f5d13416a1`
- Reporting HEAD at intake: `da52e65` (not the candidate)
- Execution branch/worktree: `codex/standards-1.0` in
  `/private/tmp/ifl-ios-pack-standards-v1`
- Integration owner: primary agent; provider sessions are the only writers in their isolated fixture
  while active, and only the integration owner writes this work item.

## Execution strategy

- Commit the approved requirements and plan once as the planning baseline.
- Extract the candidate from the exact immutable SHA into a guarded temporary directory. Each provider
  session must exclude installed RC1, reporting HEAD, and non-candidate plugin/settings payloads; an
  unverifiable load is a truthful `not qualified`, never a silent fallback.
- Create all qualification hosts outside live adopter repositories from immutable baselines. Use
  shared/sparse local clones for the representative enterprise adopter to stay within disk limits
  and commit the constructed Q2
  `0.18.4` baseline before loading RC3.
- Execute the three Codex rows as one semantic batch and the three Claude rows as a second semantic
  batch. Each row is a provider-native end-to-end flow, not a scripted simulation. Keep one writer per
  fixture, one final focused executable signal when code changed, and semantic fixture commits.
- Sanitize observations directly into two ordinary Markdown group reports. Do not retain credentials,
  raw transcripts, protected source, receipts, verifier code, CI, or a custom workflow/kernel.
- After both groups stop writing, freeze the two result commits and run one joined read-only AI
  qualification review over all six rows. Deduplicate findings once and publish one conclusive matrix
  and closeout report.
- Do not repair a candidate P0/P1 inside this plan. Record the failed row and open an incremented
  candidate corrective work item under auto mode. Environment/provider/repository blockers remain
  explicit `not qualified` until a safe in-scope recovery actually observes the outcome.
- Stage explicit paths only and preserve `.superpowers/` and all unrelated files. No push, tag,
  publication, persistent install/config change, rollout, GA declaration, or organization risk
  acceptance is authorized.

## DoD coverage

| DoD | Owning task |
|---|---|
| D1, D2, D4, D6 (Codex/session portions), D9 | Task 1 — Codex Q1/Q3/Q5 |
| D1, D3, D5, D7 (Claude/session portions), D9 | Task 2 — Claude Q2/Q4/Q6 |
| D8, D10 and joined completion of D1-D9 | Task 3 — Joined qualification review |

## Planning baseline commit

After the Plan Gate is approved, stage and commit only this work item's `requirements.md` and
`plan.md`. This is one semantic planning commit and triggers no provider run, build, test, or review.

## Task 1 — Execute Codex qualification group Q1, Q3, and Q5

**Outcome:** the exact RC3 candidate is exercised through the complete Codex matrix and all three
rows receive defensible observed results.

**Status:** COMPLETE — NOT QUALIFIED

### Candidate/session boundary

- Create one read-only candidate extraction with `git archive` from exact commit
  `521c7a4ee939bb96f3f67a75050f71f5d13416a1`.
- Invoke `/Applications/ChatGPT.app/Contents/Resources/codex` in ephemeral mode with guarded temporary
  `HOME`/`CODEX_HOME`, a session-local marketplace that contains only that extraction, and temporary
  access to the existing authenticated context without copying it into a repository or printing it.
- Remove temporary auth linkage and provider state after the active call. If the bundled runtime
  cannot prove candidate-exclusive skill loading, mark the affected rows `not qualified`.

### Rows

- **Q1:** create the Core-only SwiftPM greenfield pilot, persist selected Profiles, implement the
  framework-neutral policy/use case and focused tests, commit semantically, and observe that Boardy
  is neither loaded nor assumed and release authority is not crossed.
- **Q3:** create the Boardy/VIP + SwiftUI SwiftPM pilot, vendor only source from exact Boardy commit
  `06f4c0de619b3e745f5727d0b2c29469db89b5cc` under its MIT boundary, implement typed IO/composition,
  humble display-ready MainActor state and focused tests, then run one final SwiftPM signal.
- **Q5:** create the isolated QuizCombat hybrid transition fixture, add a local SwiftPM distribution
  boundary while retaining CocoaPods, update bindings and an owned expiring exception, exercise a
  material-blocker handoff/resume, commit semantically, then run one final focused package signal.

### Result record

- Write `qualification-codex.md` containing only the evidence contract fields, the exact candidate
  identity, provider version/isolation, per-row result and findings, semantic fixture commits, final
  focused signal, residual risk, and sanitized blockers.
- Update Task 1 and its owned DoD state truthfully; a `not qualified` row still completes its
  disposition but does not become a pass.

**Observed disposition:** Tenant policy prevented the external Codex sessions before unpublished
candidate or fixture data was sent. Candidate-exclusive loader preparation succeeded, but no row
silently fell back to installed RC1. Trusted in-runtime rehearsals remain diagnostic only; Q3 exposed
P1 `F-RC3-QUAL-001`, so RC3 promotion and further RC3 rehearsal execution stopped.

### Commit boundary

- Exact main-repository paths: `qualification-codex.md`, `requirements.md`, and `plan.md` in this work
  item only.
- Fixture repositories use their own semantic commits and are not imported into the standards repo.
- Commit intent: `docs: record RC3 Codex field qualification`.

## Task 2 — Execute Claude qualification group Q2, Q4, and Q6

**Outcome:** the exact RC3 candidate is exercised through the complete Claude Code matrix and all
three rows receive defensible observed results.

**Status:** PENDING

### Candidate/session boundary

- Load only the same read-only candidate extraction through a session-local `--plugin-dir`, with
  no-session-persistence and the narrowest settings isolation that preserves existing OAuth.
- Prove the explicit candidate skills resolve before qualification work. If safe mode does not honor
  the explicit plugin directory, try one narrower non-persistent isolation path; never fall back to
  installed RC1 or merge unrelated user plugins/settings into the session.
- Do not persist plugin installation, provider configuration, auth material, or raw transcripts.

### Rows

- **Q2:** create the isolated QuizCombat representative fixture, first seed and commit exact
  Standards `0.18.4` bindings as a distinct pre-RC3 baseline, then load RC3 and migrate bindings/
  adoption guidance while assessing one existing Boardy/UIKit module. Preserve CocoaPods and product
  behavior; do not run an artificial build for binding-only changes.
- **Q4:** create a shared/sparse representative enterprise-adopter clone at exact clean baseline,
  implement one bounded
  framework-neutral widget-search destination policy used by both scoped SwiftUI and UIKit adapters,
  update bindings, keep Boardy out of scope, and run only the smallest final repository-owned Bazel
  signal covering the executable boundary.
- **Q6:** create a separate shared/sparse clone of the representative enterprise adopter at the same
  exact baseline, migrate portable
  bindings `2.2.0 → 2.5.0`, reconcile local full-auto authority, make one bounded AIChat public-contract
  purity correction, exercise provider-native handoff/resume and shared-writer control, commit
  semantically, then run the smallest viable final Bazel signal.

### Result record

- Write `qualification-claude.md` with the same bounded evidence contract used for Task 1, including
  the Q2 constructed-baseline identity and exact pre-RC3 commit.
- Update Task 2 and its owned DoD state truthfully; unavailable provider/build behavior remains
  `not qualified` with owner and residual risk.

### Commit boundary

- Exact main-repository paths: `qualification-claude.md`, `requirements.md`, and `plan.md` in this work
  item only.
- Fixture repositories use their own semantic commits and are not imported into the standards repo.
- Commit intent: `docs: record RC3 Claude field qualification`.

## Task 3 — Run one joined qualification review and close the matrix

**Outcome:** Q1-Q6 have one deduplicated, candidate-bound disposition suitable for accountable human
sign-off or an automatic corrective-candidate handoff.

**Status:** PENDING

### Frozen review input

- Authority inputs: approved `requirements.md` and `plan.md` from the planning-baseline commit.
- Candidate payload: exact immutable SHA
  `521c7a4ee939bb96f3f67a75050f71f5d13416a1` only.
- Qualification input range: planning-baseline commit exclusive through exact Task-2 result commit
  inclusive, restricted to this work item's two group reports and task-state updates.
- Provider fixture commits/signals named in the reports are inspectable inputs; raw transcripts,
  credentials, protected source, `.superpowers/`, unrelated history, and later review outputs are
  excluded.
- All provider and integration writers stop before reviewers start.

### Joined review lanes

- Candidate/provider isolation and Q1-Q6 outcome fidelity against `RELEASE.md`.
- Architecture/Profile/UI/build-system/adoption-mode behavior and executable-signal sufficiency.
- Authority, security/privacy/source protection, finding severity, residual risk, and YAGNI/lean
  operating-model conformance.

The integration owner joins and deduplicates all lanes once. There is no routine second review and no
rerun merely to duplicate a green signal. A candidate P0/P1 produces an incremented corrective work
item; an environment/repository limitation remains `not qualified`; P2 receives owner/disposition.

### Artifacts

- Write `review.md` with frozen identities, lane results, deduplicated findings and dispositions.
- Write `qualification.md` as the single Q1-Q6 status matrix with candidate identity and residual
  risks; it must distinguish `passed`, `not qualified`, and any candidate blocker.
- Write `final-report.md` with completed/failed DoD, planning/group/review commits, sign-off readiness,
  next corrective or human-decision boundary, and unchanged public RC1/release authority.
- Update requirements/plan statuses without editing the candidate payload or release claims.

### Commit boundary

- Exact paths: `requirements.md`, `plan.md`, `qualification-codex.md`,
  `qualification-claude.md`, `review.md`, `qualification.md`, and `final-report.md` in this work item.
- Commit intent: `docs: close RC3 field qualification`.

## Plan Gate

- Mode: auto
- Gate owner: independent AI reviewer who did not author this plan
- Approval rubric:
  - Every approved DoD item and every fixed Q row has one semantic owner and observable boundary.
  - Candidate/provider/auth/live-repository/release isolation is exact and cannot silently use RC1 or
    reporting HEAD.
  - Q2 is explicitly constructed and pre-committed; Q4 proves executable shared policy adoption.
  - Signal and review cadence removes duplicate green checks without inferring compatibility.
  - Provider batches and final review are large enough to avoid micro-checkpoints but narrow enough
    for traceable semantic commits.
  - Candidate defects start a new revision; environment blockers remain truthful; no hidden tooling,
    CI, kernel, persistent install, or external authority is introduced.
  - The plan can run continuously until a genuine provider, repository, or policy blocker.
- Verdict: AUTO_APPROVED
- Reviewer: independent agent `iis0005_plan_gate`
- Open material questions: none

STATUS: READY_FOR_EXECUTION
