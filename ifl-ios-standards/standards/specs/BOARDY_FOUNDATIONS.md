<!-- Created 2026-05-23 -->
# SPEC: Boardy Foundations

> Mental model required to read every other Boardy spec. If the rules in `MICROBOARD_*` / `COMMUNICATION` / `BUS_PATTERNS` ever feel arbitrary, the answer is in here: ownership direction, lifecycle independence, attachment context, and the at-most-once completion contract.

## When to use

Read this **first** before any other Boardy spec. The five non-negotiables below are the axioms; everything else is theorem.

1. A Board owns its Controllers / UI — never the reverse.
2. A Board's lifecycle is independent of any Controller's.
3. The attach context is `AnyObject` (UIViewController is convention, not requirement).
4. `watch(content:)` is lifecycle tracking, not a communication channel.
5. `complete()` is called at most once per session.

## When NOT to use

- This spec contains no executable patterns; for code skeletons go to `MICROBOARD_UI.md` / `MICROBOARD_NONUI.md` / `EXAMPLES_*.md`.
- For the bus-specific subset of the ownership story, jump straight to `BUS_PATTERNS.md`.
- For how to wire a Board into a ModulePlugin, see `PLUGINS_INTEGRATION.md`.

## Forces

### Force 1 — Ownership direction is one-way

A Board creates its Controller (via Builder), holds it via `attachObject(_:)`, and releases it on `complete()` / `detachObject(_:)`. The Controller never holds the Board strongly; the Controller's `weak var delegate: {Name}ControlDelegate?` is the only reference back.

If you reverse this direction — "the Board completes when the Controller is gone" — you've built a Board that obeys the Controller's whims and you'll never be able to reason about reactivation, re-entrancy, or cross-flow coordination.

### Force 2 — Lifecycles do not match

A Board may be reactivated many times during a single Motherboard session. Each activation creates a fresh Controller; the old one's lifetime ends with the previous activation's context (UIViewController dying, `detachObject`, `complete()`).

A naïve mental model assumes "one Board = one Controller for life." That model fails the moment the user backgrounds, comes back, and triggers the same flow again — buses fire on two Controllers, attached objects pile up, identity filters become mandatory.

### Force 3 — Attach context is `AnyObject`, not `UIViewController`

`attachObject(_:context:)` accepts `AnyObject` as the context. In practice the context is almost always a UIViewController because UIViewController lifetime is the natural anchor for UI-driven flows. But:

- Any reference type whose deinit point is the right anchor can serve as context (a session manager, a domain coordinator).
- `Input.context` is conventionally typed `weak var context: UIViewController?` — that's the *Input* contract, not the *attachObject* contract.

Don't over-fit to UIViewController. Don't under-think which anchor object owns the lifetime.

### Force 4 — `watch(content:)` ≠ communication

`watch(content: component.controller)` tells Boardy "this Controller is the conformance object for `Controllable`; track it for lifecycle bookkeeping." It is **not** a way to retrieve the Controller later, and it is **not** a Board → Controller communication channel.

For Board → Controller communication, use buses (see `BUS_PATTERNS.md`). Reaching for `watch`-stored content as a communication primitive is the most common Viewless drift.

### Force 5 — `complete()` is at-most-once

A second `complete()` raises an assertion. The cost: every exit path through the Board must converge on exactly one `complete()` call after exactly one `sendOutput()`. The benefit: the framework can deterministically tear down attached objects, child flows, and bus subscribers on completion.

Double-complete usually means two callers each thought they were the terminal path — race conditions in dismissal, error + cancellation arriving in quick succession, etc. Use a single `Bus<{Result}>` consumed once to converge them.

## Files

This spec is foundational and has no files. The patterns it implies are realized in:

| Path | What it materializes |
|------|----------------------|
| `Sources/Microboards/{Board}/{Board}Board.swift` | The Board class — owns Controllers, calls `attachObject`, calls `complete()` once |
| `Sources/Microboards/{Board}/{Board}Controller.swift` | The Controller — holds Board via `weak delegate` |
| `IO/{Board}/{Board}InOut.swift` | `Input.context: UIViewController?` — the conventional context handoff |

## Naming

No new naming rules; defer to `QUICK_REF.md` §Module-naming and `BOARDY_CHEATSHEET.compact.md`.

## Communication

The five rules constrain the channel choices documented in `COMMUNICATION.md`:

