# ADR-0002: Module Boundaries and Dependency Direction

Status: In Review

Owner: Chief Architecture Owner

Decision date: 2026-07-13

## Context

Long-lived product policy becomes expensive to test and evolve when Domain or Application code imports
UI frameworks, orchestration libraries, persistence, networking, or vendor SDKs. A five-year standard
needs dependency direction that keeps business meaning stable while platform and infrastructure adapters
remain replaceable.

## Decision

Keep Domain independent of UI, orchestration, persistence, networking, and vendor SDKs; let Application depend inward and own protocols for required outward capabilities; and require UI and Infrastructure adapters to implement those inward contracts while remaining outside the Domain and Application import graph.

The layer that needs a capability owns its abstraction. Concrete outward technology conforms from the
edge and depends toward the policy it serves. Data crossing a boundary is mapped into inward-owned types
instead of leaking framework or vendor models into Domain or Application.

## Alternatives considered

- Let Domain import convenient framework and SDK types. Rejected because product policy would inherit
  their lifecycle and testing cost.
- Put capability protocols beside concrete adapters. Rejected because outward technology would then own
  the contract required by inward policy.
- Share one unrestricted common module across all layers. Rejected because it erases dependency
  direction and becomes a path for framework leakage.

## Consequences

- Domain and Application can be tested without platform, persistence, network, or vendor runtimes.
- Replacing an adapter does not require changing the business contract it implements.
- Boundary mapping adds deliberate code and prevents framework models from becoming domain models.
- Public contracts must remain minimal because outward adapters and composition depend on them.

## Migration

1. Inventory outward imports in Domain and Application targets.
2. Move framework- or vendor-specific behavior to UI or Infrastructure adapters.
3. Define the required capability as an inward-owned protocol using inward-owned values.
4. Map external values at the boundary and migrate callers incrementally behind the protocol.
5. Remove the obsolete outward import only after all consumers use the inward contract.
