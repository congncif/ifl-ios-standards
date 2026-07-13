# RC2 Qualification and GA Promotion

Target: `1.0.0-rc.2` working candidate

State: unpublished; not approved or represented as `1.0.0` GA

Published marketplace baseline: `v1.0.0-rc.1` until a separate RC2 release is authorized and exists

## Boundary

Engineering completion establishes that the approved RC2 content plan and its one joined AI
consistency review are complete. It does not authorize a branch merge, push, tag, GitHub release,
marketplace change, plugin installation, rollout, or GA declaration. Field qualification and the
sign-offs below are additional promotion inputs, not hidden steps inside Brain-Flow.

No release stage requires a pack-owned verifier, receipt/evidence system, CI implementation, release
script, or custom workflow state. Qualification uses provider-native task state, the candidate commit,
ordinary adopter commands when executable product code is affected, and accountable human decisions.

## Candidate sequence

1. Complete one approved RC2 engineering plan through semantic task commits, exactly one joined final
   AI review, and at most one in-scope corrective batch.
2. Freeze the candidate commit and identify its version, commit SHA, included paths, and published
   baseline. Do not move the public RC1 marketplace reference.
3. Intake and disposition RC feedback against that exact candidate.
4. Complete every required field-qualification row and resolve its P0/P1 findings.
5. Collect the named sign-offs. A conditional or missing sign-off is not approval.
6. Obtain a separate external-release authorization containing the exact operations and identifiers.
7. Only then may the authorized release operator perform those operations and report observed results.

A finding that materially changes scope, architecture, public contracts, security, or authority starts
a new approved plan and a new candidate revision. It is not hidden inside release cleanup.

## RC feedback intake and disposition

The Standards Owner designates an organization-owned issue tracker or review register for feedback.
Each report records:

- candidate version and exact commit;
- reporter and accountable triage owner;
- provider, selected Profiles, enterprise chapters, build system, and migration mode;
- reproducible scenario, expected/actual behavior, and affected Canon Rule, ADR, Skill, agent, or
  derived document when known;
- user/organization impact, security/privacy/legal relevance, and proposed severity;
- sanitized evidence or repository references that do not disclose protected adopter data.

The triage owner records one disposition: `candidate defect`, `approved candidate change`, `defer`,
`not applicable`, or `duplicate`, with rationale and an owner. Severity follows this policy:

| Severity | Meaning | RC2 / GA effect |
|---|---|---|
| **P0 — stop-ship** | Canon corruption or contradiction that can drive unsafe architecture; security, privacy, legal, data-loss, or destructive automation risk; unusable package/provider path; or release-boundary escape. | Immediately blocks qualification and promotion. De-promote/withdraw the candidate, open a new approved corrective plan, and repeat every affected qualification row plus the final joined review for that new plan. |
| **P1 — promotion blocker** | Materially wrong conformance outcome, architecture/profile inconsistency, broken full-auto recovery or authority handling, unsupported representative adoption path, or a cross-document contradiction likely to mislead implementation. | Blocks GA and any claim that RC2 is qualification-complete. Resolve in a new semantic candidate revision and repeat affected qualification before sign-off. |
| **P2 — non-blocking** | Editorial clarity, low-risk example/link/metadata defect, or improvement that does not change an obligation or supported behavior. | May be corrected only when semantically neutral and explicitly owned; otherwise defer to the next patch/minor plan. Open P2 items must be listed in release notes with owner and disposition. |

Security/privacy/legal owners may raise severity within their decision rights. AI may recommend severity
but cannot accept organization risk or downgrade a human policy-owner block.

## Allowed and prohibited candidate changes

Allowed before qualification sign-off:

- changes already inside the approved RC2 plan and Definition of Done;
- corrections that restore Canon/ADR/derived-document agreement without introducing a new decision;
- P0/P1 fixes through a new approved plan and incremented candidate revision;
- truly editorial P2 fixes whose owner confirms no semantic or compatibility effect;
- truthful metadata and release-note updates that continue to identify RC2 as unpublished.

Prohibited:

- adding unqualified architecture features, enterprise chapters, providers, or compatibility claims;
- activating the custom kernel, workflow tooling, verifier, evidence pipeline, CI, or release automation;
- hiding a new obligation, breaking change, security decision, or exception in an editorial correction;
- changing the public marketplace from `v1.0.0-rc.1` before the new tag and exact release operation are
  separately authorized;
- changing version text to `1.0.0` or claiming GA before qualification and all sign-offs;
- treating an AI gate, test result, local commit, or candidate approval as external release authority.

## Field-qualification matrix

Every row is required for GA promotion unless the Standards Owner and the relevant Profile/Policy
Owner record why it is non-applicable. Qualification may use representative internal or consenting
pilot repositories; protected product data must remain in its owning environment.

