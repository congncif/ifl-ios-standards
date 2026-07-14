# Final report — IIS-0008 RC4 targeted requalification

## Outcome

IIS-0008 is complete. Q1 and Q5 now pass against exact immutable RC4, joining retained Q3. The
candidate has no open proven P0/P1/P2, but remains **NOT QUALIFIED** at 3/6 because all Claude rows are
blocked before inference by external authentication.

The controlled Q1 reproduction showed that the prior Boardy route came from an unbound fixture, not a
proven payload defect. The focused Q5 recovery showed that the failed signal came from one fixture test
assertion, not RC4. Neither result required a candidate mutation.

## Definition of Done

- D1-D5: **COMPLETE** — approved exact-candidate isolation, explicit Q1 binding, Q1/Q5 passes, retained
  Q3, and unchanged Claude holds are recorded.
- D6: **COMPLETE** — one joined review closed both historical fixture findings with no open candidate
  finding.
- D7: **COMPLETE** — planning, Q1, Q5, and closeout are separate semantic commits; unrelated paths
  remain untouched.
- D8: **COMPLETE** — the matrix states 3/6 and does not claim qualification or GA.
- D9: **COMPLETE** — no external, public, provider-authentication, or organization-policy state
  changed.

## History

- IIS-0007 predecessor closeout: `abfca60ac8d3160a01bd50b09643cd97739c899d`.
- IIS-0008 plan: `336a4af3e591939873c603558cf760a8e014d799`.
- Q1 result: `1c9efe0d8adc5b54ed03040bb2770aa80f90ec42`.
- Q5 result: `ee47e08f8947730bb1d73a2fb4db9956fb6ec78f`.
- Joined review and reporting closeout: the commit containing this report; it does not redefine
  immutable candidate `f7cd2cf…`.

## Remaining boundary

Only Q2, Q4, and Q6 remain. The Claude Qualification Owner and provider-authentication owner must
restore a valid provider session before those rows can execute. Until that external state changes,
do not repeat the 401 probe and do not substitute Codex.

After authentication changes, open one bounded Claude qualification plan against the same immutable
candidate, run the three required provider-native rows, and perform that plan's one joined review. If
all pass, proceed to the required human/organization sign-offs and separately authorized release
operation; otherwise disposition findings without claiming GA.

No push, tag, publication, marketplace change, persistent install, rollout, GA declaration, or
organization risk acceptance occurred. Published RC1 remains unchanged.
