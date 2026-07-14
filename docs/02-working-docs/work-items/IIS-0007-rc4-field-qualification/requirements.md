# Requirements — IIS-0007 RC4 field qualification

## Meta

- Created: 2026-07-14
- Flow mode: auto
- Candidate version: `1.0.0-rc.4`
- Immutable candidate commit: `f7cd2cf87711f1a757d2fbdec5be9be02ee69173`
- Execution branch/worktree: `codex/standards-1.0` in
  `/private/tmp/ifl-ios-pack-standards-v1`
- Verification: provider-native task signals plus one final joined AI review; no plugin-owned verifier,
  script, CI, receipt, or custom kernel

## Authority and boundary

- The user authorized full-auto local qualification work and instructed the flow to skip a provider
  permission step if it remains unavailable, rather than repeating the permission loop.
- Local isolated fixture writes, focused project-owned commands, and semantic commits are in scope.
- No persistent provider/plugin configuration, adopter-repository write, push, tag, release,
  marketplace update, installation, rollout, GA declaration, or organization risk acceptance is
  authorized.
- Candidate source is extracted from the exact immutable commit. Public/installed RC1 and later
  reporting commits are not qualification payloads.
- A provider row passes only when that provider actually runs the row. A Claude-only row cannot be
  substituted with Codex; an authentication or tenant-policy denial is recorded `SKIPPED` and remains
  `not qualified`.
- Provider input must not contain credentials, provider settings, protected adopter source outside
  the bounded scenario, or unrelated repository history. Q5 therefore uses a sanitized minimum
  fixture exported from the exact baseline rather than the existing full clone, which contains
  tracked sensitive/provider-local files.

## Goal

Exercise every currently reachable `RELEASE.md` field-qualification row against exact RC4, truthfully
disposition unreachable rows without repeating permission attempts, and produce a single release-
readiness result with no hidden P0/P1 or inferred provider compatibility.

## Fixed outcomes

### Q1 — Codex / Core-only / SwiftPM / greenfield

Run Brain Flow in auto mode on the clean `CorePolicyPilot` baseline. Implement a small
framework-neutral delivery-eligibility Domain policy and Application use case with focused tests.
Observe Core-only routing, semantic commits, one final SwiftPM signal, one final review, and no Boardy
or release-authority crossing.

### Q2 — Claude Code / Boardy/VIP + UIKit / CocoaPods / 0.18.x brownfield

Do not substitute providers. The one allowed candidate-load probe returned `401 Invalid
authentication credentials`; record the row `SKIPPED — provider authentication` and `not qualified`
without sending the fixture or repeating authentication attempts.

### Q3 — Codex / Boardy/VIP + SwiftUI / SwiftPM / greenfield

Run Brain Flow in auto mode on the clean fixture seeded from Boardy commit
`06f4c0de619b3e745f5727d0b2c29469db89b5cc`. Implement a small typed-IO Boardy/VIP feature with a
SwiftUI outward adapter, display-ready MainActor state, intent-only View, focused tests, semantic
commits, one final executable signal, and one final review.

### Q4 — Claude Code / Core + UIKit + SwiftUI / Bazel / brownfield

Apply the same truthful Claude disposition as Q2. Do not expose the representative adopter fixture or
run a Codex substitute.

### Q5 — Codex / enterprise transition / CocoaPods + SwiftPM

Create a new isolated sanitized repository from exact product baseline
`d00e842905a53de17be65c134d40c15d58dfde0b`, exporting only `SharedPreferences`, the CocoaPods
consumer declaration, license context, and a neutral qualification-context note. The fixture
must contain no credentials, `.claude`, `.codex`, `.agents`, or unrelated product source/history.
Run Brain Flow in auto mode to add a local SwiftPM distribution boundary while retaining the existing
CocoaPods path; add owned, expiring transition/conformance records; exercise handoff/resume; commit
semantically; and run one final focused package signal and one final review.

### Q6 — Claude Code / Boardy/VIP + mixed UI + enterprise

Apply the same truthful Claude disposition as Q2. Do not expose the representative adopter fixture or
run a Codex substitute.

## Provider/session isolation

- Codex uses the ChatGPT-bundled CLI with an independent temporary `HOME`/`CODEX_HOME` and temporary
  auth linkage per row, a candidate-only local marketplace, exact RC4 plugin, and ephemeral sessions.
  Concurrent rows may share only the read-only candidate extraction, never writable provider state.
- The successful Codex candidate-load probe returned
  `CANDIDATE_VERSION=1.0.0-rc.4` and `BRAIN_FLOW_SKILL_LOADED=yes`.
- The Claude candidate-load probe failed before inference with `401 Invalid authentication
  credentials`. Per user direction, do not retry the permission/authentication boundary in this plan.
- A catalog warning attributed to provider-managed `workspace-agents` is external probe noise; all
  three RC4 `defaultPrompt` entries satisfy the provider manifest limit and require no candidate
  change.

## Finding and cadence policy

- P0/P1 follow `RELEASE.md` and block promotion; candidate fixes require a new revision and affected
  requalification.
- P2 receives an owner and explicit disposition.
- Execute the available Codex rows as one semantic qualification batch. Collect all findings before
  any correction; allow at most one correction batch and no routine re-review or duplicate green
  signal.
- After all provider writers stop, run one joined read-only AI review over the whole IIS-0007 plan.
- Commit by semantic task with explicit path staging; preserve unrelated `.superpowers/`.

## Definition of Done

- [x] **D1 — Exact candidate isolation.** Every executed provider session demonstrably loads only
  RC4 at `f7cd2cf…` as its standards payload and owns separate writable provider state.
- [x] **D2 — Q1 is dispositioned.** The required Codex Core-only behavior is observed or truthfully
  remains not qualified.
- [x] **D3 — Q2 is dispositioned.** Claude authentication skip and residual qualification status are
  explicit, with no provider substitution.
- [x] **D4 — Q3 is dispositioned.** The required Codex Boardy/SwiftUI behavior is observed or
  truthfully remains not qualified.
- [x] **D5 — Q4 is dispositioned.** Claude authentication skip and residual qualification status are
  explicit, with no protected fixture exposure.
- [x] **D6 — Q5 is dispositioned safely.** The required Codex hybrid-transition behavior is observed
  only on a historyless sanitized baseline, or truthfully remains not qualified.
- [x] **D7 — Q6 is dispositioned.** Claude authentication skip and residual qualification status are
  explicit, with no protected fixture exposure.
- [ ] **D8 — Findings and signals converge.** No open P0/P1 is hidden; one final signal per code row,
  at most one correction batch, and no duplicate review/test are used.
- [ ] **D9 — Review and history are conclusive.** Semantic task commits and exactly one joined final
  review produce a truthful Q1-Q6 matrix and release-readiness result.
- [ ] **D10 — External boundary is preserved.** Public RC1, remote branches, tags, releases,
  marketplace, local installed plugin, and GA state are unchanged by qualification.

## Requirement Gate

- Verdict: AUTO_APPROVED after retained amendments
- Reviewer: independent agent `iis0007_qualification_map`
- Retained amendments: separate writable provider state per concurrent Codex row; historyless Q5
  fixture with a neutral minimum Podfile and both inventory and bounded-content inspection

STATUS: APPROVED
