# ADR-0007 — Composition, DI, registration, and visibility

- Status: In review
- Decision date: 2026-07-13
- Owner: iOS Profile Owner

## Context

Boardy composition needs concrete construction at the application edge while preserving internal feature implementations, safe ownership, and repeatable activation. Unrestricted implementation imports, strong back edges, activation-time flow registration, and closure-created shared repositories undermine those boundaries.

## Decision

Only declared composition roots import implementation targets and construct registered public plugin entries. Feature implementations never import another feature's Plugins target. Required back edges are weak. Boards register flows during initialization, add activation guards only for explicit single-session semantics, and keep shared repositories as ModulePlugin-owned stored properties rather than constructing them in registration closures.

## Consequences

- Application assembly remains possible without opening implementation APIs between features.
- Board registrations have stable dependency identity and ownership.
- Re-activation does not multiply flow handlers or retain parent objects through back edges.

## Alternatives considered

- Service location from feature implementations was rejected because it obscures dependency ownership.
- Registration closures that build shared repositories on demand were rejected because they silently create inconsistent repository lifetimes.

## Migration

Move construction to declared roots, narrow public visibility, replace cross-feature Plugins imports with IO contracts, weaken required back edges, and move flow registration and shared repository ownership to their canonical locations.

## Canon mapping

- Rules: `CORE-COMP-001`, `CORE-API-001`, `BRD-COMP-001`, `BRD-MOD-001`, `BRD-REF-001`, `BRD-FLOW-001`, `BRD-ACTIVATION-001`, `BRD-REPOSITORY-001`
- Profiles: `core`, `boardy-vip`
- Reference: `standards/specs/CROSS_MODULE_DI.md`
- Migration: `MIG-ADR-0007`
