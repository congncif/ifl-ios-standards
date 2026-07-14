# RC4 qualification matrix after direct-provider closeout

Candidate: `1.0.0-rc.4` at `f7cd2cf87711f1a757d2fbdec5be9be02ee69173`

| Row | Exact result identity | Final signal / disposition | Status | Open candidate P0/P1/P2 |
|---|---|---|---|---:|
| Q1 | `3cd7fa84c2d00e1bf7ee9942df02eda63d78ecef` | `swift test`: 9 tests, 0 failures | Passed; retained | 0/0/0 |
| Q2 | `0ada3e13d33529c92e41579a0aacafff9f36065d` | N/A — bindings/adoption text only | Passed | 0/0/0 |
| Q3 | `e3921c0545ce5de3684d9d9d17f2ba47aefab0f1` | Native `xcodebuild test`: 5 tests, 0 failures | Passed; retained | 0/0/0 |
| Q4 | `04d50855af14b4de89055446881166dcfe45730e` | Explicit waiver; retained Q3 is the accepted platform signal | Passed under waiver | 0/0/0 |
| Q5 | `69556d8815e5c05f79cc4a0aa6d11130be9ae0fa` | Package test: 8 tests, 0 failures | Passed; retained | 0/0/0 |
| Q6 | `3476c3c0a6ef421fbe52aca79c1d31c5aa19f54c`, `4793004bb025b47dba77d43709912fe5b1065835` | Explicit waiver; retained Q3 is the accepted platform signal | Passed under waiver | 0/0/0 |

Overall: **QUALIFIED — 6/6 rows passed for frozen RC4.** Q2 also reported `0/5/1` findings against the
existing adopter boundary; those are not candidate findings. The Q3 native signal does not prove Q4 or
Q6 target-specific compilation/tests. Their unobserved coverage remains an explicit residual owned by
the qualification/release decision boundary.

This result qualifies only frozen RC4 `f7cd2cf…`; it does not transfer to later Standards deltas. It is
not a sign-off, GA declaration, or external release authority.
