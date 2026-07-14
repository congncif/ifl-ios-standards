<!-- Created 2026-05-23 -->
# SPEC: Bus Patterns

> `Bus<T>` is Boardy's pub-sub channel between a Board and any `AnyObject` target — most often the Board's attached Controller, but also a `userInterface` or sibling object. The wrong filter pattern silently routes events to stale or sibling Controllers; the right one is one extra payload field.

## When to use

Use `Bus<T>` whenever a Board needs to push side-effects into an object it does not own a stored reference to:

- Board → Controller (Viewless) — the canonical case.
- Board → ViewController (UI) — purpose-named navigation buses connected to the concrete
  current/destination ViewController before `show()` or composer exposure.
- Board → sibling object attached via `attachObject(_:)` — same shape.

Two distinct shapes exist; pick by **where the trigger comes from**:

| Shape | Trigger origin | Bus payload | Why |
|-------|---------------|-------------|-----|
| **A — Round-trip** | Object → Board delegate → Bus → Object | Carries the source object (`Bus<{Name}Controllable>` or tuple containing it) | Re-activation can leave older targets connected to the same Bus; payload-carried source + `target === source` is the only correct identity filter |
| **B — Board-originated** | External event (child flow, `complete()` deliver, timer) → Board → Bus → Object | Plain `Bus<Void>` or payload-only | No identity to forward; `bus.connect(target:)` weak-binds the live target — that's enough |

## When NOT to use

- For Controller → Board signalling, use the `Delegate` protocol the Board adopts — **not** a Bus. Buses go Board → target.
- For parent → child Motherboard signalling, use `interaction.send(command:)`, not a Bus.
- For domain async results (UseCase output), use Swift Concurrency / closures inside the Controller — buses are for the Board↔attached-object seam, not the Controller's internal pipeline.

## Forces

- **Buses persist across activations.** `bus.connect(target:)` weak-binds the target, but `bus.transport(input:)` fires every connected closure. Re-activation creates a new target and registers a new closure — the previous closure may still hold a live weak reference. Without an identity filter on round-trip buses, every subscriber receives every event.
- **Closing over a local controller is not a filter.** `guard target === component.controller` where `component.controller` is captured from the enclosing `activate(...)` scope only proves that the closure is the closure created during *that* activation — not that the *event* originated from *that* Controller. Re-activations of an upstream caller can fire the bus and pass the wrong source.
- **`Bus<Void>` is fine when the trigger has no identity.** When a child board's `.flow` fires, there is no Controller to forward — just the Board's own state. The weak-target binding on `bus.connect(target:)` ensures the dead Controllers don't receive the call.
- **Don't fabricate identity.** Calling `attachedObject(_:)` to "look up the current Controller" so you can put it in the bus payload is a retrieved-controller-reference — explicitly forbidden by the Viewless rules. If you don't have an identity at the trigger site, use Shape B.

## Files

`Bus<T>` is declared on the Board class; no dedicated files. Per-board layout:

| Path | Role |
|------|------|
| `Sources/Microboards/{Board}/{Board}Board.swift` | `private let {action}Bus = Bus<{Payload}>()` declarations; `bus.connect(target:)` calls in `activate()`; `bus.transport(input:)` calls from delegate methods and `registerFlows()` closures |
| `Sources/Microboards/{Board}/{Board}Protocols.swift` (or `{Board}Controller.swift` for Viewless) | `ControlDelegate` methods that accept `from controller:` as the first parameter for Shape A |

## Naming

| Element | Convention |
|---------|------------|
| Bus property | `private let {action}Bus = Bus<{Payload}>()` — `{action}` names the concrete action: `cancelBus`, `returnBus`, `childOutputBus`, `refreshBus`. Default name for the input-completion bus is `finishBus`. |
| Shape A payload type | `{Board}Controllable` (the marker protocol the source object conforms to) or a tuple `({Board}Controllable, OutputPayload)` if richer data is needed. |
| Shape A delegate method | Always accept the source as the first parameter: `func didTapClose(from controller: {Board}Controllable)`. |

## Communication

### Shape A — Round-trip with identity filter

```swift
// 1. Declare bus with payload carrying the source
private let childOutputBus = Bus<{Board}Controllable>()

// 2. Connect in activate() — gate on target === source
func activate(withGuaranteedInput input: {Board}Input) {
    let component = builder.build(withDelegate: self, input: input)
    childOutputBus.connect(target: component.controller) { target, source in
        guard target === source else { return }   // ✅ identity filter
        target.didReceiveChildOutput()
    }
    attachObject(component.controller, context: input.context ?? rootViewController)
    component.controller.start()
}

// 3. Delegate method accepts `from controller:` and forwards source through the bus
extension {Board}Board: {Board}Delegate {
    func didReceiveChildOutput(from controller: {Board}Controllable) {
        childOutputBus.transport(input: controller)
    }
}

// 4. Controller passes self when calling the delegate
extension {Board}Controller: {Board}Controllable {
    func someTrigger() {
        delegate?.didReceiveChildOutput(from: self)
    }
}
```

