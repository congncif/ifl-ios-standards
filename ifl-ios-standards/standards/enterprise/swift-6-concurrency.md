# Swift 6 Concurrency Standard

## Purpose

Make asynchronous iOS code race-safe, cancellation-aware, and understandable under Swift 6 complete
strict concurrency. This chapter applies ADR-0010 through the `CONC-*` Canon Rules; those Rules remain
the normative authority.

## Applicability

Apply this chapter to every Swift target, including application, feature, service, infrastructure,
test-support, and UI-adapter code. Existing callback or delegate APIs enter the same boundary when they
are adapted to async code. Build-system migration may be incremental, but new or materially changed
code follows the complete model.

## Non-negotiable rules

- `CONC-ISO-001`: declare the actor that owns mutable state; UI and presentation-store mutation belongs
  to `MainActor`.
- `CONC-SEND-001`: values crossing isolation boundaries are genuinely `Sendable`, immutable value
  snapshots, or remain confined to their owning actor.
- `CONC-TASK-001`: structured tasks are the default and every unstructured task has an explicit owner,
  lifetime, and completion policy.
- `CONC-CANCEL-001`: cancellation propagates, is observed at useful suspension or work boundaries, and
  performs required cleanup.
- `CONC-CONT-001`: every checked continuation resumes exactly once on every terminal callback path.
- `CONC-LEGACY-001`: callback, delegate, notification, and Objective-C bridges use a documented checked
  adapter that defines isolation, cancellation, lifetime, and terminal behavior.

## Decision guidance

Choose immutable values first. Use an actor when mutable state has one logical owner and operations must
be serialized. Use `MainActor` only for UI-facing ownership, not as a blanket way to silence isolation
errors. Prefer child tasks, task groups, and `async let` when work belongs to a caller. Use an
unstructured `Task` only when a named owner retains or otherwise bounds it. `Task.detached` is reserved
for work that intentionally inherits no actor, task-local values, priority, or cancellation; that choice
must be visible at the call site.

Use an `AsyncSequence` for repeated events. Use a checked continuation only for one terminal result.
When a callback API can finish more than once, normalize it behind a single-resume state machine or use
an event sequence instead of trusting callback behavior.

## Implementation patterns

### Actor-owned mutable service

```swift
actor SessionCache {
    private var session: SessionSnapshot?

    func replace(with value: SessionSnapshot?) { session = value }
    func current() -> SessionSnapshot? { session }
}
```

`SessionSnapshot` is an immutable `Sendable` value. The actor does not return a mutable reference that
escapes its isolation.

### MainActor presentation ownership

```swift
@MainActor
final class CheckoutPresentationStore {
    private(set) var state: CheckoutViewState = .loading

    func display(_ state: CheckoutViewState) {
        self.state = state
    }
}
```

Domain work may run elsewhere; only the display-ready value crosses to this store.

### Scoped work and cleanup

```swift
try await withTaskCancellationHandler {
    try Task.checkCancellation()
    return try await client.loadOrder()
} onCancel: {
    client.cancelOrderRequest()
}
```

The adapter remains responsible for reconciling a legacy API that races cancellation with completion.

### Checked legacy bridge

Keep the continuation private to the adapter, map all success and failure callbacks to one terminal
result, and protect resume with one owned completion state. Document executor delivery, cancellation,
delegate retention, and whether late callbacks are ignored or diagnosed.

## Compliant and non-compliant examples

Compliant: a feature owns a child task, cancellation of the feature cancels the child, the service actor
returns a `Sendable` snapshot, and the Presenter hops to a `MainActor` store to display it.

Non-compliant: a `Task.detached` captures a non-Sendable repository, outlives the screen, ignores
cancellation, and mutates a presentation store from the detached executor.

Compliant: a one-shot delegate callback is wrapped with a checked continuation and an adapter-owned
single-resume guard covering success, error, cancellation, and teardown.

Non-compliant: two delegate methods can each resume the same continuation or one error path never
resumes it.

## Anti-patterns

- Applying `@MainActor` to entire business or infrastructure layers to suppress diagnostics.
- Declaring `@unchecked Sendable` without a reviewed synchronization invariant.
- Starting fire-and-forget tasks inside initializers, property observers, or Views without ownership.
- Catching `CancellationError` and continuing normal work.
- Holding a lock across `await` or exporting actor-owned mutable references.
- Treating callback queue documentation as Swift actor isolation.

## Verification

The single final joined AI review examines the complete Standards 1.0 change for explicit isolation,
Sendable boundary integrity, task ownership, cancellation, exactly-once continuation semantics,
MainActor presentation mutation, and consistency with ADR-0010. This chapter defines no plugin verifier,
fixture gate, receipt, or standalone build command.

## Exceptions

No exception permits a known data race, an unowned task, or a continuation that can resume zero or
multiple times. A temporary legacy exception records the exact API boundary, isolation and lifetime
hazard, compensating containment, accountable owner, expiry, and removal plan. `@unchecked Sendable` is
such an exception, not a migration shortcut.

## Migration and adoption

1. Enable Swift 6 language mode and complete strict-concurrency diagnostics target by target.
2. Inventory mutable shared state and assign one actor or explicit synchronization owner.
3. Convert boundary models to immutable `Sendable` values; keep vendor types inside adapters.
4. Replace fire-and-forget work with structured tasks or an explicitly retained owner.
5. Add cancellation and cleanup before converting callback APIs.
6. Wrap remaining legacy callbacks in checked, documented adapters and remove temporary unchecked
   conformances as their owners migrate.

## Ownership

The Concurrency Chapter Owner owns this chapter and ADR-0010. Module owners own the isolation and task
lifetime of their code. The SwiftUI Profile Owner owns consistency where presentation stores and
view-scoped tasks consume these Rules.

## Metrics

Track strict-concurrency adoption by target, unresolved Swift concurrency diagnostics, count and age of
`@unchecked Sendable` declarations, unstructured and detached task inventory, cancellation-related
defects, and continuation misuse incidents. Metrics guide migration; they never waive a Rule.

## Review cadence

Review at least annually, and whenever the supported Swift language mode, concurrency runtime behavior,
or a shared asynchronous adapter materially changes. Reassess any temporary exception before its expiry.

