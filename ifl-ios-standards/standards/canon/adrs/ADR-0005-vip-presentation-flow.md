# ADR-0005 — VIP presentation flow

- Status: Accepted
- Decision date: 2026-07-13
- Owner: iOS Profile Owner

## Context

UIKit and SwiftUI need one testable presentation boundary. If Views format raw data, derive product meaning, perform business I/O, or decide policy, presentation behavior becomes framework-specific and difficult to test without rendering the UI.

## Decision

Presentation follows `View → Interactor → UseCase → Presenter → View`. The Presenter, or an equivalent presentation mapper, converts domain and raw values into display-ready state. UIKit receives that state through a display port; SwiftUI receives the same semantic state through a MainActor presentation store. Views render it, forward typed intent, and may own only transient UX-local state or geometry-only visual calculations. They do not format raw values, derive business meaning, construct business dependencies, or create analytics meaning.

## Consequences

- Presentation mapping is testable without instantiating a View.
- UIKit and SwiftUI can render equivalent semantic state.
- Small interaction and animation state remains local, avoiding needless round trips through business layers.

## Alternatives considered

- A blanket ban on all View conditionals was rejected because rendering an already-decided loading/content/empty/error state is a View responsibility.
- Allowing formatting and computed presentation values in Views was rejected because it makes product output framework-bound and difficult to test.

## Migration

Move raw-value formatting and product decisions into the Presenter or presentation mapper, introduce display-ready state, retain only UX-local View state, and route user intent through typed boundaries.

## Canon mapping

- Rules: `BRD-VIP-001`, `UI-HUMBLE-001`, `UI-HUMBLE-002`, `UI-HUMBLE-003`, `UI-HUMBLE-004`, `UI-ISOLATION-001`, `UI-COPY-001`
- Profiles: `boardy-vip`, `uikit`, `swiftui`
- Reference: `standards/brain/patterns/VIP.md`
- Migration: `MIG-ADR-0005`
