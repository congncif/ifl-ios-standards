# Governance and Evolution

Status: Standards `1.0.0-rc.1` candidate policy

## Purpose

This document assigns accountability for the Standards, explains how Canon changes, and keeps
organization-specific authority with humans. It does not duplicate architectural or enterprise Rules.
Current obligations live in `standards/canon/`; detailed operating guidance lives in the linked specs,
enterprise chapters, and process documents.

## Authority and precedence

Use this precedence path when authoring or interpreting the pack:

1. **Canon authority boundary** — the Constitution and activated Canon indexes define the governed set
   and its activation state.
2. **ADR** — an accepted ADR records the governing decision, rationale, consequences, and supersession
   history.
3. **Rule and Profile** — active Rules carry current obligations; Profiles select and may strengthen
   applicable Rules but cannot weaken Core or contradict their governing ADRs.
4. **Derived document** — enterprise chapters, specs, process guidance, Skills, agents, templates,
   examples, and scaffolds explain or apply Canon and cannot create a competing obligation.

This order is not a mechanism for ignoring contradictions. A contradiction, orphan Rule/ADR mapping,
or derived document that changes canonical meaning blocks acceptance until the affected surfaces agree.
Materially changing an accepted decision requires a superseding ADR and the corresponding Rule, Profile,
migration, and derived-document updates in the same semantic change. See
`standards/CONSTITUTION.md` and `standards/canon/adrs/ADR-0001-standards-authority-and-evolution.md`.

## Accountable roles and decision rights

Roles are responsibilities, not assumptions about an adopter's organization chart. One person may hold
several roles, but the decision right remains explicit.

| Role | Accountable decision rights |
|---|---|
| Standards Owner | Constitution, roadmap, breaking Standards direction, and resolution of cross-domain ownership disputes. |
| Canon Maintainer | Canon integrity, stable identifiers, lifecycle/status changes, index coherence, and integrated Canon/derived-document consistency. |
| ADR or Domain Owner | Technical decision proposal, alternatives, consequences, migration, and affected Rule mappings for the owned domain. |
| Profile Owner | Applicability and strengthening within a Profile; no right to weaken Core or override an ADR. |
| Derived-document Maintainer | Accuracy of assigned chapters, specs, Skills, agents, templates, examples, and links back to Canon. |
| Security, Privacy, Legal, or Organization Policy Owner | Human approval of classifications, thresholds, exceptions, risk acceptance, legal decisions, and other organization-owned values. |
| Consuming-team Owner | Profile selection, project bindings, adoption sequencing, and project-level exception/remediation ownership. |
| DevOps/Release Owner | Organization CI, artifact build/signing/provenance, tagging, publication, and external release operation. |

AI agents may analyze, draft, cross-check, and recommend. They cannot supply human legal/security
approval, invent organization thresholds or policy values, accept risk, or grant publication authority.
When required authority or a value is absent, preserve the policy reference and escalate to its human
owner instead of choosing a substitute.

## Change classes and SemVer

Classify the semantic effect before choosing the version:

| Change class | Meaning | SemVer treatment after `1.0.0` |
|---|---|---|
| Editorial | Fixes wording, links, examples, or metadata without changing an obligation or supported contract. | Patch |
| Compatible additive | Adds an optional capability, Rule, Profile, or guidance without invalidating a conforming adopter. | Minor |
| Breaking | Removes or renames a public entry point or Rule, weakens compatibility, changes required behavior, or makes a previously conforming adopter non-conforming. | Major |

Security, privacy, or legal urgency does not bypass impact analysis or human authority. Use the smallest
SemVer class that truthfully describes the compatibility effect. During a prerelease, increment the
prerelease identifier for candidate revisions and call out any change that would be breaking after
`1.0.0`; prerelease status is not permission to hide migration impact.

Every semantic Canon change identifies its owner, affected ADRs/Rules/Profiles/derived documents,
compatibility effect, migration, and release-note entry. Detailed obligations remain in Canon rather
than being restated in the change record.

## Deprecation and exceptions

A deprecation names the deprecated surface, replacement, reason, owner, first deprecated version,
migration path, and removal condition. Announce it in the changelog and relevant entry-point guidance.
Removal of an accepted public surface is a breaking change and therefore belongs in a major release,
unless the surface existed only in an unaccepted prerelease. Governance sets no fictional universal
deprecation window; the owning release plan records the justified schedule.

An exception is temporary and records scope, reason and risk, accountable owner, approving authority,
compensating controls, expiry, and remediation/removal plan. Organization-policy exceptions require the
corresponding human policy owner. Expiry is mandatory: an expired exception is not authorization and
must be removed, renewed by the same authority, or replaced by a conforming solution. Canon grants no
default exception.

## Evolution model

- **Continuous:** accept proposed corrections and decisions through the ADR/Rule/Profile lifecycle and
  keep derived documents aligned in the same semantic change.
- **Annual stewardship review:** accountable owners assess adoption feedback, compatibility, active
  deprecations/exceptions, provider and build-system operation, platform/framework evolution, and
  security/privacy/legal policy references. The review chooses changes; it does not invent organization
  values or promise unsupported platform minimums.
- **Five-year evolution review:** at least once in each five-year period, the Standards Owner leads a
  deeper revalidation of the Constitution, authority model, Core boundaries, Profile strategy, and
  accumulated deprecations. Each annual review also maintains a rolling five-year outlook so the deeper
  review is a planned horizon, not a freeze or compatibility guarantee.

## Candidate acceptance and release boundary

For `1.0.0-rc.1`, Tasks 1–5 complete before one joined AI consistency review of the full candidate.
Collect all findings before remediation and dispose accepted in-scope findings as one corrective batch.
Only after findings are disposed may the Canon lifecycle/statuses and indexes be activated and the plan
Definition of Done be marked complete. This is the one review event; do not create per-task or
per-finding review loops. See `standards/process/lean-verification.md` and `RELEASE.md`.

The Standards do not require verifier scripts, receipts, manifests, hash chains, derived-artifact
registrations, custom workflow state, CI, release scripts, tags, or publication. Provider-native task
state and the approved plan are enough for local delivery. Organization CI and any external release
remain DevOps/Release-owned and outside the Standards candidate acceptance scope. Frozen custom-kernel
contracts are preserved only under `backlog/post-1.0/custom-kernel/` and have no active authority.
