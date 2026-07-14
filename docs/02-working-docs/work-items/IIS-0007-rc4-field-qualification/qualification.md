# RC4 qualification matrix

Candidate: `1.0.0-rc.4` at `f7cd2cf87711f1a757d2fbdec5be9be02ee69173`

| Row | Status | Open P0/P1/P2 | Primary blocker | Owner |
|---|---|---:|---|---|
| Q1 | Not qualified | 0/1/0 | Provider/Core-only Profile-routing failure | Qualification Owner + provider/Profile-routing owner |
| Q2 | Not qualified | 0/0/0 | Claude pre-inference 401 | Claude Qualification Owner + provider-authentication owner |
| Q3 | Passed | 0/0/0 | None | Codex Qualification Owner |
| Q4 | Not qualified | 0/0/0 | Claude pre-inference 401 | Claude Qualification Owner + provider-authentication owner |
| Q5 | Not qualified | 0/1/0 | Fixture test target does not compile; separate policy-owner boundaries remain | Qualification Owner + fixture/policy owners |
| Q6 | Not qualified | 0/0/0 | Claude pre-inference 401 | Claude Qualification Owner + provider-authentication owner |

Q1 and Q5 are qualification/fixture failures, not proven RC4 payload defects. Q5's provider-reported
preliminary P0 is preserved in the Codex record and dispositioned by the joined review; it is not
counted as a candidate P0. Q2/Q4/Q6 are external holds and do not imply provider compatibility.

Overall status: **NOT QUALIFIED** — 1 of 6 rows passed. RC4 remains unchanged and is not
qualification-complete. Public RC1, marketplace, installed plugin, remote refs, tags, and releases
remain unchanged.
