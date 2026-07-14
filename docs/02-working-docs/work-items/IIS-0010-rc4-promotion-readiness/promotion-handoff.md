# RC4 promotion-readiness handoff

## Current state

| Item | State |
|---|---|
| Immutable candidate | `1.0.0-rc.4` at `f7cd2cf87711f1a757d2fbdec5be9be02ee69173` |
| Candidate payload since freeze | Unchanged |
| Published baseline | `v1.0.0-rc.1` |
| Qualification | **NOT QUALIFIED — 3/6** |
| Passed rows | Q1, Q3, Q5 |
| Pending rows | Q2, Q4, Q6 direct operator CLI |
| Open candidate P0/P1 | `0/0` |
| Open owned P2 | Frozen release-status snapshot; defer to qualification-complete/GA metadata plan |
| External RC feedback | **UNOBSERVABLE — exact RC4 has no authorized external review surface** |
| Sign-offs | Not requested; ordering gate not met |
| External release authority | Not granted |

## Required sequence

1. **Complete qualification:** run Q2/Q4/Q6 sequentially through the direct runbook in IIS-0009 and
   return only bounded results. Retain Q1/Q3/Q5; do not rerun them.
2. **Close the matrix:** ingest direct results once and run that result plan's one joined review. Any
   candidate P0/P1 creates a new candidate revision and affected requalification; otherwise require 6/6.
3. **Close feedback scope:** Standards Owner designates the internal feedback register as sufficient or
   authorizes an exact candidate review surface, then dispositions any newly observable feedback.
4. **Only after 6/6 with no open P0/P1:** request the named sign-offs below. Do not collect them early.
5. **Prepare promotion metadata:** in a separate approved plan, move version/manifests/release notes and
   status text to the exact approved GA or next-RC identity. Include `RC4-FB-004` correction.
6. **Obtain exact external authority:** every operation/identifier in the template below must be filled
   and approved by its accountable owner.
7. **Execute only authorized operations:** omitted fields remain prohibited. Report observed results and
   rollback posture without silently replacing an existing version.

## Sign-off readiness map — mapping only, no requests or approvals

| Role | Current readiness | Blocking prerequisite |
|---|---|---|
| Standards Owner | BLOCKED | 6/6, feedback-scope disposition, P2 metadata decision, exact version decision |
| Canon Maintainer | NOT REQUESTED | Sign-off phase cannot start before 6/6/no open P0/P1 |
| Enterprise Adoption Owner | BLOCKED | Q2/Q4/Q6 provider/profile/build/adoption outcomes unobserved |
| Claude Qualification Owner | BLOCKED | Direct Q2/Q4/Q6 results pending |
| Codex Qualification Owner | NOT REQUESTED | Codex rows pass, but collection order remains gated by 6/6 |
| Applicable Organization Policy Owners | NOT REQUESTED | Qualification first; Q5 and Q6 policy domains then require owned approve/N/A decisions |
| DevOps/Release Owner | NOT REQUESTED | Qualification, feedback, sign-offs, metadata candidate, and exact operation set first |
| Legal Owner, when distribution/license scope requires | NOT REQUESTED | Exact distribution/license scope and DevOps release handoff first |

One person may hold multiple roles, but every decision right must be recorded separately. AI review,
tests, commits, candidate approval, or this handoff cannot substitute for a human/organization sign-off.

## External-release authority template — all fields currently UNSET

| Required authority field | Exact value / decision |
|---|---|
| Immutable candidate commit | UNSET |
| Authorized version | UNSET |
| Target branch | UNSET |
| Target remote | UNSET |
| Push authorization for exact branch/commit | UNSET |
| Merge authorization and exact source/target | UNSET |
| Is target consumed by an unpinned public channel? | UNSET |
| Distribution/marketplace authority if push or merge is public-consumed | UNSET |
| Exact tag | UNSET |
| Local tag creation authorized? | UNSET |
| Remote tag push authorized? | UNSET |
| Release host/repository | UNSET |
| Draft release creation authorized? | UNSET |
| Release publication authorized? | UNSET |
| Provider marketplace entries and exact version/ref changes | UNSET |
| Local plugin install/update authorized and target scope | UNSET |
| Staged rollout authorized and target scope | UNSET |
| General availability declaration/rollout authorized | UNSET |
| Authorized operator | UNSET |
| Time/scope constraints | UNSET |
| Rollback/de-promotion target and accountable owner | UNSET |
| Legal Owner approval required for license/distribution scope? | UNSET |
| Legal Owner decision, when required | UNSET |

This table is a handoff template, not authority. `UNSET` means prohibited. A default-branch push or merge
that can distribute the plugin requires both remote-Git and marketplace/release authority.

## Stop conditions

- Any open Q2/Q4/Q6 result, candidate P0/P1, unowned P2, unresolved feedback-scope decision, missing or
  conditional sign-off, or `UNSET` authority field stops promotion.
- Candidate correction means a new immutable revision and affected requalification; never patch RC4
  silently.
- No custom kernel, verifier, receipt/evidence framework, CI, release script, or recurring register is
  introduced by this handoff.
