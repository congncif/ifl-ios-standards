# ADR-0008 — UIKit rendering adapter

- Status: In review
- Decision date: 2026-07-13
- Owner: iOS Profile Owner

## Context

UIViewController is both a framework lifecycle object and a rendering adapter. Without a strict boundary it easily accumulates formatting, asynchronous orchestration, and dependency construction that belong to presentation or composition layers.

## Decision

A UIKit ViewController receives immutable display-ready state through a display port, renders that state, and forwards typed lifecycle and user events. UI mutation occurs on the declared MainActor boundary. Builders or composition roots construct business dependencies; ViewControllers never construct repositories, use cases, services, or other business dependencies.

## Consequences

- UIKit lifecycle callbacks remain thin and testable through protocol seams.
- Rendering uses the same presentation semantics as SwiftUI.
- Dependency lifetime and ownership stay visible in composition code.

## Alternatives considered

- ViewController-owned presentation mapping was rejected because it couples product output to UIKit.
- Lazy business dependency construction inside ViewControllers was rejected because lifecycle callbacks are not composition roots.

## Migration

Introduce a display port and immutable display-ready state, forward lifecycle events to the Interactor, isolate UI mutation to MainActor, and move dependency construction into the Builder or application composition root.

## Canon mapping

- Rules: `UIKIT-RENDER-001`, `UIKIT-LIFE-001`, `UIKIT-DI-001`
- Profiles: `uikit`
- Reference: `standards/specs/MICROBOARD_UI.md`
- Migration: `MIG-ADR-0008`
