# Data Lifecycle Standard

## Purpose

Give product data one classification and an explicit lifecycle from collection and storage through cache,
backup, migration, offline use, retention, and deletion. `DATA-CLASS-001` owns the canonical taxonomy used
by downstream Security, Privacy, and Observability guidance; those chapters must reference it rather than
create competing classes.

## Applicability

Apply to every app-owned record, file, preference, database row, credential, key, cache, log buffer,
download, attachment, queued request, search index, analytics payload, and offline copy. Apply at design
time and whenever purpose, sensitivity, store, backup behavior, retention, or deletion behavior changes.

## Non-negotiable rules

- `DATA-CLASS-001`: classify every product-data element as `public`, `internal`, `confidential`, or
  `restricted` before selecting storage or transport behavior.
- `DATA-STORE-001`: use only stores approved for the class and purpose.
- `DATA-CRYPT-001`: protect confidential and restricted data at rest with platform-approved encryption and
  separately protected keys.
- `DATA-RET-001`: define a purpose-bound retention duration or terminal event; permanent-by-default
  retention is invalid.
- `DATA-DELETE-001`: deletion cascades through every app-owned primary, derived, cached, queued, indexed,
  and offline copy.
- `DATA-CACHE-001`: caches inherit source classification and have explicit bounds and purge triggers.
- `DATA-BACKUP-001`: backup inclusion or exclusion is explicit; restricted secrets and reproducible caches
  are excluded.
- `DATA-MIGRATE-001`: persisted schema changes are versioned, integrity-preserving, recoverable, and have a
  rollback or forward-recovery decision.
- `DATA-OFFLINE-001`: offline data is purpose-limited and bounded by scope, age, and capacity.

## Decision guidance

Use the highest class that applies:

| Class | Meaning | Typical examples |
|---|---|---|
| `public` | Approved for public disclosure | Published catalogue copy or public help content |
| `internal` | Non-public operational data with limited harm if disclosed | Feature configuration or non-sensitive diagnostics |
| `confidential` | Personal, customer, or business data whose disclosure can cause material harm | Profile data, transaction history, private documents |
| `restricted` | Credentials, authentication tokens, cryptographic material, regulated/high-impact identifiers, or data whose compromise enables account or systemic harm | Refresh tokens, private keys, recovery secrets |

Classification follows content and impact, not a convenient current store. A mixed record uses the highest
contained class unless fields are separated into independently controlled stores.

Storage selection:

| Class | Approved direction |
|---|---|
| `public` | App bundle or sandbox storage appropriate to availability and freshness |
| `internal` | Sandbox preferences, files, or database with platform data protection and explicit retention |
| `confidential` | Protected file/database storage with encryption at rest and least data necessary |
| `restricted` | Keychain or an approved hardware-/system-protected secret store with least-privilege accessibility; never plain files, preferences, logs, or general caches |

When a record no longer has a valid purpose, delete it rather than merely hiding it. When immediate deletion
cannot reach a remote dependency, queue an idempotent deletion request, remove local access, and keep only
the minimum tombstone needed to complete or reconcile the cascade.

## Implementation patterns

### Classification at the boundary

Define classification beside the inward-owned data contract. An Infrastructure adapter maps external
fields into that contract and chooses a store from the approved matrix; vendor models do not decide class.

### Protected store

Separate encrypted content from key material, use platform Data Protection and Keychain facilities, limit
accessibility to the required device state, and avoid synchronizable or shared access groups unless the
declared purpose requires them.

### Retention and deletion cascade

A retention policy names purpose, class, store, start event, terminal event or duration, and owner. A
deletion use case enumerates primary records, attachments, caches, search indexes, queued payloads,
analytics buffers, and offline replicas. Each adapter implements the inward deletion contract.

### Versioned migration

Persist a schema version, make migration steps deterministic and restart-safe, validate invariants before
removing the previous representation, and define rollback or forward recovery before rollout. Destructive
fallback is not a migration strategy.

### Bounded offline cache

Declare eligible fields, record count or storage capacity, maximum age, refresh policy, purge triggers, and
behavior when the bound is reached. Logout, account removal, classification change, and consent/purpose
withdrawal trigger purge where applicable.

## Compliant and non-compliant examples

Compliant: a confidential order database uses platform-protected encrypted storage, retains only the
business-required period, excludes derived thumbnails from backup, and deletion removes rows, search
indexes, attachments, and offline pages.

Non-compliant: the same order is unclassified, stored in preferences, retained forever, copied into an
unbounded cache, and removed only from the primary table.

Compliant: a refresh token is `restricted`, stored in a least-privilege Keychain item, excluded from backup
and logs, rotated, and deleted on account removal.

Non-compliant: a token is placed in a plist or database beside ordinary profile data because both belong to
the same feature.

Compliant: a migration is versioned and restart-safe, validates record counts and critical invariants, and
has a documented recovery decision.

Non-compliant: launch code deletes the store and silently recreates it when migration fails.

## Anti-patterns

- Inventing feature-local sensitivity labels instead of using the four canonical classes.
- Choosing a class based on where data is already stored.
- Treating sandbox location alone as encryption or access control.
- Permanent retention, backup-by-default, or cache-without-bounds.
- Deleting the primary record while retaining derived, queued, indexed, or offline copies.
- Keeping restricted data in `UserDefaults`, logs, crash context, general files, or shared caches.
- Shipping a destructive migration as automatic recovery.

## Verification

The single final joined AI review examines the complete Standards 1.0 change for one classification
taxonomy, class-appropriate storage and encryption, finite retention, complete deletion cascades, cache and
backup policy, recoverable migration, bounded offline data, and absence of Security or Privacy back-edges.
This chapter defines no plugin verifier, fixture matrix, receipt, or build command.

## Exceptions

An exception is temporary and binds the exact data class, store, affected artifact digest, compensating
control, accountable owner, expiry, and removal plan. It cannot make restricted plaintext storage,
permanent retention, partial deletion, destructive migration, or unbounded offline data acceptable. A
classification dispute uses the higher class until the Data Lifecycle Owner resolves it.

## Migration and adoption

1. Inventory persisted, cached, queued, logged, backed-up, and offline data by purpose and owner.
2. Assign one of the four canonical classes and separate mixed records where useful.
3. Move each class to an approved store and protection level; migrate restricted secrets first.
4. Add explicit retention, deletion cascade, backup, and cache policies.
5. Version current schemas and define restart-safe migration and recovery.
6. Bound offline copies and connect purge to logout, account removal, purpose withdrawal, and expiry.
7. Remove legacy copies only after the new lifecycle covers every declared location.

## Ownership

The Data Lifecycle Owner owns the taxonomy and this chapter. Feature owners classify and declare purpose;
Infrastructure owners implement stores, migrations, backup flags, and deletion adapters. Security, Privacy,
and Observability owners consume the taxonomy without redefining it.

## Metrics

Track classified versus unclassified data elements, stores outside the approved class matrix, expired
retention records, deletion-cascade failures and age, cache-bound violations, backup-policy exceptions,
migration recovery incidents, offline footprint by class, and active exception age.

## Review cadence

Review at least annually, and whenever a new data class/use, store, backup behavior, retention law,
cryptographic policy, migration framework, or offline capability is introduced. Reassess every exception
before expiry.

