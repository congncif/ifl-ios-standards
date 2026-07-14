# RC4 qualification matrix after IIS-0008

Candidate: `1.0.0-rc.4` at `f7cd2cf87711f1a757d2fbdec5be9be02ee69173`

| Row | Status | Open P0/P1/P2 | Primary blocker | Owner |
|---|---|---:|---|---|
| Q1 | Passed | 0/0/0 | None | Codex Qualification Owner |
| Q2 | Not qualified | 0/0/0 | Claude pre-inference 401 | Claude Qualification Owner + provider-authentication owner |
| Q3 | Passed — retained | 0/0/0 | None | Codex Qualification Owner |
| Q4 | Not qualified | 0/0/0 | Claude pre-inference 401 | Claude Qualification Owner + provider-authentication owner |
| Q5 | Passed | 0/0/0 | None; organization policy handoff remains for adopter promotion | Codex Qualification Owner + applicable policy owners |
| Q6 | Not qualified | 0/0/0 | Claude pre-inference 401 | Claude Qualification Owner + provider-authentication owner |

Historical Q1 and Q5 failures are closed as fixture issues; neither is a candidate defect. Q5 passing
the qualification scenario does not accept the adopter's separately human-owned promotion risks.
Q2/Q4/Q6 are external holds and do not imply Claude compatibility.

Overall status: **NOT QUALIFIED — 3/6 rows passed**. RC4 remains unchanged, unpublished, and not
qualification-complete. Public RC1, marketplace, installed plugin, remote refs, tags, and releases
remain unchanged.
