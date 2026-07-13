# ADR-0009 — SwiftUI rendering adapter

- Status: Accepted
- Decision date: 2026-07-13
- Owner: SwiftUI Profile Owner

## Context

SwiftUI makes local state and computed rendering convenient, but convenience can blur the line between transient interaction state and product state. A SwiftUI View that formats domain values or owns business state no longer shares a testable presentation contract with UIKit.

## Decision

SwiftUI Views receive display-ready product state from a presentation store isolated to MainActor. The store is the rendering adapter for Presenter output, not a second domain or business layer. View-local state is limited to transient focus, pressed or highlighted state, gestures, animation, scrolling, disclosure, and geometry-only visual interpolation. Formatting, eligibility, policy, analytics meaning, persistence, and business dependency construction remain outside the View.

## Consequences

- SwiftUI retains ergonomic local interaction state without owning product decisions.
- UIKit and SwiftUI render the same semantic presentation output.
- Presentation stores have a clear isolation and ownership role.

## Alternatives considered

- Treating every `@State` value as architecture state was rejected because UX mechanics do not need a business round trip.
- Letting Views compute formatted product values was rejected because those outputs become difficult to test and inconsistent across adapters.

## Migration

Introduce a MainActor presentation store for display-ready product state, move product computations and formatting to the Presenter or presentation mapper, and keep only explicitly UX-local values in SwiftUI state.

## Canon mapping

- Rules: `UI-HUMBLE-001`, `UI-HUMBLE-002`, `UI-HUMBLE-003`, `UI-HUMBLE-004`, `UI-ISOLATION-001`, `UI-COPY-001`
- Profiles: `swiftui`
- Reference: `standards/brain/patterns/VIP.md`
- Migration: `MIG-ADR-0009`
