# IIS-0011 — RC4 qualification closeout and verification-scope optimization

## Goal

Ingest the completed direct Claude CLI results for Q2/Q4/Q6, close the frozen RC4 qualification
matrix once, update promotion readiness, and encode the approved representative-configuration rule in
Brain Flow without introducing tooling, build matrices, or another execution/review loop.

## Fixed inputs

- Standards worktree baseline: `727ae0d` on `codex/standards-1.0`.
- Frozen RC4 payload: `1.0.0-rc.4` at
  `f7cd2cf87711f1a757d2fbdec5be9be02ee69173`; IIS-0011 does not rewrite that commit.
- Retained rows: Q1, Q3, and Q5 passed against exact RC4; Q3 includes one native
  `xcodebuild test` result with 5 tests and 0 failures.
- Direct rows:
  - Q2: `0ada3e13d33529c92e41579a0aacafff9f36065d`;
  - Q4: `04d50855af14b4de89055446881166dcfe45730e`;
  - Q6: `3476c3c0a6ef421fbe52aca79c1d31c5aa19f54c` and
    `4793004bb025b47dba77d43709912fe5b1065835`.
- User-owned verification decision: nonstandard project configurations do not require exhaustive
  build/test coverage when an accepted representative platform signal exists. Record the waived
  target-specific coverage and residual risk; do not relabel a known build-graph defect as a candidate
  defect. This applies to iOS and, as a technology-neutral operating principle, Android variants.
- Direct CLI transport requires the operator's normal setting sources; empty `--setting-sources ""`
  prevents the configured local-model route. Default settings may provide transport but are never
  Standards authority; exact RC4 remains explicitly loaded.

## Scope

1. Record Q2/Q4/Q6 outcomes, commits, findings, verification facts, waivers, and residual risks.
2. Update the IIS-0009 runbook and qualification matrix so the proven CLI command and completed state
   are truthful.
3. Update the IIS-0010 feedback register and promotion handoff from 3/6 to the final observed state.
4. Add a concise representative/impacted-configuration rule to Brain Flow's loaded process contract
   and portable verification guidance. Do not create Android architecture standards in this iOS pack.
5. Preserve exact candidate identity: Q1-Q6 results qualify frozen RC4 `f7…`; any payload edit made by
   IIS-0011 is a post-freeze standards delta and must not be silently represented as part of `f7…`.
6. Run one joined final AI consistency review over the complete documentation/standards result and
   apply at most one reporting-only corrective batch.

## Exclusions

- No build, test, Bazel/Xcode/Gradle configuration probe, verification script, CI, custom kernel,
  receipt, evidence framework, or duplicate provider execution.
- No Q1-Q6 rerun and no routine re-review.
- No version bump, manifest/marketplace mutation, branch change, history rewrite, push, tag, publish,
  install, rollout, GA declaration, or inferred organization sign-off.
- No protected source, raw transcript, credentials, source URL, or adopter brand in committed records.

## Authority and review

- Auto mode and scoped local stage/commit authority are retained for IIS-0011 semantic tasks on the
  current worktree/branch.
- External Git/release operations and human/organization sign-offs remain separate.
- Requirements and plan require independent read-only auto-gate decisions before mutation.
- Documentation and SKILL text do not use TDD or executable verification. One final AI review is the
  only consistency event.

## Definition of Done

- [ ] Q1-Q6 have one truthful final matrix with exact frozen-candidate identity and `0/0` open
  candidate P0/P1.
- [ ] Q2 is recorded as passed without an executable signal because it changed bindings/adoption text
  only.
- [ ] Q4 and Q6 are recorded with the user-approved executable waiver and explicit residual risk;
  neither claims an unrun target-specific test.
- [ ] IIS-0009 commands omit empty setting sources and separate operator transport from Standards
  authority.
- [ ] Brain Flow selects representative/impacted configurations rather than exhaustive matrices,
  with risk-based expansion and iOS/Android examples.
- [ ] Promotion readiness, feedback state, sign-off prerequisites, external authority, and frozen-RC4
  versus post-freeze-delta identity are unambiguous.
- [ ] One joined final AI review is recorded; accepted in-scope findings, if any, are handled once.
- [ ] Each semantic task is committed with explicit path staging; unrelated `.superpowers/` files are
  untouched.

Work-item status: **IN PROGRESS — AUTO GATES APPROVED**

## Requirement Gate

- Mode: auto
- Reviewer: independent read-only agent `iis0011_auto_gate`
- Verdict: `AUTO_APPROVED`

STATUS: APPROVED
