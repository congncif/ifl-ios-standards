# Requirements — IIS-0005 RC3 field qualification

## Meta

- Created: 2026-07-14
- Flow mode: auto
- Candidate version: `1.0.0-rc.3`
- Immutable candidate commit: `521c7a4ee939bb96f3f67a75050f71f5d13416a1`
- Reporting baseline HEAD: `da52e65` (not the candidate)
- Branch/worktree: `codex/standards-1.0` in `/private/tmp/ifl-ios-pack-standards-v1`
- Change class: provider-native field qualification and ordinary Markdown result records
- Verification owner: Qualification Owner per row; one final joined AI qualification review

## Authority and boundary

- The user authorized uninterrupted full-auto work toward the complete enterprise standard and
  scoped local stage/commit for semantic tasks in the approved standards plan.
- Ordinary session-local Codex/Claude model invocations, isolated fixture writes, focused
  project-owned executable commands, and semantic commits inside qualification fixtures are required
  qualification operations. They do not authorize a persistent plugin install, mutation of user
  provider configuration, source-adopter repository write, remote Git operation, tag, release,
  marketplace change, rollout, or GA declaration.
- Candidate source is extracted from the exact immutable SHA. IIS-0005 never edits that candidate or
  treats reporting HEAD as equivalent.
- Live adopter repositories are read-only baselines. All provider writes occur in guarded temporary
  repositories created from immutable commits; existing dirty files and protected product data remain
  in their owning environments.
- Qualification uses provider-native sessions, ordinary Git/project commands, and concise Markdown
  results. It does not create a plugin-owned verifier, workflow kernel, receipt/evidence framework,
  test harness, CI implementation, or release automation.

## Goal

Execute every Q1-Q6 row in `ifl-ios-standards/RELEASE.md` against the exact RC3 candidate, observe the
required provider/Profile/build-system/adoption behavior, disposition all findings truthfully, and
produce a qualification status that is usable for accountable human sign-off. A row passes only when
its required outcome is observed with no open P0/P1; unavailable or failed behavior remains
`not qualified` and cannot be inferred from static compatibility claims.

## Qualification evidence contract

For each row record only:

- candidate version and exact SHA;
- provider/runtime version and session-isolation method;
- immutable repository/pilot baseline and repository class;
- selected Profiles/enterprise chapters, build system, adoption mode, task, and authority boundary;
- observed provider flow, semantic commits, focused signals when executable code changed, and final
  result;
- P0/P1/P2 findings, disposition/owner, residual risk, and any sanitized blocker.

Do not copy protected adopter source, raw credentials, provider auth files, full model transcripts, or
machine-specific secrets into the standards repository. Temporary raw output may be used during the
active task and is summarized into ordinary Markdown; it is not a release receipt.

## Fixed qualification scenarios

### Q1 — Codex / Core-only / SwiftPM / greenfield

- Host: new isolated iOS SwiftPM `CorePolicyPilot` repository.
- Task: full-auto implement and test a small framework-neutral delivery-eligibility Domain policy and
  Application use case from approved requirements through one joined review.
- Required observation: Core/Brain only; no Boardy skill/import/assumption; semantic commits; no push,
  tag, publish, install, or other release-authority crossing.

### Q2 — Claude Code / Core + Boardy/VIP + UIKit / CocoaPods / 0.18.x brownfield

- Host: isolated `QuizCombatApp` at `d00e842905a53de17be65c134d40c15d58dfde0b`, seeded with the
  exact historical Standards `0.18.4` snapshot at
  `ee011fe5f8b018cbb263e93e320349934b34d97b` before RC3 is loaded.
- Classification: constructed representative migration pilot, not a claim that the source application
  previously adopted Standards `0.18.4`. The isolated fixture must commit its `0.18.4` bindings as a
  distinct pre-RC3 baseline before the RC3 provider session starts; otherwise Q2 is `not qualified`.
- Task: migrate project bindings/adoption guidance and assess one existing Boardy/UIKit module without
  changing product behavior or package manager.
