# RC4 qualification matrix after IIS-0009 handoff

Candidate: `1.0.0-rc.4` at `f7cd2cf87711f1a757d2fbdec5be9be02ee69173`

| Row | Status | Open candidate P0/P1/P2 | Next boundary |
|---|---|---:|---|
| Q1 | Passed | 0/0/0 | Retained; no rerun |
| Q2 | Not qualified — direct CLI pending | 0/0/0 | Run `prompts/q2.md` through the runbook |
| Q3 | Passed | 0/0/0 | Retained; no rerun |
| Q4 | Not qualified — direct CLI pending | 0/0/0 | Run `prompts/q4.md` through the runbook |
| Q5 | Passed | 0/0/0 | Retained; policy-owner handoff still applies |
| Q6 | Not qualified — direct CLI pending | 0/0/0 | Run `prompts/q6.md` through the runbook |

Overall: **NOT QUALIFIED — 3/6 rows passed**. Automated pre-inference startup observations neither pass
nor fail candidate semantics. Direct results must satisfy the row-specific pass boundaries before this
matrix changes.

RC4 remains unchanged and unpublished. Public RC1, marketplace, installed plugin, remote refs, tags,
releases, rollout, organization policy, and GA state remain unchanged.