| ID | Provider | Selected architecture/UI Profiles | Build system | Adoption mode | Required qualification outcome |
|---|---|---|---|---|---|
| Q1 | Codex | Core only; pattern-neutral | SwiftPM | Greenfield | Auto flow reaches engineering completion without loading Boardy or crossing release authority. |
| Q2 | Claude Code | Core + Boardy/VIP + UIKit | CocoaPods | Brownfield from `0.18.x` | Existing module boundaries remain migratable; Boardy is confined to its selected shell; project-owned commands and bindings are honored. |
| Q3 | Codex | Core + Boardy/VIP + SwiftUI | SwiftPM | Greenfield | IO/composition and SwiftUI humble-state/isolation guidance agree; agents execute the approved plan and one final review. |
| Q4 | Claude Code | Core + UIKit + SwiftUI; no Boardy | Bazel | Brownfield | Mixed UI adapters share framework-neutral application policy; no Boardy assumption or package-manager rewrite appears. |
| Q5 | Codex | Core + applicable enterprise chapters | CocoaPods/SwiftPM hybrid | Transitional migration | Partial/transitional conformance, owned policy bindings, expiring exceptions, recovery/resume, and material-blocker escalation are usable. |
| Q6 | Claude Code | Core + Boardy/VIP + mixed UIKit/SwiftUI + applicable enterprise chapters | Representative organization build graph | Existing modular app | Provider-native handoff/resume, shared-writer control, focused executable signals, semantic commits when authorized, and the joined final review operate end to end. |

For each row, the Qualification Owner records candidate identity, repository class, scenario, selected
Profiles/chapters, mode, result, P0/P1/P2 findings, dispositions, and residual risk. “Passed” means the
required outcome was observed with no open P0/P1; it does not require copying adopter source or building
a new evidence framework. Provider availability or a build-system adapter not yet exercised must be
reported as `not qualified`, not inferred as compatible.

## Required sign-offs

One person may hold multiple roles, but each decision right is recorded separately.

| Sign-off role | Required decision |
|---|---|
| **Standards Owner** | RC2 scope is complete; all P0/P1 are closed; P2 dispositions and the GA version decision are acceptable. |
| **Canon Maintainer** | Canon, ADRs, Profiles, Rules, indexes, and derived authority are coherent for the frozen candidate. |
| **Enterprise Adoption Owner** | Every applicable qualification row passed and full/partial/transitional claims are truthful. |
| **Claude Qualification Owner** | Required Claude Code rows passed on the frozen candidate. |
| **Codex Qualification Owner** | Required Codex rows passed on the frozen candidate. |
| **Security/Privacy/Legal Policy Owners** | Any affected organization-owned policy, exception, license, or risk decision is approved; unaffected owners are explicitly marked non-applicable. |
| **DevOps/Release Owner** | Exact external operations, target commit/version/tag/remote/marketplace scope, operator, timing, and rollback route are authorized. |

## External release authority

External release authority must be an explicit instruction from the DevOps/Release Owner (and Legal
Owner where license/distribution scope requires it) that names all of:

- immutable candidate commit and version;
- target branch and remote for any push/merge;
- whether that ref is consumed by an unpinned public channel; a default-branch push requires both
  remote-Git and marketplace/release authority when it can distribute the plugin payload;
- exact tag and whether tag creation/push are authorized;
- release host/repository and whether draft creation or publication is authorized;
- provider marketplace entries and exact version/ref changes;
- whether local install/update, staged rollout, or general availability is authorized;
- authorized operator, time/scope constraints, and rollback/de-promotion owner.

Omitted operations are not authorized. Authority for local stage/commit, a prior RC, one provider, or
one environment does not transfer to another operation, release, provider, or environment. An AI agent
must stop at release readiness when a required field or accountable approval is absent.

## Rollback and de-promotion

- **Before publication:** freeze further promotion, label the candidate not qualified, retain public
  RC1, and open the corrective plan. Do not rewrite history or delete tags without explicit Git/release
  authority.
- **After RC publication:** suspend promotion to GA. Publish a corrected incremented RC or restore the
  marketplace reference to the last known-good published version through a separately authorized
  operation. Published tags remain immutable unless the Release Owner explicitly invokes an incident
  policy that requires removal.
- **After GA publication:** treat a P0/P1 as a release incident. The Release Owner decides marketplace
  withdrawal/rollback; the Standards Owner selects patch, deprecation, or major-version remediation;
  affected policy owners decide risk acceptance. Never silently replace an existing version.

Every rollback/de-promotion records affected versions/providers, reason, owner, adopter communication,
remediation candidate, and requalification scope. Recovery does not convert release automation or CI
into part of this plugin.
