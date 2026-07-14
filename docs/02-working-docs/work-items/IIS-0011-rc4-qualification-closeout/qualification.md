# IIS-0011 frozen RC4 qualification ledger

## Qualified candidate

- Version: `1.0.0-rc.4`.
- Immutable payload: `f7cd2cf87711f1a757d2fbdec5be9be02ee69173`.
- Overall result: **QUALIFIED — Q1-Q6 6/6**.
- Open candidate findings: P0/P1/P2 = `0/0/0`.

## Final scenario matrix

| Row | Provider result identity | Executable evidence or disposition | Result |
|---|---|---|---|
| Q1 | `3cd7fa84c2d00e1bf7ee9942df02eda63d78ecef` | `swift test`: 9 tests, 0 failures | PASS — retained |
| Q2 | `0ada3e13d33529c92e41579a0aacafff9f36065d` | N/A — bindings/adoption text only | PASS |
| Q3 | `e3921c0545ce5de3684d9d9d17f2ba47aefab0f1` | Native `xcodebuild test`: 5 tests, 0 failures | PASS — retained |
| Q4 | `04d50855af14b4de89055446881166dcfe45730e` | Explicit representative-signal waiver | PASS under waiver |
| Q5 | `69556d8815e5c05f79cc4a0aa6d11130be9ae0fa` | Package test: 8 tests, 0 failures | PASS — retained |
| Q6 | `3476c3c0a6ef421fbe52aca79c1d31c5aa19f54c`, `4793004bb025b47dba77d43709912fe5b1065835` | Explicit representative-signal waiver | PASS under waiver |

## Direct-row dispositions

- **Q2:** exact RC4 and Brain Flow were observed. The incremental bindings/adoption migration produced
  one semantic commit, a clean no-remote fixture, and no executable signal because no executable code
  changed. Candidate findings were `0/0/0`. A separate `0/5/1` adopter-boundary review result remains
  adopter work and is not a candidate defect.
- **Q4:** exact RC4 and the applicable Core/UIKit/SwiftUI guidance were observed. One semantic commit
  contains the bounded policy/adapters/tests change. The repository wrapper reached Bazel analysis,
  then a pre-existing missing simulator runner stopped analysis; 0 tests ran. The user accepted retained
  Q3 native iOS 5/0 as the representative platform signal and waived further nonstandard-graph work.
  This does not prove Q4 target-specific compilation/tests.
- **Q6:** exact RC4, Boardy/VIP, mixed UI, applicable enterprise guidance, provider-native
  handoff/resume, and one-writer ownership were observed. Two semantic commits contain the bindings and
  public-contract changes. The user accepted the same retained Q3 signal and waived target execution.
  No Q6 build/test ran; Q6 target-specific compilation/tests are unproven.

For both waivers, the Qualification Owner owns the residual target coverage. The selected Standards
and Release decision owners must explicitly accept or resolve it before promotion. The known
nonstandard build graph is not an RC4 candidate defect. No row is rerun and no duplicate green signal
is manufactured.

## Transport and authority

The successful direct CLI command omitted empty setting sources. Normal operator settings supplied the
configured local-model transport only. Exact RC4 loaded explicitly through `--plugin-dir` and remained
the sole Standards authority. Authentication/configuration details and raw transcripts are not retained.

## Identity and release boundary

This matrix qualifies only frozen RC4 `f7cd2cf…`. IIS-0011 edits to Brain Flow, process guidance, or
working documents are post-freeze deltas and do not inherit this qualification. The later promotion
handoff must choose frozen RC4 or freeze a new versioned candidate and record its qualification-impact
decision. This ledger is not a sign-off, GA declaration, or external release authority.