### Shape B — Board-originated

```swift
private let childFlowBus = Bus<Void>()

func activate(withGuaranteedInput input: {Board}Input) {
    let component = builder.build(withDelegate: self, input: input)
    childFlowBus.connect(target: component.controller) { target, _ in
        target.didReceiveChildOutput()   // weak target binding — only live target fires
    }
    attachObject(component.controller, context: input.context ?? rootViewController)
    component.controller.start()
}

private func registerFlows() {
    motherboard.serviceMap.mod{Module}Plugins
        .ioChildBoard.flow.addTarget(self) { target, _ in
            target.childFlowBus.transport(input: ())
        }
}
```

### Direction matrix

| Mechanism | Direction | Shape |
|-----------|-----------|-------|
| `Delegate` method (`from controller:`) | Object → Board | n/a — direct call |
| `Bus<{Controllable}>.transport(input: controller)` | Board → object (round-trip) | A |
| `Bus<Void>.transport(input: ())` | Board → object (Board-originated) | B |
| `sendOutput(_:)` / `flow.addTarget` | Board → caller Motherboard | n/a |
| `interaction.send(command:)` | Motherboard → child Board | n/a |

## Concurrency

- `Bus<T>.transport(input:)` is **synchronous**. The connected closure runs on the calling thread.
- If the closure touches UIKit and the trigger may originate off-main (e.g. `BlockTaskBoard` completion, `Task` callback), wrap the consumer side in `await MainActor.run { [weak self] in ... }` inside the bus closure. Do not hop on the transport side — keep `transport` synchronous and let the consumer decide.
- `bus.connect(target:)` captures the target weakly. Do not also capture it strongly inside the closure (`[target] in ...`) — defeats the lifecycle hook.

## Composition

- Buses are private to the Board class; no ModulePlugin wiring.
- For Composable Boards (`COMPOSABLE_BOARD.md`), each child Board still owns its own buses; the parent Composable does not share buses across children.

## Lifecycle

- Declare buses as stored `private let` properties on the Board — they live as long as the Board does.
- Connect in `activate(...)` AFTER the target object exists. Never connect in `init` (target doesn't exist yet) or `registerFlows()` (would re-register per activation → stacked closures).
- For UI targets, build → `watch(content:)` → connect buses to the concrete ViewController → put it
  into context → expose it through `show()` or the composer. The presentation root is not a valid
  back/return target.
- A Bus may have multiple subscribers across re-activations. The target is held weakly; transport fires every still-live closure. Shape A's identity filter is what makes this safe; Shape B trusts the weak binding alone.
- Buses are not explicitly disconnected. Subscriber lifetime = target lifetime (weak). On `complete()` the Board's bus property is released too.

## Testing

- Round-trip buses: unit-test the Controller's delegate call passes `self`; integration-test that the bus filter actually drops events with a non-matching source (instantiate two Controllers; transport with the wrong source; assert the other Controller's handler did not fire).
- Board-originated buses: assert `bus.transport(input: ())` inside the `registerFlows()` closure delivers to the connected target via a recording mock.
- Do not test `Bus<T>` itself — it's a Boardy primitive; trust the framework.

## Pitfalls

- ❌ **Shape A bus with closed-over local controller as the "filter source"** — `guard target === component.controller` captured from `activate()` scope. The capture is per-activation, not per-event. Re-activations of upstream callers can fire the bus with a different source and pass the guard incorrectly. Carry the source in the payload instead.
- ❌ **Calling `attachedObject(_:)` to fabricate a source** for Shape B — that's a retrieved controller reference (forbidden). If the trigger has no identity, use plain `Bus<Void>` and trust `bus.connect(target:)`'s weak binding.
- ❌ **Connecting the bus in `init`** — target doesn't exist yet; you'll connect to a captured-nil target.
- ❌ **Connecting in `registerFlows()`** — registerFlows runs once per init, but if you re-call it from `activate()` (also wrong), you stack subscribers; if you call it correctly from `init`, the target doesn't exist yet.
- ❌ **Strong target capture inside the closure** (`[target] in ...`) — defeats the weak binding; target stays alive after the Controller would naturally release.
- ❌ **`Bus<T>` for Controller → Board signalling** — wrong direction. Controllers call the Board's `Delegate`; the Board then optionally re-emits via Bus to another attached object.
- ❌ **Calling `bus.transport` from a background thread** when the closure touches UIKit — wrap in `MainActor.run` inside the closure, or guarantee the trigger site is on main.

## References

- `MICROBOARD_NONUI.md` §Communication — Viewless Board where Shape A is the default.
- `MICROBOARD_UI.md` §Communication — UI Board's purpose-named current/destination navigation buses.
- `COMMUNICATION.md` — full channel direction matrix (Bus is one of several channels).
- `EXAMPLES_VIEWLESS_BOARD.md` — complete worked skeleton with both shapes.
- `REVIEWER_CHECKLIST.md` §Non-UI Board — checklist items derived from this spec.
- `BOARDY_FOUNDATIONS.md` — Board ↔ Controller lifecycle ownership; why identity filtering matters at all.