| Channel | What this spec implies |
|---------|----------------------|
| `Delegate` (Object → Board) | Controllers must pass `self` as the source for Shape A bus round-trips (consequence of Force 2) |
| `Bus<T>` (Board → Object) | Buses persist; payload must carry identity when source matters (Force 2) |
| `attachObject(_:context:)` | Context choice picks the lifetime anchor — priority below (Force 3) |
| `watch(content:)` | Lifecycle marker only (Force 4) |

### Attachment context priority

| Priority | Choice | When |
|---|---|---|
| **1** | `attachObject(controller, context: input.context)` | Default. Caller owns the natural lifetime anchor — typically a UIViewController, but any `AnyObject` works. |
| **2** | `attachObject(controller, context: rootViewController)` | Flow outlives any single screen but ends with navigation root (logout, splash). |
| **3** | `attachObject(controller)` (no context) | Last resort. Work is intrinsically Board-bound; lifetime ends only on `complete()` / `detachObject(_:)`. Easy to forget and leak. |

## Concurrency

- Boards run on the main Motherboard. Activate / complete / attach operations are main-actor.
- Off-main work happens inside Controller `Task` blocks; consumer side wraps in `await MainActor.run { [weak self] in ... }` before touching Boardy state or UI.
- `Bus<T>.transport` is synchronous on the calling thread — the consumer side decides whether to hop.

## Composition

The mental model implies a fixed composition shape:

```
ModulePlugin
  └── BoardRegistration<{Board}Board>(continuous)
        └── {Board}Board.init(identifier:, builder:, producer:)
              └── builder.build(withDelegate: self, input:) → component
                    ├── component.controller  (attachObject on activate)
                    └── component.userInterface  (motherboard.putIntoContext + show)
```

Boards register once per ModulePlugin `internalContinuousRegistrations`. Controllers are constructed per activation by the Builder. The Builder is the only point where Domain dependencies (UseCases) enter; the Board itself never sees them.

## Lifecycle

Canonical sequence per activation:

```
1. activate(withGuaranteedInput: input)
2. let component = builder.build(...)                    // Controller born here
3. watch(content: component.controller)                  // lifecycle marker
4. (optional) bus.connect(target: component.controller)  // BUS_PATTERNS Shape A or B
5. attachObject(component.controller, context: ...)      // priority 1 → 2 → 3
6. motherboard.putIntoContext(viewController)            // UI only, before show
7. rootViewController.show(viewController)               // UI only, default path
8. component.controller.start()                          // Viewless only
9. … runtime: bus transports / flow callbacks / delegate calls …
10. sendOutput(_:)
11. complete()   // exactly once
```

`registerFlows()` is called from `init`, never from `activate(...)` — flows must be ready before the first activation, and re-registration would stack handlers.

Double-activation guard is added **only** when the Board is explicitly single-session. Default: re-activation is supported.

## Testing

- Unit-test the Controller in isolation: mock the `ControlDelegate`; verify it calls the delegate with `from: self` for round-trip events.
- Integration-test the Board: instantiate twice (simulate re-activation), transport on the bus, verify only the live Controller's handler fires.
- Assert `complete()` is called exactly once across all exit paths — instrument via mock Motherboard or count via test-only override.

## Pitfalls

- ❌ **Storing Controller as a Board property** — breaks Force 2; re-activation collisions guaranteed.
- ❌ **`weak var board` on the Controller pointing to the Board directly** (instead of the Delegate protocol) — breaks Force 1; couples Controller to Board class.
- ❌ **Calling `attachObject(controller)` without `context:` when a natural anchor exists** — breaks Force 3; Controller's lifetime drifts onto the Board's.
- ❌ **Using `watch(content:)`-stored content as a way to call into the Controller** — breaks Force 4; use a Bus.
- ❌ **Two exit paths each calling `complete()`** — breaks Force 5; converge them on a single `Bus<Result>`.
- ❌ **Reasoning about a Board as "one screen"** — the Board may outlive any single UIViewController; the screen is the *context*, not the *Board*.

## References

- `BUS_PATTERNS.md` — direct consequence of Force 2; the two bus shapes and their identity filters.
- `MICROBOARD_UI.md` / `MICROBOARD_NONUI.md` — the variants that realize this mental model.
- `COMMUNICATION.md` — direction matrix across channels.
- `compact/BOARDY_CHEATSHEET.compact.md` — the one-page cheatsheet ios-coder default-loads.
- `REVIEWER_CHECKLIST.md` — checklist items derived from these five forces.
- `QUICK_REF.md` rules 7, 8, 12, 13 — the foundational rules in the project rulebook.
