# Enterprise Standard — Observability and Operability

## Purpose

Define privacy-safe, bounded, and owned diagnostic signals that let teams detect, correlate, diagnose,
and operate production behavior without moving analytics meaning or sensitive data into Views.

## Applicability

Applies to production iOS applications, extensions, shared SDK adapters, background work, network and
persistence infrastructure, crash reporting, product analytics, operational dashboards, and offline
diagnostic buffering. It consumes the active Security log-redaction, Privacy minimization/disclosure,
and Data classification/retention Rules.

## Non-negotiable rules

- `OBS-EVENT-001`: emit events through typed contracts with bounded fields and cardinality.
- `OBS-CRASH-001`: crash context is bounded, classified, minimized, and redacted before capture.
- `OBS-METRIC-001`: important service and product outcomes expose owned metrics or traces with defined units.
- `OBS-CORR-001`: related signals use a non-sensitive correlation identifier across asynchronous boundaries.
- `OBS-REDACT-001`: classification-aware redaction occurs before persistence, buffering, or transport.
- `OBS-TAXON-001`: one versioned taxonomy owns names, purpose, allowed fields, and analytics meaning.
- `OBS-BUFFER-001`: offline buffering has explicit capacity, age, eviction, retry, and deletion behavior.
- `OBS-OWNER-001`: every diagnostic surface has an owner, retention boundary, operational use, and removal path.

Views may forward a typed user intent or render display-ready state. They never assemble event names,
classify product outcomes, attach domain objects, or decide analytics meaning. That mapping belongs to
a tested presentation/domain boundary and the infrastructure adapter.

## Decision guidance

1. Start with the operational question and named owner; do not collect data “for later.”
2. Classify every field using the product data taxonomy, then remove fields not required by the purpose.
3. Choose an event for a discrete occurrence, a metric for an aggregate, and a trace for causal timing.
4. Use correlation only when a workflow crosses components or asynchronous boundaries; identifiers
   must not encode account, device, contact, or other sensitive identity.
5. Reject dimensions whose possible values are uncontrolled. Prefer a bounded enum or coarse bucket.
6. If collection cannot satisfy redaction, retention, consent, and disclosure obligations, do not emit it.

## Implementation patterns

- Define typed event payloads and translate them to vendor SDKs in an Infrastructure adapter.
- Keep taxonomy definitions versioned and review field additions as contract changes.
- Redact at the source boundary so raw values never reach crash breadcrumbs, queues, or exporters.
- Propagate an opaque correlation value through task-local or explicit request context; create a new value
  at a trust or workflow boundary rather than reusing a user identifier.
- Configure offline queues with explicit maximum count/bytes, maximum age, deterministic eviction,
  network policy, retry ceiling, and deletion on consent withdrawal or account-data deletion.
- Keep diagnostic retention no longer than the governing Data and Privacy policy permits.

## Compliant and non-compliant examples

Compliant:

- A typed checkout outcome maps a bounded result enum and duration bucket to an analytics adapter.
- A crash report includes app/build state and a redacted error category, but no free-form request body.
- A trace links network, persistence, and presentation spans through an opaque correlation value.
- An offline queue evicts oldest eligible records at its declared capacity and purges expired records.

Non-compliant:

- A View builds a free-form event name from button text or a domain model.
- Crash metadata includes email, access token, URL query contents, or unrestricted error descriptions.
- A metric labels every request with a raw URL, object identifier, or arbitrary server message.
- A diagnostic buffer grows until disk pressure or retries forever without an age or attempt limit.

## Anti-patterns

- Logging entire models or payloads “temporarily.”
- Treating crash breadcrumbs as exempt from Security, Privacy, or Data rules.
- Creating a second event taxonomy inside a feature or vendor adapter.
- Using analytics events as an implicit business-state store.
- Declaring success from event volume without measuring loss, delay, cardinality, or ownership.
- Keeping ownerless dashboards, alerts, or events after their operational purpose ends.

## Verification

The final joined AI consistency review checks Rule coverage, dependency alignment, View-boundary
language, taxonomy ownership, bounded cardinality/buffering, retention, and redaction consistency.
Executable implementations use the consuming repository's normal tests to demonstrate typed mapping,
redaction before export, correlation propagation, and deterministic buffer eviction. Production
readiness claims reference observed commands or operational data; self-reported assertions are not evidence.

## Exceptions

An exception records the exact signal and fields, data classification, purpose, affected environment,
owner, approving Security/Privacy/Data authorities, compensating controls, expiry, and removal plan.
An exception cannot authorize secrets, authentication material, or undisclosed collection, and cannot
create an unbounded field, buffer, retry loop, or retention period.

## Migration and adoption

1. Inventory current events, metrics, traces, crash fields, buffers, dashboards, and owners.
2. Map each signal to the canonical taxonomy, operational purpose, data class, and retention policy.
3. Remove unused and ownerless signals before translating vendor calls behind typed adapters.
4. Move analytics-meaning construction out of Views and into tested presentation/domain mapping.
5. Add source redaction, bounded dimensions, opaque correlation, and bounded offline eviction.
6. Adopt by feature slices, preserving legacy aliases only for an explicitly time-bounded transition.

## Ownership

The Operability Owner owns this chapter and the shared taxonomy. Feature owners own semantic event
mapping and runbooks. Security owns log/crash redaction requirements; Privacy owns minimization and
disclosure; Data Lifecycle owns classification, retention, deletion, backup, and offline-storage bounds.

## Metrics

Track owned-signal coverage, unowned-signal count, taxonomy-change rate, dropped/exported event ratio,
redaction violations, cardinality budget violations, correlation coverage, buffer occupancy/eviction,
diagnostic age, alert actionability, and mean time to detect/diagnose. Products set reviewed thresholds
for their context; this chapter does not prescribe universal numeric values.

## Review cadence

Review taxonomy and new fields with every material instrumentation change. Owners review dashboards,
alerts, retention, buffers, and unused signals on the organization-defined operating cadence and after
an incident, privacy/security change, vendor change, or material architecture migration.
