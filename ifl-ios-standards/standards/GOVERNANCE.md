# Governance and Evolution

Status: unpublished Standards `1.0.0-rc.7` working-candidate policy; published marketplace remains
`v1.0.0-rc.1`

## Purpose and authority

This document assigns accountability for Canon, adoption, exceptions, full-auto engineering, and
release decisions. It does not duplicate architectural or enterprise obligations.

Use this interpretation order:

1. The Constitution defines the Canon authority boundary and lifecycle.
2. Accepted ADRs record governing decisions, consequences, and supersession.
3. Active Rules carry obligations; selected Profiles define applicability and may strengthen but never
   weaken Core or contradict their ADRs.
4. Enterprise chapters, specs, process guidance, Skills, agents, templates, examples, and scaffolds are
   derived artifacts. They explain or apply Canon and cannot invent a competing mandate.

User instructions and project bindings select applicable Profiles, change scope, organization-owned
policy values, and stricter local constraints. They cannot silently weaken Canon. A real deviation uses
the governed exception path. If a derived artifact contradicts Canon, Canon governs and candidate
acceptance is blocked until the contradiction is corrected. A material decision change requires a
superseding ADR plus affected Rule, Profile, migration, compatibility, and derived-document updates in
one semantic change.

## Accountable roles and decision rights

Roles describe decision rights, not a required organization chart; one person may hold more than one
role, but each decision remains explicit.

| Role | Accountable decision rights |
|---|---|
| **Standards Owner** | Constitution, roadmap, compatibility direction, candidate scope, and cross-domain ownership disputes. |
| **Canon Maintainer** | Stable identifiers, Canon lifecycle/index integrity, ADR/Rule/Profile coherence, and Canon-to-derived consistency. |
| **ADR or Domain Owner** | Alternatives, consequences, migration, and affected Rule mappings for an owned technical decision. |
| **Profile Owner** | Profile applicability and strengthening; no authority to weaken Core or override an ADR. |
| **Derived-document Maintainer** | Accuracy and Canon traceability of assigned chapters, specs, Skills, agents, templates, examples, and scaffolds. |
| **Consuming-team Conformance Owner** | Profile/chapter selection, adoption scope, project bindings, gap register, migration posture, and claim of full/partial/transitional conformance. |
| **Organization Policy Owner** | Human-owned security, privacy, legal, accessibility, observability, data-retention, deployment-target, and other thresholds/decisions. |
| **Exception Approver** | Acceptance of a temporary deviation: the affected Rule/Profile/Domain Owner plus every impacted Organization Policy Owner. |
| **Enterprise Adoption Owner** | Qualification coverage, representative adoption matrix, and truthfulness of compatibility/conformance claims. |
| **DevOps/Release Owner** | CI, artifact build/signing/provenance, exact Git/tag/publication/marketplace operations, rollout, and rollback. |

AI may analyze, draft, implement, cross-check, and recommend. It cannot invent organization policy
values, grant legal/security approval, accept human-owned risk, approve its own Requirement/Plan gate,
or infer publication authority. A missing value is escalated only when it materially blocks the task;
otherwise the agent preserves the owning policy binding and continues within safe scope.

## Conformance and exception ownership

- **Full conformance** is claimed only by the Consuming-team Conformance Owner after every applicable
  active Rule and selected enterprise policy binding is satisfied and no exception is expired.
- **Partial conformance** declares the exact included scope, excluded scope, non-applicable Rules,
  unresolved gaps, owners, and limitations; it is not a claim that the whole product or organization
  conforms.
- **Transitional conformance** is time-bounded partial conformance with an approved migration owner,
  milestones, expiry, and destination. It is appropriate for staged adoption such as Swift concurrency
  migration, not a permanent weakening of Core.
- **Non-applicable** means a Rule/Profile/chapter is outside the declared product/change scope; it needs
  a recorded rationale and owner but is not an exception.

An exception records affected Rule/policy, bounded scope, reason and risk, accountable owner, every
approving authority, compensating controls, start date, expiry, and remediation/removal plan. Expiry is
mandatory. An expired exception provides no authority and must be removed, renewed by the same decision
rights, or replaced by a conforming solution. Canon grants no default or AI-approved exception.

## Full-auto engineering boundary

When project bindings select auto mode and supply required authority, provider-native Brain-Flow may:

- obtain independent AI Requirement and Plan gate decisions;
- execute one approved plan continuously with disjoint assignments and provider-native resume/handoff;
- run the smallest risk-relevant commands for changed executable code;
- stage explicit paths and commit complete semantic tasks under a scoped Git grant;
- run exactly one joined final AI review, join findings once, and apply at most one in-scope corrective
  batch;
- report engineering completion and release readiness.

Full auto ends there. It never implies branch changes, history rewrite, push, PR, merge, tag, GitHub
release, marketplace publication, installation/update, rollout, organization risk acceptance, or GA
declaration. Those operations require their exact separately granted authority. Provider-native
task/thread state and the approved plan own continuity; no provider-independent kernel, receipt system,
or workflow evidence pipeline is required.

## Change classes and SemVer

| Change class | Meaning | SemVer treatment after `1.0.0` |
|---|---|---|
| Editorial | Wording, links, examples, or metadata change with no obligation/compatibility effect. | Patch |
| Compatible additive | Optional Rule, Profile, capability, or guidance that does not invalidate a conforming adopter. | Minor |
| Breaking | Removes/renames a public entry point or Rule, changes a requirement, narrows compatibility, or makes a conforming adopter non-conforming. | Major |

During prerelease, increment the candidate identifier and disclose any effect that would be breaking
after GA. Security/privacy/legal urgency does not hide impact or bypass the accountable human decision.
Every semantic Canon change identifies owner, ADRs/Rules/Profiles/derived artifacts, compatibility,
migration, and release-note impact.

Deprecation records the surface, replacement, reason, owner, first deprecated version, migration, and
removal condition. Governance sets no fictional universal window. Removal of an accepted GA surface is
breaking unless a governing security/legal policy requires a separately approved emergency path.

## Evolution model

- **Continuous:** process owned corrections and decisions through ADR/Rule/Profile lifecycle and align
  derived documents in the same semantic change.
- **Annual stewardship:** accountable owners assess adoption feedback, qualification coverage,
  compatibility, deprecations/exceptions, provider/build-system experience, platform evolution, and
  policy references.
- **Five-year review:** at least once per five-year period, the Standards Owner revalidates the
  Constitution, Core boundaries, Profile strategy, compatibility posture, and accumulated decisions.
  Annual stewardship maintains a rolling five-year outlook; it is neither a feature promise nor a
  frozen platform-support guarantee.

## Candidate and backlog boundaries

`1.0.0-rc.7` is an unpublished working candidate. Engineering completion, Canon coherence, or AI
review does not make it GA. `RELEASE.md` owns RC feedback, field qualification, sign-offs,
de-promotion, and exact external release authority. The public marketplace stays at published RC1
until an authorized candidate release operation occurs.

Frozen custom-kernel material lives only at repository-root
`backlog/post-1.0/custom-kernel/`, outside the installable `ifl-ios-standards/` plugin subtree. It is
inactive, non-shipping, non-normative, and cannot be an operational prerequisite, dependency, or proof
of conformance. Reactivation requires a separate post-1.0 plan backed by adoption evidence and explicit
scope; it must not be smuggled into a candidate correction. CI and release automation remain owned by
the consuming organization and are outside this plugin.
