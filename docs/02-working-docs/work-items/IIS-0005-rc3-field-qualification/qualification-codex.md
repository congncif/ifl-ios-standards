# RC3 Codex field-qualification result

## Result

- Candidate: `1.0.0-rc.3`
- Candidate commit: `521c7a4ee939bb96f3f67a75050f71f5d13416a1`
- Runtime inspected: ChatGPT-bundled `codex-cli 0.144.2`
- Group disposition: **NOT QUALIFIED**
- Open candidate findings: P0/P1/P2 = `0/1/0`

The candidate was extracted from the exact immutable commit and exposed through an isolated local
marketplace containing only RC3. Before an external provider session could execute a row, tenant
policy denied processing the unpublished candidate and fixture data. The user had authorized Q1-Q6
processing, but that authorization could not override the tenant control. No prompt or fixture source
was sent, installed RC1 was not used as a fallback, and temporary authentication linkage was removed.

Trusted in-runtime rehearsals were then used only to discover candidate defects. They are not
provider-native sessions and are not qualification passes.

## Q1 — Core-only / SwiftPM / greenfield

- Official result: **NOT QUALIFIED — provider environment hold**.
- Open row findings P0/P1/P2: `0/0/0`.
- Recovery owner: Qualification Owner with the tenant/provider policy owner.
- Fixture baseline: `7871194d07eec6e18eae27b5c30c1f81919755ff`.
- Rehearsal commit: `856e759c3a1124d63ed3ffc03d173010e0eea224`
  (`feat: add delivery eligibility policy`).
- Rehearsal observation: framework-neutral Domain policy and Application composition; Boardy was not
  loaded or assumed; local release authority was not crossed.
- Final rehearsal signal: one `swift test` event, 5 tests in 2 suites, 0 failures.
- Rehearsal review: P0/P1/P2 = `0/0/0`.
- Residual risk: provider-native skill selection, authority handling, and auto-loop completion were
  not observed.

## Q3 — Boardy/VIP + SwiftUI / SwiftPM / greenfield

- Official result: **NOT QUALIFIED — provider environment hold and candidate P1**.
- Open row findings P0/P1/P2: `0/1/0`.
- Recovery owners: Standards Owner for `F-RC3-QUAL-001`; Qualification Owner with the
  tenant/provider policy owner for provider access.
- Fixture baseline: Boardy source commit `06f4c0de619b3e745f5727d0b2c29469db89b5cc`,
  represented by fixture commit `674b06bf862c3bcb1f439a27b4f8d2912b3acdd8`.
- Rehearsal commits:
  - `dc7f955` — expose vendored Boardy as a local SwiftPM target;
  - `b84953e` — add a typed Boardy/VIP SwiftUI welcome board.
- Rehearsal observation: typed public IO, destination-bound composition, display-ready MainActor
  state, intent-only SwiftUI View, and project-owned local Boardy integration.
- Final rehearsal signal: one Xcode package test event, 8 tests, 0 failures.
- Rehearsal review: candidate P0/P1/P2 = `0/1/0`.
- Finding `F-RC3-QUAL-001` (P1): `MICROBOARD_UI.md`, `EXAMPLES_VIP_BOARD.md`,
  `COMMUNICATION.md`, and the compact Boardy cheatsheet route `returnHere()` through
  `rootViewController`, while `BRD-CTX-001`, `CONTEXT_NAVIGATION.md`, and
  `REVIEWER_CHECKLIST.md` require the destination ViewController. Related activation-order guidance
  also connects the navigation bus after `show()` in some derived documents and before `show()` in
  the context-navigation contract.
- Disposition: RC3 promotion and remaining RC3 rehearsal work stopped. The Standards Owner must
  correct the derived guidance in a new incremented candidate and repeat affected qualification.

## Q5 — enterprise transition / CocoaPods + SwiftPM hybrid

- Official result: **NOT QUALIFIED — provider environment hold**.
- Open row findings P0/P1/P2: `0/0/0`; the fixture-document P1 described below is closed.
- Recovery owner: Qualification Owner with the tenant/provider policy owner.
- Fixture baseline: `d00e842905a53de17be65c134d40c15d58dfde0b`.
- Rehearsal commits:
  - `2498d90` — add the local SharedPreferences package boundary and focused tests;
  - `0248af9` — bind the hybrid transition and its expiring record;
  - `43908a7` — correct final-review applicability wording.
- Rehearsal observation: CocoaPods surfaces stayed unchanged, a local SwiftPM distribution boundary
  was added, and the transition remains explicitly partial with expiration `2026-10-14`.
- Final rehearsal signal: one `swift test --package-path submodules/SharedPreferences` event,
  4 tests, 0 failures.
- Rehearsal review: one fixture-document P1 was corrected in the single allowed batch; no open
  fixture P0/P1 remained and no duplicate review or test ran.
- Residual risk: provider-native handoff/resume and organization policy-principal decisions were not
  observed; Swift 6 isolation of mutable global storage remains transitional.

## Group boundary

No network call, persistent plugin/configuration mutation, adopter-source write, push, tag, publish,
install, CI, custom verifier, receipt framework, or release action was performed. Q1, Q3, and Q5 are
dispositioned but remain not qualified.
