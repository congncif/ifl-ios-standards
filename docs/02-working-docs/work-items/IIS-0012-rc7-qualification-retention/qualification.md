# IIS-0012 RC7 qualification-retention closeout

## Decision

- Previously qualified baseline: `1.0.0-rc.4` at
  `f7cd2cf87711f1a757d2fbdec5be9be02ee69173`.
- Engineering-complete candidate: `1.0.0-rc.7` at
  `2fc508b8d943fe4ef439bdcbbd86585e398cc513`.
- Decision date: 2026-07-14.
- Explicit task-owner direction: do not repeat Q1-Q6 or manufacture duplicate green signals solely
  because the candidate identifier changed. Retain the completed gates through this recorded impact
  decision and close the engineering objective.
- Overall result: **QUALIFIED BY EXPLICIT IMPACT RETENTION — Q1-Q6 6/6**.
- Open candidate findings: P0/P1 = `0/0`.

This record is the post-freeze qualification decision. It intentionally sits outside the frozen
plugin payload, so recording the decision does not mutate RC7 and trigger another candidate reset.

## RC4 to RC7 impact

The exact `f7cd2cf…2fc508b` range was classified before retention:

- no Canon chapter, Rule, ADR, Profile, enterprise chapter, Boardy architecture/IO specification, or
  executable iOS product implementation changed;
- Brain skills gained Codex path portability and native generic-subagent routing with inline fallback;
- review and verification guidance converged on one joined review, one corrective batch, and the
  smallest representative configuration set;
- `ifl-init` retained the twin binding contract, stopped offering unsupported Codex custom profiles,
  preserves adopter-owned `.codex/agents`, and returns 64 for the retired flag;
- remaining changes are version/package metadata, install/runbook/release text, and working records.

The changed surfaces refine provider operation and remove unsupported unpublished RC5/RC6 behavior;
they do not invalidate the architecture, UI, service, enterprise, or build-scenario outcomes already
observed for RC4. The user-provided RC6 Claude smoke additionally observed Brain Flow load, 9/9 Claude
agents, single-pass Boardy review, no P0/P1, and no release crossing. It is supporting context, not a
claim that Q2, Q4, or Q6 were rerun.

The final RC7 corrective task had a focused 5/5 signal for shell syntax, twin bindings, no new
`.codex` output, preservation of existing agent files, and retired-flag exit 64. Its joined review
reported no principal findings and one mechanical P2, corrected at `2fc508b`; no routine re-review
followed.

## Retained qualification matrix

| Row | Qualified evidence identity | RC7 impact disposition | Result |
|---|---|---|---|
| Q1 | `3cd7fa84c2d00e1bf7ee9942df02eda63d78ecef`; Swift 9/0 | Core and SwiftPM behavior unchanged; Codex routing is provider-native and no custom profile is required | PASS — retained |
| Q2 | `0ada3e13d33529c92e41579a0aacafff9f36065d`; binding-only | Claude agents, Boardy/UIKit boundaries, CocoaPods adoption, and binding schema unchanged | PASS — retained |
| Q3 | `e3921c0545ce5de3684d9d9d17f2ba47aefab0f1`; native iOS 5/0 | Boardy IO/composition and SwiftUI humble-state guidance unchanged; only Codex routing/review cadence changed | PASS — retained |
| Q4 | `04d50855af14b4de89055446881166dcfe45730e`; representative-signal waiver | Mixed-UI/application policy unchanged; lean verification now makes the existing waiver boundary explicit | PASS — waiver retained |
| Q5 | `69556d8815e5c05f79cc4a0aa6d11130be9ae0fa`; package 8/0 | Enterprise chapters and migration/conformance policy unchanged; Codex delegation mapping only | PASS — retained |
| Q6 | `3476c3c0a6ef421fbe52aca79c1d31c5aa19f54c`, `4793004bb025b47dba77d43709912fe5b1065835`; representative-signal waiver | Boardy, mixed-UI, enterprise, authority, and handoff obligations unchanged; joined-review cadence clarified | PASS — waiver retained |

## Residuals and boundary

Q4 Bazel-target compilation/tests and Q6 target-specific compilation/tests remain unproven. Their
existing representative-signal waivers and residual target coverage are retained exactly; this
closeout does not relabel either omitted target as observed. The Qualification Owner continues to own
that residual until the Standards/Release decision accepts or resolves it.

No build, test, provider CLI, or qualification row was rerun for this reporting-only closeout. No
branch merge, push, tag, publication, marketplace change, installation, rollout, GA declaration, or
organization risk acceptance is implied. Those external operations remain separately authorized
release work.
