# RC3 qualification matrix

Candidate: `1.0.0-rc.3` at `521c7a4ee939bb96f3f67a75050f71f5d13416a1`

| Row | Status | Open P0/P1/P2 | Primary blocker | Owner |
|---|---|---:|---|---|
| Q1 | Not qualified | 0/0/0 | Provider environment hold | Qualification Owner + tenant/provider policy owner |
| Q2 | Not qualified | 0/1/0 | Provider hold; inherited `F-RC3-QUAL-001` | Qualification Owner + Standards Owner |
| Q3 | Not qualified | 0/1/0 | Provider hold; observed `F-RC3-QUAL-001` | Qualification Owner + Standards Owner |
| Q4 | Not qualified | 0/0/0 | Provider environment hold; early candidate stop | Qualification Owner + tenant/provider policy owner |
| Q5 | Not qualified | 0/0/0 | Provider environment hold | Qualification Owner + tenant/provider policy owner |
| Q6 | Not qualified | 0/1/0 | Provider hold; inherited `F-RC3-QUAL-001` | Qualification Owner + Standards Owner |

Q2, Q3, and Q6 refer to one deduplicated candidate finding, not three defects. Trusted internal
rehearsals supplied diagnostic observations only and do not change any row to passed.

Overall status: **NOT QUALIFIED**. Public RC1, marketplace state, and every release/promotion boundary
remain unchanged.