- Required observation: existing IO/Plugins boundaries remain migratable, Boardy stays in the selected
  shell, CocoaPods and repository-owned commands/bindings are preserved, and no artificial build runs
  for documentation/binding-only changes.

### Q3 — Codex / Core + Boardy/VIP + SwiftUI / SwiftPM / greenfield

- Host: new isolated iOS SwiftPM pilot with Boardy source vendored from immutable MIT-licensed Boardy
  commit `06f4c0de619b3e745f5727d0b2c29469db89b5cc` through a project-owned local package target.
- Task: implement a small typed-IO Boardy/VIP feature whose SwiftUI View is hosted at the outward
  boundary, observes display-ready MainActor state, emits intent only, and has focused tests.
- Required observation: IO/composition, Presenter/equivalent display mapping, humble SwiftUI state,
  isolation, approved-plan execution, one joined review, and one final SwiftPM/Xcode signal agree.

### Q4 — Claude Code / Core + UIKit + SwiftUI / Bazel / brownfield / no Boardy in scope

- Host: isolated sparse/shared clone of a representative enterprise adopter repository at clean
  `origin/develop`
  `6296c186812011be89e25429f387064e9dedc4a4`.
- Scope: production `WidgetExtension` SwiftUI adapter and `Features/OneSearch` UIKit adapter; Boardy is
  non-applicable to this bounded surface even though other app modules use it.
- Task: implement one bounded framework-neutral widget-search destination policy and connect both the
  SwiftUI and UIKit adapters to that executable policy, with the smallest repository-owned focused
  Bazel signal that can exercise or compile the changed boundary. Documentation/bindings describe the
  decision but cannot substitute for executable adoption.
- Required observation: Claude loads Core/UIKit/SwiftUI only for the scope, keeps Bazel and repository
  commands, introduces no Boardy assumption/package rewrite, and correctly omits product build/test
  outside the one final focused signal. A row cannot pass merely because the adapters could
  theoretically share a policy.

### Q5 — Codex / Core + enterprise chapters / CocoaPods + SwiftPM hybrid / transitional

- Host: a separate isolated `QuizCombatApp` baseline at
  `d00e842905a53de17be65c134d40c15d58dfde0b`.
- Task: add a local SwiftPM distribution boundary for the existing Foundation-only
  `SharedPreferences` module while its podspec/Podfile consumer remains during transition; update
  bindings and an owned, expiring transition/exception record.
- Applicable concerns: Swift/concurrency destination, data lifecycle, privacy/security, modern
  testing, and supply-chain/legal; other chapters require explicit owned N/A rationale.
- Required observation: partial/transitional conformance, policy owners, expiration/remediation,
  focused package signal, material-blocker escalation, handoff, and resume are usable without
  inventing organization decisions or converting the whole app/package manager.

### Q6 — Claude Code / Core + Boardy/VIP + mixed UIKit/SwiftUI + enterprise / organization graph

- Host: a separate isolated sparse/shared clone of the same representative enterprise adopter at
  `6296c186812011be89e25429f387064e9dedc4a4`.
- App evidence: Boardy/VIP + UIKit `Features/AIChat`, SwiftUI `WidgetExtension`, Bazel organization
  graph, privacy manifests/entitlements, and performance test surfaces.
- Task: migrate portable bindings `2.2.0 → 2.5.0`, reconcile full-auto authority, then make one bounded
  AIChat public-contract purity correction and run its smallest viable repository-owned Bazel signal.
- Required observation: provider-native handoff/resume, one writer at a time, scoped local commits,
  focused signal, Boardy confined to selected shell, mixed-app UI/enterprise applicability, and one
  joined final review operate end to end.

## Provider/session isolation

- Claude loads only the exact extracted candidate through a session-local `--plugin-dir`; use safe
  mode with existing OAuth when explicit plugins resolve there, otherwise use the narrowest settings
  isolation that preserves OAuth and record the observed limitation. No persistent install/update.
- Codex uses the ChatGPT-bundled CLI, a guarded temporary `HOME`/`CODEX_HOME`, a local marketplace
  pointing only to the extracted candidate, ephemeral exec sessions, and the existing authenticated
  user context without printing or committing credentials. Temporary auth linkage is removed after
  the active model call.
