# ADR-0003 — Contract versus implementation targets

- Status: Accepted
- Decision date: 2026-07-13
- Owner: iOS Profile Owner

## Context

Feature modules need a stable surface for cross-feature use without exposing their construction details. Treating a module's IO contract and Plugins implementation as interchangeable creates implementation coupling, broadens the public API, and lets one feature construct another feature's internals.

## Decision

Each feature separates its public IO/contract target from its implementation target. Cross-feature consumers import only the owning feature's IO target. Implementation declarations remain internal except for explicitly registered composition entry types required by an application composition root. A public composition entry does not make the rest of the implementation target a feature-to-feature dependency surface.

## Consequences

- Feature contracts can evolve independently of implementation layout.
- Composition roots retain enough visibility to build the application.
- Public surface area and cross-feature dependency direction become reviewable.

## Alternatives considered

- One public target per feature was rejected because it exposes construction and implementation details to every consumer.
- Public implementation types with convention-only import discipline were rejected because the boundary would not be explicit.

## Migration

Split mixed targets into IO and implementation targets, move shared contracts to IO, make implementation declarations internal, and expose only the registered composition entries required by the application root.

## Canon mapping

- Rules: `CORE-API-001`, `BRD-MOD-001`
- Profiles: `core`, `boardy-vip`
- Reference: `standards/specs/ARCHITECTURE.md`
- Migration: `MIG-ADR-0003`
