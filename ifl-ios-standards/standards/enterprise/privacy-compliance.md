# Privacy and Compliance

Owner: Privacy Owner  
Requirement: `ENT-PRIVACY`  
Profile: `core`  
Rationale: `ADR-0001`

## 1. Purpose

Make the collection, use, sharing, retention, and disclosure of product data explicit, minimal, owned, and consistent with platform declarations and human-approved legal obligations. This chapter consumes `DATA-CLASS-001` and the redaction boundary in `MSEC-LOG-001`; it does not define a second classification or logging policy.

## 2. Applicability

Apply to every application, extension, SDK, analytics event, diagnostic stream, account flow, permission request, tracking technology, external disclosure, and feature that collects, derives, processes, transmits, stores, or deletes product data. Reassess when purpose, fields, recipients, retention, required-reason API use, tracking behavior, or platform privacy requirements change.

## 3. Non-negotiable rules

- `PRIV-INV-001`: every collected, derived, stored, or disclosed data category has an owned inventory entry linked to purpose, class, recipients, retention, and deletion.
- `PRIV-MANIFEST-001`: the application privacy manifest completely represents app and included SDK behavior.
- `PRIV-REASON-001`: every required-reason API has an approved reason that matches actual use.
- `PRIV-CONSENT-001`: collection or tracking that requires consent starts only after the required informed choice and stops when that choice is revoked.
- `PRIV-MIN-001`: collect, process, disclose, and retain only the minimum data necessary for the declared purpose.
- `PRIV-DISCLOSE-001`: every external disclosure and privacy statement has a named human owner responsible for accuracy and change control.

## 4. Decision guidance

Begin with purpose, not available data. For each purpose, identify the minimum fields, canonical `DATA-CLASS-001` class, source, processing location, recipients, retention, deletion behavior, user control, and accountable owner. Distinguish consent from legal basis and from platform permission: one does not automatically satisfy another. Treat SDK declarations as claims to verify against actual behavior, not as a substitute for product inventory.

Agents may trace code, compare declarations, identify missing ownership, and propose minimization. Agents must not invent legal basis, consent language, disclosure text, required-reason justification, regulatory interpretation, or privacy-risk acceptance. Those decisions require the designated human authority.

## 5. Implementation patterns

### Owned inventory

Maintain one product inventory that identifies data category, `DATA-CLASS-001` class, whether it is collected or derived, purpose, source, processing and storage locations, SDK and external recipients, tracking linkage, retention, deletion cascade, user controls, and named product and privacy owners. Reference Security controls rather than duplicating them.

### Manifest and required-reason APIs

Generate or maintain `PrivacyInfo.xcprivacy` from reviewed app and dependency behavior. Reconcile merged manifests with binary and SDK use before release. For each required-reason API, record the exact API family, actual feature use, approved reason, owner, and removal condition. Remove stale declarations when use ends.

### Consent and tracking

Define a state model covering unknown, not-required, requested, granted, denied, restricted, and revoked states as applicable. Gate collection and tracking at the earliest boundary. Persist only the evidence the organization is authorized to retain. Propagate denial or revocation to SDKs, queued work, identifiers, and downstream processing.

### Minimization and disclosure

Use allowlisted transfer and event schemas rather than serializing domain objects. Separate operational necessity from speculative future analysis. External disclosures name the data, purpose, recipient, sharing role, retention expectation, and owner in language approved through the organization's legal/privacy process.

## 6. Compliant and non-compliant examples

Compliant:

- A new analytics field is added only after its purpose, class, owner, retention, recipient, and deletion behavior are recorded.
- Tracking SDK initialization is delayed until the applicable consent state is granted and is disabled when consent is revoked.
- A required-reason API entry names the feature behavior it supports and is removed when that behavior is replaced.
- A network request DTO contains only the fields required for the declared operation.

Non-compliant:

- A team collects all available profile fields because they may be useful later.
- A privacy manifest copies an SDK sample without comparing it to the shipped dependency and configuration.
- Platform permission is treated as blanket consent for unrelated tracking or disclosure.
- An Agent writes final legal basis or user disclosure text without human authority.
- Logs or diagnostics bypass the deterministic redaction required by `MSEC-LOG-001`.

## 7. Anti-patterns

- Maintaining separate inventories per team with no canonical owner or reconciliation.
- Using broad purposes such as “improve experience” to justify unrelated fields.
- Starting an SDK before consent and attempting to delete its output later.
- Declaring every possible required-reason API “just in case.”
- Treating encryption as permission to collect or retain unnecessary data.
- Leaving disclosure ownership with a channel, committee, or Agent rather than a named accountable human role.

## 8. Verification

The single final joined AI consistency review confirms reciprocal chapter, Rule, ADR, profile, ownership, and dependency references; exact consumption of `DATA-CLASS-001` and `MSEC-LOG-001`; and guidance covering inventory, manifest completeness, required-reason APIs, consent order, minimization, and disclosure ownership. Executable privacy behavior and plist validity remain subject to the consuming repository's ordinary tests and platform tooling; CI operation and legal approval are outside this plugin.

## 9. Exceptions

An exception identifies the exact Rule, purpose, data fields and `DATA-CLASS-001` classes, processing and recipients, affected versions, legal/privacy authority, compensating minimization and security controls, accountable owner, expiry, review event, and deletion or removal plan. Only designated human privacy/legal authority may approve legal basis, disclosure wording, consent deviation, or privacy-risk acceptance. Expired or ownerless exceptions are invalid.

## 10. Migration and adoption

Create the owned data inventory first. Reconcile actual collection, SDK behavior, manifests, required-reason APIs, consent gates, event and request schemas, retention, and disclosures against it. Stop unauthorized or ownerless collection before refining documentation. Then minimize payloads, enforce consent and revocation at source, align manifests and disclosures, and retire temporary compatibility behavior through time-bounded exceptions.

## 11. Ownership

The Privacy Owner owns this chapter, inventory completeness, privacy interpretation, and exception routing. The Data Lifecycle Owner owns `DATA-CLASS-001`, retention, and deletion semantics. The Security Owner owns `MSEC-LOG-001`. Feature owners own declared purpose and field necessity. Legal and designated privacy authorities own legal basis and disclosure approval; Agents do not assume those roles.

## 12. Metrics

Track inventory coverage, ownerless entries, undeclared SDK or required-reason API use, manifest-to-shipped-behavior differences, collection paths gated before consent, revocation propagation time, fields removed through minimization, disclosures awaiting owner review, and privacy exceptions approaching expiry. Metrics themselves follow minimization and redaction requirements.

## 13. Review cadence

Review at least quarterly and before release when data fields, purposes, recipients, SDKs, tracking, required-reason APIs, retention, consent behavior, or disclosures change. Reconcile platform privacy changes promptly. Review active exceptions before expiry and immediately after a privacy incident, regulator or platform-policy change, or discovery of undeclared collection.
