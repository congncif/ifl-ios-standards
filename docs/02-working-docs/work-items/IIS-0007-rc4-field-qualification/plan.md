# Plan — IIS-0007 RC4 field qualification

## Meta

- Created: 2026-07-14
- Mode: auto
- Requirements: `requirements.md`
- Immutable candidate: `f7cd2cf87711f1a757d2fbdec5be9be02ee69173`
- Integration owner: primary agent; exactly one provider writer per isolated fixture

## Execution strategy

- Commit this approved requirements/plan pair as one planning baseline.
- Reuse the already proven candidate-only temporary Codex marketplace and exact RC4 extraction.
- Run Q1, Q3, and Q5 in independent clean fixtures, concurrently where safe. Each row invokes RC4
  Brain Flow in auto mode, owns its fixture exclusively, makes semantic fixture commits, runs one final
  focused executable signal because code changes, and performs one final joined row review.
- Never place the full Q5 product clone in provider context. Build a new minimal fixture by exporting
  only an allowlisted set from the exact baseline, inspect its filename inventory locally, initialize
  a new Git history, and only then start the provider session.
- Do not retry Claude authentication. Record Q2/Q4/Q6 as `SKIPPED — provider authentication` and
  `not qualified`; Codex results do not transfer across providers.
- Join all six dispositions once after provider writers stop. Collect all findings, allow at most one
  correction batch if needed, do not run a second review, and do not duplicate green signals.
- Stage main-repository paths explicitly and commit by semantic task. Never stage `.superpowers/`.

## Task 1 — Planning baseline and guarded fixtures

**Outcome:** approved executable scope, exact candidate boundary, and clean provider inputs.

**Status:** COMPLETE

- Obtain one independent combined requirement/plan gate.
- Commit only this work item's `requirements.md` and `plan.md`.
- Confirm Q1 and Q3 are clean at their immutable baselines.
- Export Q5 into a new sanitized fixture containing only:
  - `LICENSE`;
  - a neutral `Podfile` recreated with only the existing `SharedPreferences` local-path declaration,
    never copied from the product fixture wholesale;
  - `submodules/SharedPreferences/SharedPreferences.podspec` and `Sources/**`;
  - a neutral `QUALIFICATION_CONTEXT.md` naming the source SHA, CocoaPods ownership, selected module
    boundary, authority, and excluded sensitive surfaces.
- Reject the Q5 fixture if its inventory or bounded content inspection contains credentials, provider
  settings, agent payloads, product metadata, or unrelated product source. Record the source
  declaration hash/provenance in `QUALIFICATION_CONTEXT.md`. The export must contain no source Git
  object database; initialize and commit a new history locally only after both checks.

**Commit:** `docs: plan RC4 field qualification`

## Task 2 — Execute Codex Q1, Q3, and Q5

**Outcome:** every Codex row has a provider-native, exact-candidate result.

**Status:** COMPLETE — Q1/Q5 NOT QUALIFIED; Q3 PASSED

- Launch one ephemeral Codex session per fixture using a row-owned temporary `HOME`, `CODEX_HOME`,
  auth linkage, and candidate-only marketplace. Rows share only the read-only RC4 extraction.
- Require the first model action to invoke `/ifl-ios-standards:brain-flow` and confirm RC4 from the
  plugin `VERSION` file.
- Give each session only its fixed row task and local fixture authority. No remote/release operation,
  persistent install/configuration change, unrelated path access, or extra test loop is allowed.
- When all sessions finish, inspect semantic commits, final signal summaries, worktree cleanliness,
  and final responses. Do not rerun merely to obtain another green result.
- Write `qualification-codex.md` with candidate/runtime/isolation, baseline, observed flow, commits,
  one final signal, row review, findings, residual risk, and result for Q1/Q3/Q5.

**Commit:** `docs: record RC4 Codex field qualification`

## Task 3 — Disposition Claude Q2, Q4, and Q6

**Outcome:** unavailable provider rows are closed truthfully without a permission loop or data
exposure.

**Status:** PENDING

- Record the single Claude probe command boundary, runtime version, pre-inference 401 result, zero
  fixture exposure, zero mutation, and no retry.
- Mark Q2/Q4/Q6 `SKIPPED — provider authentication` and `not qualified` with the Claude
  Qualification Owner/provider authentication owner as recovery owners.
- Write `qualification-claude.md`; do not invoke Claude again and do not substitute Codex.

**Commit:** `docs: record RC4 Claude qualification skip`

## Task 4 — One joined final review and release-readiness closeout

**Outcome:** one deduplicated Q1-Q6 matrix and an accountable next boundary.

**Status:** PENDING

- Freeze exact planning, Codex-result, and Claude-result commits.
- Run one joined independent AI review across candidate identity, provider fidelity, architecture,
  fixture security, signal sufficiency, authority, severity, and release claims.
- Apply at most one consolidated correction batch to reporting artifacts; do not rerun the review or
  provider/test signals.
- Write `review.md`, `qualification.md`, and `final-report.md`; update DoD/task statuses.
- Release-readiness must remain `NOT QUALIFIED` while any mandatory Claude row is skipped, even if all
  Codex rows pass. No external release operation follows without separate exact authority and complete
  qualification.

**Commit:** `docs: close RC4 field qualification`

## Plan Gate

- Mode: auto
- Gate owner: independent AI reviewer not authoring these documents
- Rubric: exact candidate/provider fidelity, no provider substitution, sanitized fixture boundary,
  one-signal/one-review cadence, semantic commit scope, truthful release status, and no hidden tooling
  or external authority.
- Verdict: AUTO_APPROVED after retained amendments
- Reviewer: independent agent `iis0007_qualification_map`
- Retained amendments: separate writable provider state per concurrent row; neutral Q5 Podfile plus
  inventory-and-content inspection

STATUS: APPROVED
