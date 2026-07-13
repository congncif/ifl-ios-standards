# ADR-0006 — Board communication, navigation, and context

- Status: Accepted
- Decision date: 2026-07-13
- Owner: iOS Profile Owner

## Context

Cross-board flows need typed communication without controller reach-through. Navigation and return behavior become fragile when rendering code owns policy or when callers depend on implicit stack position instead of an explicit context contract.

## Decision

Board communication uses owner-defined typed IO, flows, and event buses. Boards do not retrieve another Board's controller to communicate. Views only forward navigation intent; the Board or coordinator owns navigation policy, while business completion flows through the Interactor control boundary. Return behavior uses explicit context semantics such as `backToPrevious` or `returnHere`, selected and carried by the owner of the flow.

## Consequences

- Board communication remains replaceable and testable at typed seams.
- Navigation policy stays outside rendering adapters.
- Callers can reason about return behavior without assuming a navigation-stack shape.

## Alternatives considered

- Direct controller references were rejected because they couple Board lifecycle to UI objects and break re-activation.
- Implicit stack inspection was rejected because it hides context ownership and is unreliable across entry points.

## Migration

Replace controller reach-through with typed IO or buses, move navigation policy to the Board or coordinator, and make every return path carry an explicit context choice.

## Canon mapping

- Rules: `BRD-COMM-001`, `BRD-NAV-001`, `BRD-CTX-001`
- Profiles: `boardy-vip`
- Reference: `standards/specs/PLUGINS_INTEGRATION.md`
- Migration: `MIG-ADR-0006`
