# RC4 promotion-readiness handoff

## Current state

| Item | State |
|---|---|
| Immutable candidate | `1.0.0-rc.4` at `f7cd2cf87711f1a757d2fbdec5be9be02ee69173` |
| Candidate payload since freeze | Unchanged |
| Published baseline | `v1.0.0-rc.1` |
| Qualification | **QUALIFIED — 6/6 for frozen RC4 only** |
| Passed rows | Q1-Q6; Q4/Q6 use the explicit representative-platform-signal waiver |
| Pending rows | None |
| Retained verification residual | Q4/Q6 target-specific compilation/tests unobserved; Q3 native 5/0 does not prove them; Qualification Owner owns the residual pending explicit Standards/Release acceptance or resolution |
| Exact promotion target | **UNSET — choose frozen `f7cd2cf…` or a later versioned candidate** |
| Open candidate P0/P1 | `0/0` |
| Open owned P2 | Frozen release-status snapshot; defer to promotion metadata plan |
| External RC feedback | **UNOBSERVABLE — exact RC4 has no authorized external review surface** |
| Sign-offs | Not requested; ordering gate not met |
| External release authority | Not granted |

## Required sequence

1. **Close IIS-0011:** ingest the completed direct results and run its one joined final AI review. Do
   not rerun Q1-Q6 or duplicate platform signals.
2. **Close feedback scope:** Standards Owner designates the internal feedback register as sufficient or
   authorizes an exact candidate review surface, then dispositions any newly observable feedback.
3. **Choose the exact promotion target:** select frozen RC4 `f7cd2cf…` or freeze a later versioned
   candidate containing post-freeze standards deltas. For a later candidate, record an explicit
   qualification-impact and affected-requalification decision; never transfer RC4's 6/6 silently.
4. **Request named sign-offs:** only for the selected immutable target and with the waiver residuals
   visible. Readiness below is not approval.
5. **Prepare promotion metadata:** in a separate approved plan, move version/manifests/release notes and
   status text to the exact approved GA or next-RC identity. Include `RC4-FB-004` correction.
6. **Obtain exact external authority:** every operation/identifier in the template below must be filled
   and approved by its accountable owner.
7. **Execute only authorized operations:** omitted fields remain prohibited. Report observed results and
   rollback posture without silently replacing an existing version.

## Sign-off readiness map — mapping only, no requests or approvals

| Role | Current readiness | Blocking prerequisite |
|---|---|---|
| Standards Owner | BLOCKED | Feedback-scope disposition, P2 metadata decision, and exact target selection |
| Canon Maintainer | NOT REQUESTED | Exact target unresolved |
| Enterprise Adoption Owner | READY TO REQUEST FOR FROZEN RC4 | 6/6 observed; Q4/Q6 residuals must remain visible |
| Claude Qualification Owner | READY TO REQUEST FOR FROZEN RC4 | Direct Q2/Q4/Q6 complete; exact target still required |
| Codex Qualification Owner | READY TO REQUEST FOR FROZEN RC4 | Retained Q1/Q3/Q5 complete; exact target still required |
| Applicable Organization Policy Owners | NOT REQUESTED | Q5/Q6 policy domains require owned approve/N/A decisions for the selected target |
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

- Any incomplete IIS-0011 closeout, candidate P0/P1, unowned P2, unresolved feedback-scope or exact
  target decision, missing/conditional sign-off, or `UNSET` authority field stops promotion.
- Candidate correction means a new immutable revision and affected requalification; never patch RC4
  silently.
- No custom kernel, verifier, receipt/evidence framework, CI, release script, or recurring register is
  introduced by this handoff.
