# Final report — IIS-0007 RC4 field qualification

## Outcome

IIS-0007 is complete as a truthful **NOT QUALIFIED** result. Exact-candidate Codex execution is now
observed, and Q3 passed, but Q1 failed Core-only provider routing, Q5 failed to compile its test target,
and all three Claude rows stopped on pre-inference authentication. RC4 cannot be signed off or
promoted.

The joined review found no proven candidate P0/P1/P2. That attribution is intentionally narrower than
release readiness: five unpassed rows still block qualification, regardless of whether their root
cause is candidate payload, provider behavior, fixture execution, or external authentication.

## Definition of Done

- D1-D7: **COMPLETE** — exact candidate/session isolation and truthful Q1-Q6 dispositions are
  recorded; no provider result was substituted or inferred.
- D8: **COMPLETE** — findings, failed/green signals, corrective signals after real code mutation, and
  materially different Full Access recoveries are explicit; no unchanged duplicate signal or hidden
  P0/P1 remains.
- D9: **COMPLETE** — semantic task commits and one joined review produce a conclusive 1/6 matrix and
  accountable owners.
- D10: **COMPLETE** — qualification did not change public RC1, remote refs, tags, releases,
  marketplace, installed plugin, or GA state.

The IIS-0007 work-item DoD is complete because its purpose was truthful disposition. Standards 1.0
qualification/GA readiness is not complete.

## History

- Planning baseline: `586c6ebc20e6be943fa3e163a4f05d6939296489`.
- Codex result: `dea68ee5071035939e8a86150dc7f59a77ed55bf`.
- Claude result: `b7a700b871a1ec2151d5f11b22f28e5aca332f82`.
- Joined review and reporting-only closeout: the commit containing this report; its SHA resolves from
  Git history after commit and does not redefine immutable candidate `f7cd2cf…`.

## Next boundary

The Qualification Owner should open one bounded follow-up qualification plan that:

1. reproduces Q1 under an explicit Core-only route to isolate provider/session behavior from a
   candidate guidance defect;
2. corrects only the Q5 fixture test compile error and reruns the one affected executable signal;
3. executes Q2/Q4/Q6 only after the provider-authentication owner restores Claude access, without
   repeating the current 401 action.

If Q1 establishes a semantic RC4 defect, the Standards Owner must open a separate approved candidate
correction and increment the candidate before affected requalification. No candidate mutation is
justified by IIS-0007 alone.

No push, tag, publication, marketplace change, persistent install, rollout, GA declaration, or
organization risk acceptance occurred. Published RC1 remains unchanged.
