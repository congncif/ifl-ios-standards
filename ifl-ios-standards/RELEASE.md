# Standards 1.0 Release and Future Promotion

Target: `1.0.0` General Availability

State: GA release at immutable tag `v1.0.0`

Published marketplace baseline: `v1.0.0`

Qualification: **Q1-Q6 6/6 — qualified by explicit impact retention**. The engineering-complete RC7
payload is `2fc508b8d943fe4ef439bdcbbd86585e398cc513`; the post-freeze ledger is
`docs/02-working-docs/work-items/IIS-0012-rc7-qualification-retention/qualification.md`. Open P0/P1
is `0/0`. Q4 Bazel-target and Q6 target-specific compilation/tests remain unproven; the Release Owner
accepts that disclosed residual for 1.0 without relabeling either target as observed.

GA decision: the task owner explicitly authorized publishing `1.0.0`, updating marketplace/install
references, pushing `main`, creating and pushing `v1.0.0`, and publishing the GitHub Release.
Administrative sign-off consolidation is deferred as post-release documentation. The exact operation
set and rollback target are recorded in
`docs/02-working-docs/work-items/IIS-0013-1.0-ga-publication/release-decision.md`.

## Boundary

Engineering completion alone establishes only that the approved content plan and its joined AI review
are complete. Standards 1.0 crossed the external release boundary through the explicit GA decision
above; that decision does not become standing authority for any future branch, tag, publication,
installation, or rollout.

No release stage requires a pack-owned verifier, receipt/evidence system, CI implementation, release
script, or custom workflow state. Qualification uses provider-native task state, the candidate commit,
ordinary adopter commands when executable product code is affected, and accountable human decisions.

## Future candidate sequence

1. Complete one approved candidate engineering plan through semantic task commits, exactly one joined final
   AI review, and at most one in-scope corrective batch.
2. Freeze the candidate commit and identify its version, commit SHA, included paths, and published
   baseline. Do not move the current public marketplace reference before the new release is authorized.
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
`not applicable`, or `duplicate`, with rationale and an owner. The table below defines **RC feedback
and qualification severity**. The engineering final review uses the operating-model taxonomy; a
finding carried into RC qualification keeps the higher applicable severity and cannot be silently
downgraded merely because its phase changed.

| Severity | Meaning | Candidate / GA effect |
|---|---|---|
| **P0 — stop-ship** | Canon corruption or contradiction that can drive unsafe architecture; security, privacy, legal, data-loss, or destructive automation risk; unusable package/provider path; or release-boundary escape. | Immediately blocks qualification and promotion. De-promote/withdraw the candidate, open a new approved corrective plan, and repeat every affected qualification row plus the final joined review for that new plan. |
| **P1 — promotion blocker** | Materially wrong conformance outcome, architecture/profile inconsistency, broken full-auto recovery or authority handling, unsupported representative adoption path, or a cross-document contradiction likely to mislead implementation. | Blocks GA and any claim that the candidate is qualification-complete. Resolve in a new semantic candidate revision and repeat affected qualification before sign-off. |
| **P2 — non-blocking** | Editorial clarity, low-risk example/link/metadata defect, or improvement that does not change an obligation or supported behavior. | May be corrected only when semantically neutral and explicitly owned; otherwise defer to the next patch/minor plan. Open P2 items must be listed in release notes with owner and disposition. |

Any applicable Organization Policy Owner may raise severity within their decision rights. AI may
recommend severity but cannot accept organization risk or downgrade a human policy-owner block.

## Allowed and prohibited candidate changes

Allowed before qualification sign-off:

- changes already inside the approved candidate plan and Definition of Done;
- corrections that restore Canon/ADR/derived-document agreement without introducing a new decision;
- P0/P1 fixes through a new approved plan and incremented candidate revision;
- truly editorial P2 fixes whose owner confirms no semantic or compatibility effect;
- truthful metadata and release-note updates that preserve the candidate/release state.

Prohibited:

