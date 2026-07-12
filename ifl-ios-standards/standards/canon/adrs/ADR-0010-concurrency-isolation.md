# ADR-0010: Concurrency and Isolation

Status: In Review

Owner: Concurrency Chapter Owner

Decision date: 2026-07-13

## Context

Swift 6 makes previously implicit concurrency assumptions visible. A five-year iOS standard needs one
model for isolation, Sendable crossings, task lifetime, cancellation, UI mutation, continuations, and
legacy callbacks without prescribing one business architecture or hiding risk behind unchecked escape
hatches.

## Decision

Adopt Swift 6 complete strict concurrency, assign every mutable state boundary an explicit actor or synchronization owner, require Sendable values across isolation boundaries, prefer structured task ownership, propagate cancellation, isolate UI presentation on MainActor, and adapt one-shot legacy callbacks through exactly-once checked continuations.

An unstructured task is allowed only with an explicit owner and lifetime. `Task.detached` is exceptional
and must justify loss of inherited isolation, task-local values, priority, and cancellation. A repeated
callback is modeled as an `AsyncSequence`, not forced into a one-shot continuation. SwiftUI presentation
stores apply the same isolation and cancellation contract.

## Alternatives considered

- Keep callback queues and informal thread documentation as the concurrency model. Rejected because queue
  delivery does not prove actor isolation, cancellation, or Sendable safety.
- Put all asynchronous code on MainActor. Rejected because it hides ownership, couples business work to UI,
  and creates responsiveness risk.
- Use unstructured or detached tasks by default. Rejected because lifetime, cancellation, and failure
  propagation become implicit.
- Apply `@unchecked Sendable` broadly during migration. Rejected because it suppresses the exact invariant
  the migration must establish.

## Consequences

- Actor ownership and data crossings become explicit and reviewable.
- Some boundary models must become immutable Sendable snapshots.
- Task lifetime and cancellation become part of feature design instead of cleanup after defects.
- Legacy adapters require deliberate terminal-state and cancellation handling.
- UIKit and SwiftUI presentation mutation share one MainActor contract.

## Migration

1. Enable Swift 6 complete strict-concurrency diagnostics incrementally by target.
2. Assign ownership to mutable shared state and isolate UI-facing mutation on MainActor.
3. Replace cross-boundary reference sharing with Sendable values or actor methods.
4. Convert fire-and-forget work to structured or explicitly owned tasks and add cancellation cleanup.
5. Wrap remaining callback/delegate boundaries in checked adapters, documenting temporary unchecked
   conformances with owners and removal dates.

