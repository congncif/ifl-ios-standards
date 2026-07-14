# Requirements — IIS-0010 RC4 promotion readiness

## Meta

- Created: 2026-07-14
- Flow mode: auto
- Immutable candidate: `1.0.0-rc.4` at
  `f7cd2cf87711f1a757d2fbdec5be9be02ee69173`
- Current qualification: Q1/Q3/Q5 passed; Q2/Q4/Q6 direct CLI execution pending
- Published baseline: `v1.0.0-rc.1`
- Verification: one joined AI review over the complete documentation result; no build/test, script,
  verifier, CI, receipt, or custom kernel

## Goal

Create one lean promotion-readiness handoff outside the immutable plugin payload. Consolidate observed
RC feedback and its disposition, the externally visible feedback-surface audit, the exact qualification
state, required sign-off decisions, and the external-release authority fields. Make every remaining
owner/action explicit without mutating RC4, fabricating approval, or creating a release system.

## Requirements

1. **Feedback register:** record every material RC4 qualification/review observation with candidate,
   source/reporter class, accountable triage owner, affected scenario, impact/severity, disposition,
   rationale, next owner, and state. Deduplicate historical fixture/provider symptoms from candidate
   defects.
2. **External feedback truth:** record only what the read-only origin audit proves: exact RC4 is not
   remotely addressable and therefore has no inspectable external review surface. Do not infer whether
   unobservable external feedback exists. Classify it as
   `UNOBSERVABLE — candidate has no authorized review surface`, never as absent, zero feedback, or pass.
3. **Current matrix:** retain Q1/Q3/Q5 and mark Q2/Q4/Q6 `NOT QUALIFIED — direct CLI pending`. No startup
   transport observation is a candidate finding or provider-compatibility signal.
4. **Metadata drift:** disposition the frozen payload statement that all RC4 rows are unqualified as a
   conservative P2 status snapshot now stale relative to the 3/6 ledger. Do not edit immutable RC4;
   carry the correction into the later qualification-complete/GA metadata plan.
5. **Sign-offs:** list every role required by `RELEASE.md` and its current readiness. At 3/6 this work
   may map readiness only; it must not request or collect a sign-off. Sign-off collection begins only
   after Q2/Q4/Q6 pass with no open P0/P1. A missing, conditional, AI-inferred, or organization-policy
   decision remains `NOT REQUESTED` or `BLOCKED`, never approval.
6. **External authority:** provide one exact-operation handoff template covering candidate/version,
   branch/remote and push/merge authorization, unpinned-public-channel distribution effect, tag
   create/push, release host/publication, marketplace refs, install/rollout, operator/time limits,
   rollback owner, and conditional Legal Owner approval for license/distribution scope. Leave every
   unauthorized field explicitly unset.
7. **Boundary:** no payload/version/manifest/marketplace change, push, tag, release, install, rollout,
   GA declaration, organization risk acceptance, or feedback-surface publication occurs.
8. **Privacy and YAGNI:** use neutral fixture/source aliases and repository-safe summaries. Do not copy
   adopter brand, source URL, protected source, raw transcript, credentials, provider config, or build
   logs. Create only Markdown working documents; no new schema, registry, automation, script, or
   recurring process.

## Definition of Done

- [x] **D1 — Exact state.** Handoff identifies immutable RC4, public RC1, 3/6 matrix, and no payload
  change.
- [x] **D2 — Feedback is dispositioned.** Every observed RC4 item has one deduplicated disposition and
  owner; no candidate P0/P1/P2 is hidden.
- [x] **D2a — Intake fields are complete.** Every row records provider, Profiles/chapters, build system,
  adoption mode, expected/actual behavior, affected authority artifact, and security/privacy/legal
  relevance, using explicit neutral `N/A` where a field does not apply.
- [x] **D3 — External visibility is honest.** Missing RC4 review surface is `UNOBSERVABLE`, not a pass.
- [x] **D4 — Promotion owners are explicit.** Qualification, feedback surface, sign-offs, metadata, and
  release authority each have their next owner and prerequisite.
- [x] **D5 — No approval is fabricated.** Human/policy/release decisions remain pending until recorded by
  their accountable owners.
- [x] **D6 — Review converges once.** One joined AI review covers the complete bundle; at most one
  reporting-only correction batch follows and no routine re-review occurs.
- [x] **D7 — Scope/history are clean.** Work uses semantic explicit-path commits, preserves
  `.superpowers/`, and performs no executable or external release operation.

Work-item status: **COMPLETE — PROMOTION HANDOFF READY; RC4 NOT QUALIFIED (3/6)**

## Requirement Gate

- Mode: auto
- Reviewer: independent agent `iis0010_plan_gate`
- Verdict: AUTO_APPROVED after retaining four release-governance amendments

STATUS: APPROVED