- adding unqualified architecture features, enterprise chapters, providers, or compatibility claims;
- activating the custom kernel, workflow tooling, verifier, evidence pipeline, CI, or release automation;
- hiding a new obligation, breaking change, security decision, or exception in an editorial correction;
- changing the public marketplace from the current `v1.0.0` baseline before a new tag and exact release operation are
  separately authorized;
- changing version text to `1.0.0` or claiming GA before qualification and all sign-offs;
- treating an AI gate, test result, local commit, or candidate approval as external release authority.

## Field-qualification matrix

Every distinct provider/Profile/build-system/adoption scenario advertised for GA must be represented
by and pass a row. The six rows are scenario boundaries, not a requirement to exhaust every internal
scheme, destination, simulator, or other configuration permutation. Within a row,
select the smallest representative set covering changed behavior, common supported configurations, and
directly impacted build surfaces. Expand only for distinct configuration risk or when the approved DoD
or bound release policy requires it; do not duplicate equivalent platform signals across build systems.

The Standards Owner and relevant Profile/Policy Owner may mark a scenario row non-applicable only when
the corresponding support claim is narrowed or removed consistently from compatibility guidance,
README/manifests, and release notes. A named owner with authority over that boundary may waive a
nonstandard configuration inside an otherwise observed row when an accepted exact-candidate platform
signal exists and the omitted boundary, accepted signal, rationale, unproven target coverage, residual
risk, and owner are recorded. The waiver does not prove the omitted target and cannot hide P0/P1
evidence. Otherwise an unexercised required row is `not qualified` and blocks GA. Qualification may use
representative internal or consenting pilot repositories; protected product data must remain in its
owning environment.

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
a new evidence framework. An entirely unobserved provider, advertised scenario, or build-system adapter
remains `not qualified`. An inside-row configuration waiver cannot substitute for observing the row's
required outcome. Do not infer compatibility or relabel the scenario non-applicable while its support
claim remains advertised.

## Required sign-offs

One person may hold multiple roles, but each decision right is recorded separately.

For `1.0.0`, the task/Release Owner accepted the Q4/Q6 residual and explicitly deferred the
administrative consolidation of the role records below until after publication. This is a scoped GA
decision, not evidence that omitted target tests ran and not a precedent that weakens future release
authority.

| Sign-off role | Required decision |
|---|---|
| **Standards Owner** | Candidate scope is complete; all P0/P1 are closed; P2 dispositions and the GA version decision are acceptable. |
| **Canon Maintainer** | Canon, ADRs, Profiles, Rules, indexes, and derived authority are coherent for the engineering-complete candidate. |
| **Enterprise Adoption Owner** | Every applicable qualification row passed and full/partial/transitional claims are truthful. |
| **Claude Qualification Owner** | Required Claude Code rows passed on the engineering-complete candidate. |
| **Codex Qualification Owner** | Required Codex rows passed on the engineering-complete candidate. |
| **Applicable Organization Policy Owners** | Every affected deployment/platform, security, privacy, legal, accessibility, observability/operability, data-retention, performance/resilience, supply-chain, or other governed policy/exception/risk decision is approved by its owner; each unaffected domain is explicitly marked non-applicable with rationale and owner. |
| **DevOps/Release Owner** | Exact external operations, target commit/version/tag/remote/marketplace scope, operator, timing, and rollback route are authorized. |

## External release authority

The exact `1.0.0` authority is recorded in the IIS-0013 release decision: promotion commit on `main`,
remote `origin` (`congncif/ifl-ios-standards`), atomic push of `main` and `v1.0.0`, public GitHub
Release publication, and marketplace/install ref `v1.0.0`. Local plugin installation and adopter
rollout are not included. Rollback/de-promotion returns public guidance to `v1.0.0-rc.1` through a new
explicit operation; the published `v1.0.0` tag remains immutable.

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

- **Before publication:** freeze further promotion, label the candidate not qualified, retain the
  last known-good published ref, and open the corrective plan. Do not rewrite history or delete tags without explicit Git/release
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
