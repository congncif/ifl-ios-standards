# RC4 Claude local-provider qualification result

## Outcome

- Candidate: `1.0.0-rc.4` at `f7cd2cf87711f1a757d2fbdec5be9be02ee69173`.
- Runtime: Claude Code `2.1.207` through an operator-owned local-model transport.
- Q2/Q4/Q6 result: **PASSED**.
- Open candidate findings: P0/P1/P2 = `0/0/0`.

Normal setting sources supplied the configured transport; they did not supply Standards authority.
Every successful row explicitly loaded exact RC4 through `--plugin-dir`. Earlier pre-inference attempts
remain historical transport observations and are not candidate compatibility findings.

## Direct results

| Row | Baseline | Result commit(s) | Observed outcome | Executable disposition |
|---|---|---|---|---|
| Q2 | `8af9959876c1a130d9e6071d131f13f3a10138fe` | `0ada3e13d33529c92e41579a0aacafff9f36065d` | Incremental bindings/adoption migration; clean, no remote | N/A — text/binding-only task |
| Q4 | `6296c186812011be89e25429f387064e9dedc4a4` | `04d50855af14b4de89055446881166dcfe45730e` | Framework-neutral policy, focused tests, humble UIKit/SwiftUI adapters; clean, no remote | Repository wrapper reached Bazel analysis, then a pre-existing missing simulator runner stopped analysis; 0 tests ran. Explicit waiver accepted. |
| Q6 | `6296c186812011be89e25429f387064e9dedc4a4` | `3476c3c0a6ef421fbe52aca79c1d31c5aa19f54c`, `4793004bb025b47dba77d43709912fe5b1065835` | Portable binding migration, provider-native handoff/resume, one-writer ownership, UI-neutral public contract; clean, no remote | No build/test by explicit waiver. |

Q2 reported no candidate findings and separately reported `0/5/1` findings against the existing
adopter boundary. Q4 and Q6 reported no candidate P0/P1/P2. The accepted representative platform
signal is retained Q3's native `xcodebuild test` result, 5 tests with 0 failures. It does not prove Q4
or Q6 target-specific compilation/tests; that unobserved coverage remains an explicit residual owned by
the Qualification Owner. The selected Standards and Release decision owners must explicitly accept or
resolve it before promotion.

No row is rerun. No candidate mutation, persistent provider/plugin change, push, tag, release,
marketplace update, install, rollout, GA declaration, or organization risk acceptance occurred.
