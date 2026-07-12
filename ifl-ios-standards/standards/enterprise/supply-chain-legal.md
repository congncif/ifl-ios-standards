# Enterprise Standard — Supply Chain and Legal Governance

## Purpose

Require reproducible dependency selection, source provenance, integrity, inventory, vulnerability
handling, license classification, notices, and release-artifact integrity while preserving human
authority for organization-specific security and legal decisions.

## Applicability

Applies to every direct and transitive build/runtime/test dependency, binary artifact, plugin, build
tool, package-manager resolution, vendored source, generated dependency inventory, and distributable
iOS artifact. It also applies when a dependency is upgraded, replaced, patched, mirrored, or removed.

This chapter consumes the consuming organization's approved supply-chain and legal policy authority.
That policy supplies its own identity, version, owner, approval, classifications, response expectations,
and escalation contacts. This standard deliberately does not invent allow/deny lists, license decisions,
remediation windows, contacts, risk acceptances, or other organization values.

## Non-negotiable rules

- `SUP-PIN-001`: dependencies resolve to exact reviewed versions or immutable revisions in committed resolution state.
- `SUP-PROV-001`: every dependency and binary records authoritative origin, retrieval path, and producer provenance.
- `SUP-HASH-001`: supported checksums/signatures are verified before a fetched or mirrored artifact is trusted.
- `SUP-INVENTORY-001`: releases have an SBOM-compatible direct/transitive inventory tied to the built inputs.
- `SUP-VULN-001`: findings follow the referenced organization vulnerability triage, remediation, exception, and escalation policy.
- `SUP-INTEGRITY-001`: release artifacts and their provenance are integrity-bound to reviewed source and dependency inputs.
- `LEGAL-LICENSE-001`: each dependency has a reviewed license classification from the approved organization policy.
- `LEGAL-NOTICE-001`: required notices have a named owner and are generated/reviewed from the release inventory.

## Decision guidance

1. Prefer platform capabilities, then evaluate necessity, maintenance, security, privacy, license,
   provenance, update cadence, exit cost, and ownership before adding a dependency.
2. Use exact manager-supported resolution and commit the authoritative resolution state. Floating
   branches, ranges without a locked result, mutable URLs, and unrecorded local artifacts are unacceptable.
3. Retrieve from authoritative or organization-approved origins and preserve upstream identity even
   when using a mirror or cache.
4. Treat an unknown origin, checksum/signature mismatch, unknown license classification, or untriaged
   vulnerability as unresolved; route it to the policy owner rather than guessing.
5. Generate release inventory from actual resolved/built inputs, not a manually remembered list.
6. Legal and security risk acceptance is human-owned and time-bounded under organization policy.

## Implementation patterns

- Keep each package manager's authoritative lock/resolution artifact under version control where supported.
- Record package name, version/revision, direct/transitive relationship, source/origin, checksum or
  signature status, license evidence, build use, and owning team in an SBOM-compatible inventory.
- Verify binary checksums/signatures before integration and whenever the origin or expected value changes.
- Isolate dependency APIs behind internal adapters so replacement and vulnerability response remain bounded.
- Correlate the release artifact with source revision, resolved dependency inventory, toolchain, signing
  context, and integrity digest through the organization's release provenance mechanism.
- Route vulnerability and license results to the approved organization policy authority; retain decision
  identity and expiry without copying policy values into this chapter.
- Derive notice inputs from the release inventory and have the named legal/release owner approve output.

## Compliant and non-compliant examples

Compliant:

- A release uses committed exact package resolution and an inventory derived from the resolved graph.
- A vendored binary records its producer, authoritative download origin, version, and verified checksum.
- An unknown license is escalated to the legal policy owner and excluded from release pending a decision.
- A vulnerability exception references the approved policy decision, owner, scope, expiry, and remediation plan.

Non-compliant:

- A dependency follows a mutable branch or an unlocked range at release time.
- A binary is copied from an engineer's machine with no provenance or integrity value.
- A team invents its own license allowlist, vulnerability deadline, or risk acceptance in feature docs.
- A notice file is copied from a previous release without reconciling the current dependency inventory.

## Anti-patterns

- Assuming a package-manager lockfile alone proves provenance, license, vulnerability, and artifact integrity.
- Treating cached or mirrored content as a new origin and discarding upstream identity.
- Inventorying only direct dependencies or only code linked into the main app target.
- Silently accepting checksum/signature mismatch because the artifact “still builds.”
- Using a historical CocoaPods-only policy as universal manager truth.
- Asking an AI agent to choose legal classification, approve vulnerability risk, or invent organization contacts.
- Publishing artifacts that cannot be traced to reviewed source and resolved dependency inputs.

## Verification

The final joined AI consistency review checks that Rules, metadata, chapter guidance, SDK-first
boundaries, and organization-policy references agree and contain no invented policy values. The
consuming organization verifies actual resolution files, dependency/inventory completeness,
provenance, checksums/signatures, vulnerability-policy decisions, license classifications/notices,
and release-artifact integrity through its ordinary DevOps/release process outside this plugin.

## Exceptions

An exception is valid only through the approved organization policy authority and records exact
dependency/artifact/version, reason, risk, affected releases, compensating controls, decision owner,
approval identity, expiry, and removal/remediation plan. This chapter grants no default exception and
cannot waive missing provenance, unexplained integrity mismatch, unknown legal authority, or release
traceability by itself.

## Migration and adoption

1. Inventory package managers, lock/resolution artifacts, vendored binaries, build tools, plugins, and mirrors.
2. Replace floating inputs with exact reviewed resolution and document authoritative origins.
3. Add checksum/signature validation for fetched binaries and preserve upstream provenance through caches.
4. Produce an SBOM-compatible direct/transitive inventory from actual resolved inputs.
5. Bind vulnerability and license decisions to the approved organization policy; escalate unresolved items.
6. Reconcile notices and release integrity with the current inventory before removing legacy manual lists.

## Ownership

The Security/Legal Owner owns this chapter jointly with organization supply-chain, release, and legal
policy authorities. Dependency owners maintain necessity, provenance, upgrades, and removal. Security
owns vulnerability triage under approved policy; Legal owns classification and notices; DevOps/release
owns inventory generation and artifact provenance/integrity.

## Metrics

Track unpinned inputs, unknown origins, integrity failures, inventory completeness/freshness, dependency
age, open vulnerability decisions, expired exceptions, unknown license classifications, notice drift,
and artifacts lacking source/dependency provenance. Thresholds and response expectations come only
from the approved organization policy.

## Review cadence

Review at every dependency or origin change and before each release. Re-evaluate after vulnerability,
license, provenance, package-manager, mirror, signing, or policy changes, and on the organization-defined
supply-chain/legal cadence. Policy owners determine all time-bound values.
