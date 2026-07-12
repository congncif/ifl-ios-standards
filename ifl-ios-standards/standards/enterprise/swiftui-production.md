# SwiftUI Production Standard

## Purpose

Use SwiftUI as a production rendering adapter without moving product decisions, presentation derivation,
navigation policy, or dependency construction into Views. This chapter specializes the shared humble-View
and concurrency Rules for the `swiftui` Profile.

## Applicability

Apply to SwiftUI screens, reusable View components, hosting-controller integrations, presentation stores,
navigation adapters, and mixed UIKit/SwiftUI features. It covers both new features and incremental
migration of existing UIKit modules.

## Non-negotiable rules

- `SWUI-STATE-001`: a `MainActor` presentation store owns display-ready product state; dependencies are
  injected outside the View.
- `SWUI-VIEW-001`: View-local state is limited to transient UX and rendering mechanics; Views do not
  derive product meaning or format raw/domain values.
- `SWUI-LIFE-001`: asynchronous View work is scoped to stable feature or View identity and cancels when
  that scope ends.
- `SWUI-ID-001`: collections, navigation destinations, and state restoration use stable semantic identity.
- `SWUI-NAV-001`: Views emit typed navigation intent; business navigation policy is resolved outside
  rendering.
- `SWUI-PERF-001`: Observation, invalidation, and collection rendering are bounded to the smallest useful
  state and measured against product-specific budgets.
- `SWUI-INTEROP-001`: UIKit and SwiftUI adapters consume the same display-ready state and typed intents;
  an interoperability layer does not remap business semantics.

The shared `UI-HUMBLE-*`, `UI-ISOLATION-001`, `CONC-ISO-001`, and `CONC-CANCEL-001` Rules also apply.

## Decision guidance

Put product state and prepared text, labels, accessibility meaning, CTA availability, and error mapping in
the Presenter or equivalent mapper. Put only focus, pressed/highlight state, gesture progress, animation,
scroll position, disclosure, and short-lived input mechanics in View-local state. If changing a value can
change eligibility, price, product status, analytics meaning, or business navigation, it is not local View
state.

Prefer one presentation store per coherent screen or feature boundary. Split observation when unrelated
updates invalidate expensive subtrees. Use `task(id:)` when work is tied to semantic identity. A coordinator
or injected navigation port owns destination policy; `NavigationStack` remains a rendering mechanism.

## Implementation patterns

### Injected MainActor store

```swift
@MainActor
@Observable
final class OrderPresentationStore {
    private(set) var state: OrderViewState
    private let send: (OrderIntent) -> Void

    init(state: OrderViewState, send: @escaping (OrderIntent) -> Void) {
        self.state = state
        self.send = send
    }

    func handle(_ intent: OrderIntent) { send(intent) }
}
```

The composition root constructs the store. The View neither creates repositories nor maps raw orders to
display text.

### Humble View and UX-local state

```swift
struct OrderView: View {
    let store: OrderPresentationStore
    @State private var isDetailsExpanded = false

    var body: some View {
        content(for: store.state)
    }
}
```

Branching on `.loading`, `.content`, `.empty`, or `.error` is permitted because the decision is already in
display-ready state. The disclosure flag controls rendering mechanics only.

### Scoped task

Tie refresh or stream consumption to stable state such as `orderID`, use `task(id:)`, propagate
cancellation to the use case, and avoid spawning another untracked `Task` inside the task body.

### Bounded collection rendering

Use stable model IDs, lazy containers for potentially large collections, paged or otherwise bounded data,
and a narrow observed state surface. Define performance budgets from actual product interactions instead of
one universal row count or render-time constant.

## Compliant and non-compliant examples

Compliant: `if case .error(let display) = store.state` renders `display.message` and sends
`.retryTapped` when the prepared state says retry is available.

Non-compliant: the View checks a domain error and retry count, formats its message, and decides whether
retry is allowed.

Compliant: a `ForEach` uses the stable `OrderRowState.id` prepared for the View and renders a lazy, paged
collection.

Non-compliant: a `ForEach` uses array offsets or fresh UUID values and eagerly renders an unbounded result.

Compliant: UIKit and SwiftUI adapters receive the same `OrderViewState` and forward the same `OrderIntent`.

Non-compliant: the hosting bridge reinterprets status, price, navigation, or analytics semantics for one UI
framework.

## Anti-patterns

- Constructing use cases, repositories, clients, or service locators in a View.
- Storing the product entity itself in `@State` and deriving display values in `body`.
- Formatting dates, currency, quantity, status, or errors in a View extension.
- Triggering business navigation as a side effect of rendering a state branch.
- Starting unscoped tasks in `onAppear` without cancellation or stable identity.
- Observing a large mutable model when a small immutable display state is sufficient.
- Using indexes, transient UUIDs, or mutable hashes as collection identity.
- Adding an interoperability mapper that produces different product meaning per framework.

## Verification

The single final joined AI review examines the complete Standards 1.0 change for presentation-store
ownership, humble Views, scoped cancellation, stable identity, navigation separation, bounded invalidation,
and UIKit/SwiftUI semantic parity. This chapter defines no plugin verifier, fixture gate, receipt, or build
command.

## Exceptions

There is no exception for business decisions, product-facing formatting, business dependency construction,
or unscoped work in a View. A performance exception records the measured interaction, affected state and
subtree, current budget, owner, expiry, and remediation plan; it cannot redefine product semantics or waive
stable identity.

## Migration and adoption

1. Freeze the existing semantic output and typed user intents before changing the rendering framework.
2. Introduce a `MainActor` presentation store that receives the existing display-ready state.
3. Move raw/domain formatting and decisions out of SwiftUI Views into the Presenter or equivalent mapper.
4. Reduce View-local state to UX mechanics and inject all business dependencies at composition.
5. Scope async work and navigation to stable feature identity.
6. Measure invalidation and collection behavior, then migrate one adapter at a time while UIKit and SwiftUI
   consume the same semantic contract.

## Ownership

The SwiftUI Profile Owner owns this chapter. Feature owners own their presentation-store and navigation
boundaries. The Concurrency Chapter Owner owns the shared isolation and cancellation semantics referenced
here.

## Metrics

Track screens with injected presentation stores, Views containing business dependencies or raw formatting,
unscoped task count, unstable-identity defects, observed invalidations for critical interactions, large-list
render latency, and UIKit/SwiftUI semantic-parity regressions.

## Review cadence

Review at least annually, when the supported SwiftUI Observation/navigation model changes, and after a
material performance or state-restoration incident. Reassess each active performance exception before
expiry.

