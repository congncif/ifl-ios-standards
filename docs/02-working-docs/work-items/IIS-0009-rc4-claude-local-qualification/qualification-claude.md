# RC4 Claude local-provider qualification handoff

## Outcome

- Candidate: `1.0.0-rc.4` at `f7cd2cf87711f1a757d2fbdec5be9be02ee69173`
- Runtime inspected: Claude Code `2.1.207` with an operator-owned local-model transport
- Q2/Q4/Q6 result: **NOT QUALIFIED — manual direct-CLI handoff ready**
- Candidate findings: P0/P1/P2 = `0/0/0`

The first isolated-state invocation for each row stopped before inference with zero model tokens and no
permission denial. One shared-state candidate-load probe then reached the configured local endpoint but
also stopped before inference with HTTP 401. No row loaded a Standards skill, received fixture source,
mutated a fixture, created a commit, or ran a build/test signal.

These are operator-local transport observations, not RC4 compatibility findings. Per user direction,
automated transport investigation ended. `CLAUDE-CLI-RUNBOOK.md` and `prompts/q2.md`, `q4.md`, and
`q6.md` now provide the direct operator path. Authentication details, provider configuration, raw
transcripts, source URLs, and adopter identities are intentionally not recorded.

## Frozen fixture state

| Row | Baseline/HEAD after automated stop | Changed paths | New commits | Final signal |
|---|---|---:|---:|---:|
| Q2 | `8af9959876c1a130d9e6071d131f13f3a10138fe` | 0 | 0 | N/A — no code task began |
| Q4 | `6296c186812011be89e25429f387064e9dedc4a4` | 0 | 0 | 0 — no code task began |
| Q6 | `6296c186812011be89e25429f387064e9dedc4a4` | 0 | 0 | 0 — no code task began |

All three fixtures remained clean and have no remote configured. The read-only candidate clone remained
at exact RC4.

## Qualification boundary

Q1, Q3, and Q5 remain passed against unchanged RC4. Q2, Q4, and Q6 remain unpassed until direct CLI
execution returns the bounded results requested by the runbook. A pre-inference local transport failure
does not consume the row's one final executable signal and does not justify provider substitution.

No candidate mutation, public/installed RC1 change, push, tag, release, marketplace update, persistent
plugin/provider configuration change, rollout, GA declaration, or organization risk acceptance occurred.