- A provider path that cannot load the exact candidate or authenticate safely is `not qualified`; do
  not silently run the installed RC1 plugin instead.
- Provider settings, skills, hooks, MCPs, and plugins outside the extracted candidate must be excluded
  from the qualification session. If the session cannot demonstrate RC3 as its only standards/plugin
  payload, the affected row is `not qualified` even when the task output otherwise appears correct.

## Finding policy

- Apply the P0/P1/P2 qualification severity in `RELEASE.md`.
- A candidate P0/P1 is not fixed inside IIS-0005. Freeze the result, open a new approved incremented
  candidate plan, repeat affected rows, then run that plan's one final review.
- Fixture/repository/environment findings that do not indict candidate behavior remain owned
  qualification blockers and keep the row `not qualified` until observed successfully.
- P2 is recorded with owner/disposition and does not automatically trigger reruns.

## Out of scope

- Editing or publishing RC3 candidate content, narrowing Q1-Q6, or marking any row N/A to avoid work.
- Writing to live QuizCombatApp, Boardy, the representative enterprise adopter, or other
  user/adopter repositories.
- Full product builds when a focused target suffices, repeated build/test after each finding, or CI.
- Persistent provider/plugin/config/auth mutation, credential disclosure, external release operations,
  organization risk acceptance, or human sign-off decisions.

## Definition of Done

- [ ] **D1 — Exact candidate isolation.** Every provider session demonstrably loads extracted
  `521c7a4…`; installed/public RC1 and reporting HEAD are not used as the qualification payload.
- [x] **D2 — Q1 is dispositioned.** Required Core-only Codex/SwiftPM greenfield behavior is observed
  or truthfully recorded `not qualified` with findings.
- [ ] **D3 — Q2 is dispositioned.** Required Claude/Boardy/UIKit/CocoaPods 0.18.x migration behavior is
  observed or truthfully recorded `not qualified` with findings.
- [x] **D4 — Q3 is dispositioned.** Required Codex/Boardy/SwiftUI/SwiftPM greenfield behavior is
  observed or truthfully recorded `not qualified` with findings.
- [ ] **D5 — Q4 is dispositioned.** Required Claude/mixed-UI/no-Boardy/Bazel brownfield behavior is
  observed or truthfully recorded `not qualified` with findings.
- [x] **D6 — Q5 is dispositioned.** Required Codex/hybrid/transitional enterprise behavior is observed
  or truthfully recorded `not qualified` with findings.
- [ ] **D7 — Q6 is dispositioned.** Required Claude/full enterprise modular-app behavior is observed
  or truthfully recorded `not qualified` with findings.
- [ ] **D8 — Findings are governed.** No open P0/P1 is hidden; candidate defects start a new revision,
  environment/repository blockers remain explicit, and P2 has owner/disposition.
- [ ] **D9 — Evidence remains lean and safe.** Records contain the required sanitized observations,
  no secrets/protected source/raw transcripts, no verifier/CI/receipt system, and no duplicate signal.
- [ ] **D10 — Review/history are conclusive.** Codex and Claude row groups each have one semantic
  result commit; one final joined qualification review covers all rows; main-repo commits use explicit
  paths; `.superpowers/` and external release state remain untouched.

## Requirement gate

- Mode: auto
- Gate owner: independent AI reviewer who did not author this document
- Approval rubric:
  - Each RELEASE row maps to one concrete defensible host/task/outcome without weakening its claim.
  - Candidate/repository/provider/auth/release boundaries are explicit and safe.
  - Results are observable but do not create a pack-owned evidence or verification framework.
  - DoD supports pass and truthful not-qualified outcomes without manufacturing success.
  - The work can continue autonomously until a genuine provider/repository/policy blocker.
- Verdict: AUTO_APPROVED after retained amendments
- Reviewer: independent agent `iis0005_requirement_gate`
- Open material questions: none after retaining Q2 constructed-baseline identity, Q4 executable
  adoption, and candidate-exclusive provider isolation

STATUS: READY_FOR_PLAN
