# Final report — IIS-0009 RC4 Claude direct-CLI handoff

## Outcome

The automated portion of IIS-0009 is closed. Exact RC4 and three clean isolated fixtures are ready, and
the direct operator path is frozen in `CLAUDE-CLI-RUNBOOK.md` with self-contained Q2/Q4/Q6 prompts.

RC4 remains **NOT QUALIFIED at 3/6**. No Claude row reached inference during automated attempts, so no
provider compatibility, skill behavior, code change, commit, or executable signal is inferred. Q1, Q3,
and Q5 remain valid passes against unchanged RC4.

## Semantic history

- Plan: `70a3e99fbe415642acba9e65a736dd19e8338420`.
- Direct-CLI handoff: `e9828ddf372e9027b29645b51dc6767c0fe23bed`.
- Joined review/reporting closeout: the commit containing this report.
- Candidate: `f7cd2cf87711f1a757d2fbdec5be9be02ee69173`; no payload diff through closeout.

## Review result

One joined review found no candidate P0/P1/P2 and one reporting P2. The single reporting correction
batch reconciled automated versus direct operator state, corrected Task 2 status, strengthened preflight,
and made prompts self-contained. No re-review, provider retry, build/test, or duplicate signal followed.

## Remaining qualification boundary

The operator runs Q2, Q4, and Q6 sequentially using `CLAUDE-CLI-RUNBOOK.md` and returns only the bounded
result blocks. Until all three pass with no open P0/P1, do not collect promotion sign-offs or claim
provider compatibility/GA. Startup/auth/local-router details remain operator-local and are not Standards
findings.

After qualifying results arrive, ingest them in one bounded result-closeout change, perform its one
joined review, then move to RC feedback and named sign-offs. Do not rerun Q1/Q3/Q5.

No candidate/public RC1 mutation, remote change, push, tag, release, marketplace update, install,
rollout, GA declaration, organization-policy decision, CI, verifier, receipt, or custom kernel occurred.
