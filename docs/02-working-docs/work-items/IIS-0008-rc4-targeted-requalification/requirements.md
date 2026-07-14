# Requirements — IIS-0008 RC4 targeted requalification

## Meta

- Created: 2026-07-14
- Flow mode: auto
- Candidate version: `1.0.0-rc.4`
- Immutable candidate commit: `f7cd2cf87711f1a757d2fbdec5be9be02ee69173`
- Predecessor closeout: IIS-0007 at `abfca60ac8d3160a01bd50b09643cd97739c899d`
- Verification: one provider-native final signal for each changed code fixture plus one joined final AI
  review; no plugin-owned script, verifier, CI, receipt, or custom kernel

## Goal

Close the two locally actionable RC4 qualification failures without repeating green rows or external
authentication failures: reproduce Q1 with an explicit consuming-repository `core` Profile binding,
and correct/re-execute the single Q5 fixture test compile failure. Preserve Q3's exact-candidate pass
and truthfully retain Q2/Q4/Q6 as externally blocked.

## Authority and fixed boundary

- Local temporary fixture creation, fixture code/test/docs changes, focused repository-owned commands,
  and semantic local commits are authorized by the existing full-auto and commit-by-task direction.
- Provider sessions start with Full Access. If a local permission action still fails, classify it once
  and continue/close the row; do not run another permission loop.
- No candidate payload mutation is authorized in IIS-0008. A reproducible candidate defect opens a new
  approved candidate-revision plan rather than being repaired here.
- No Claude authentication probe or Q2/Q4/Q6 execution is allowed until external authentication state
  changes. Codex cannot substitute those rows.
- No Q3 rerun: its passing result at fixture HEAD `e3921c0545ce5de3684d9d9d17f2ba47aefab0f1`
  remains applicable because the immutable RC4 payload is unchanged.
- No push, tag, release, marketplace update, persistent install/configuration change, GA declaration,
  or organization risk acceptance is authorized.

## Q1 controlled reproduction

Create a new history from clean Q1 source baseline
`7871194d07eec6e18eae27b5c30c1f81919755ff`. Before provider execution, add identical minimal root
`CLAUDE.md` and `AGENTS.md` consuming-repository bindings that declare:

- selected Standards Profiles: `core` only;
- SwiftPM and project-owned `swift test`;
- auto mode and scoped local fixture commit authority;
- no Boardy/VIP selection and no external/release authority.

Commit that fixture binding as the new immutable Q1 baseline. Run one fresh Codex session with
row-owned provider state and exact RC4. It must invoke RC4 Brain Flow against the already approved
outer plan, implement the same small framework-neutral delivery-eligibility Domain policy and
Application use case, commit semantically, and run one final `swift test` signal.

The row passes only if the provider does not load/invoke a Boardy skill, the source has no Boardy
import/assumption, the final signal is green, semantic commits exist, the worktree is clean, and no
release authority is crossed. A second Boardy load establishes reproducible Q1 Profile-routing
failure for disposition; do not attempt a third session in IIS-0008.

## Q5 focused recovery

Continue from sanitized historyless fixture HEAD
`3cbf36cfd5369fcc2bf95eca3571ab1665d6662f`. The only authorized implementation change is the
smallest test-code correction needed to compare the optional restored date safely in
`AppPreferencesSerializationTests.swift`; production source, transition records, `Podfile`, and
podspec are frozen.

Run one fresh Codex session with row-owned provider state and exact RC4 against the approved outer
plan. Commit the test correction as one semantic task, then run exactly one final
`swift test --package-path submodules/SharedPreferences` signal. The row passes only if tests execute
green, the frozen surfaces remain unchanged, the worktree is clean, and previously recorded
organization-policy handoff boundaries remain unaccepted by AI.

## Cadence and finding policy

- Q1 and Q5 are independent writers and may run concurrently with separate writable
  `HOME`/`CODEX_HOME`/auth linkage; only the read-only RC4 extraction may be shared.
- The outer approved requirements/plan is the only plan gate. Provider rows execute their assigned
  task without opening nested requirements/review checkpoints.
- Each row gets one final signal on its completed state. A failed signal is evidence, not a reason for
  an unchanged retry. Collect provider findings until both writers stop.
- Freeze exact task commits, then run exactly one joined read-only AI review over IIS-0008. Apply at
  most one reporting-only correction batch; do not rerun review or unchanged signals.
- Preserve unrelated `.superpowers/` and stage only explicit work-item paths in the Standards repo.

## Definition of Done

- [x] **D1 — Approved exact-candidate plan.** One independent auto gate approves the bounded Q1/Q5
  plan; every provider session loads only RC4 at `f7cd2cf…` with separate writable state.
- [x] **D2 — Q1 baseline is explicit.** Clean source plus identical `core`-only repository bindings
  form a committed immutable baseline with no Boardy source/dependency.
- [x] **D3 — Q1 is requalified or dispositioned.** Provider Profile routing, semantic commits, final
  SwiftPM signal, clean state, and authority behavior are recorded without a third attempt.
- [x] **D4 — Q5 is requalified or dispositioned.** Only the known test compile seam changes; one final
  package signal, frozen production/CocoaPods surfaces, clean state, and policy-owner boundaries are
  recorded.
- [x] **D5 — Valid results are retained.** Q3 remains passed against unchanged RC4; Q2/Q4/Q6 remain
  external-authentication holds with no retry or substitution.
- [x] **D6 — Review converges once.** One joined final AI review deduplicates candidate, provider,
  fixture, and external findings; at most one reporting-only closeout batch follows.
- [x] **D7 — History is semantic.** Planning, Q1 result, Q5 result, and closeout are separate local
  semantic commits; unrelated paths remain untouched.
- [x] **D8 — Release claims remain truthful.** The final matrix reports actual pass count and keeps
  RC4 unpublished/not qualification-complete while any mandatory row remains unpassed.
- [x] **D9 — External boundary is preserved.** Public RC1, remotes, refs, tags, releases, marketplace,
  installed plugin, organization policy, and GA state are unchanged.

Work-item status: **CLOSED — NOT QUALIFIED (3/6 rows passed)**

## Requirement Gate

- Mode: auto
- Reviewer: independent agent `iis0007_qualification_map`, reassigned as IIS-0008 combined gate
- Verdict: AUTO_APPROVED — no P0/P1

STATUS: APPROVED
