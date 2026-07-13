<!-- Retrofitted to SPEC_CONTRACT 12 sections on 2026-05-23 -->

# SPEC: Board Communication Patterns

> Reference: *Modern large-scale iOS app development* — Micro-services Composable pillar.
> Companion specs: `ARCHITECTURE.md` §4 (runtime composition), `MICROBOARD_UI.md`, `MICROBOARD_NONUI.md`, `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded).

## When to use

When wiring boards together — picking between `sendOutput` / `broadcastAction` / Command, registering flow listeners, setting up `Bus<T>` bridges, or deciding whether/when to call `complete()`.

## When NOT to use

- Single-screen board with no child boards and no parent listener → no communication wiring needed.
- View ↔ Interactor / Interactor ↔ Presenter — those are VIP protocols, see `VIP_COMPONENTS.md`. This spec is for board-to-board edges only.
- Cross-module activation contract — see `IO_INTERFACE.md` for the type shapes; this spec covers the channel mechanics.

## Forces

- Three near-identical-looking channels (`sendOutput` / `broadcastAction` / Command) exist because the direction differs. Collapsing them ("just always sendOutput") leaks signals upward or breaks sibling coordination.
- `Bus<T>` decouples Board from Controller lifetime, but adds one bus declaration per action — pay the cost rather than store controller refs.
- `complete()` semantics differ per board variant. The same call pattern that's required for Viewless is illegal for `BlockTaskBoard`.

## Files

This spec governs wiring inside existing Board files — no new files. Typical edits land in:

```
Sources/Microboards/{Board}/{Board}Board.swift       ← activate() bus connections + registerFlows()
Sources/Microboards/{Board}/{Board}Protocols.swift   ← delegate methods consumed by Board
```

## Naming

- `private let {action}Bus = Bus<{Type}>()` — bus per action; standard names: `completeBus: Bus<Bool>`, `finishBus: Bus<Void>`, `closeBus: Bus<Void>`.
- `registerFlows()` — private extension method; the only legal place flow listeners are wired.
- Delegate methods on the Board map 1:1 to bus transports or service-map activations; no business logic inside the delegate.

## Communication

### The 3 pillars on every `MainboardGenericDestination`

```swift
motherboard.serviceMap.mod{Module}Plugins
    .io{Board}.activation.activate(with: input)        // pillar 1 — fire input
    .io{Board}.flow.addTarget(self) { target, out in } // pillar 2 — listen for output
    .io{Board}.interaction.send(command: .refresh)     // pillar 3 — push command into active board
```

Void variants: `.activation.activate()`, `.interaction.send()`.

### Pick the right channel — direction + target

| Mechanism | Direction | Target | Use when |
|-----------|-----------|--------|----------|
| `sendOutput()` → `.flow` | Board → its motherboard | Direct parent only | Default child→parent signal |
| `broadcastAction()` → `FlowActionType` | Board → upstream chain | Any opt-in ancestor | Concern one or more ancestors need to hear (global event) |
| Command (`.interaction.send`) | Motherboard → child / sibling → sibling | Active board in same motherboard | Push command into an already-active board |

Decision tree:

```
Communicating with the motherboard that activated me (my direct parent)? → sendOutput
Signaling one or more ancestors up the chain?                            → broadcastAction
Pushing into an already-active child or sibling in the same motherboard? → Command via .interaction.send
```

### Bus<T> — Board ↔ managed object

```swift
private let completeBus = Bus<Bool>()
private let finishBus   = Bus<Void>()

// Object subscription with weak target
completeBus.connect(target: self) { target, isDone in
    target.rootViewController.returnHere { [weak target] in
        target?.complete(isDone)
    }
}

// Closure-only subscription (no target lifecycle binding)
finishBus.deliver {
    input.completion?()
}

// Fire
completeBus.transport(input: true)
finishBus.transport()
```

Connection order in `activate`: watch controller → put in context → show → connect buses → deliver input closures.

### registerFlows pattern

```swift
init(identifier: BoardID, ...) {
    super.init(identifier: identifier, boardProducer: producer)
    registerFlows()   // always last in init
}

private extension ParentBoard {
    func registerFlows() {
        motherboard.serviceMap.mod{Module}Plugins
            .ioChildA.flow.addTarget(self) { target, output in
                switch output {
                case .next: target.motherboard.serviceMap.mod{Module}Plugins.ioChildB.activation.activate()
                case .exit: target.closeBus.transport()
                }
            }

        motherboard.serviceMap.mod{Module}Plugins
            .ioChildB.flow.addTarget(self) { target, output in
                switch output {
                case .done, .exit: target.closeBus.transport()
                }
            }
    }
}
```

### Delegate → bus / activation forwarding

```swift
extension {Board}: {Board}Delegate {
    // ActionDelegate (from VC)
    func close(_ isDone: Bool)   { completeBus.transport(input: isDone) }
    func exitFlow()              { closeBus.transport() }

    // ControlDelegate (from Interactor)
    func performCompletion(_ isDone: Bool) { completeBus.transport(input: isDone) }
    func presentChildBoard(with data: SomeData) {
        motherboard.serviceMap.mod{Module}Plugins
            .ioChildBoard.activation.activate(with: data)
    }
    func loadData() {}
}
```

## Concurrency

- All flow listeners and bus consumers fire on the main thread (Boardy convention). Long-running work must be dispatched inside the consumer with `Task { ... await MainActor.run { ... } }`.
- `transport(input:)` is synchronous — observers run before it returns.
- A Board is event-driven and **stateless** by design. Multiple concurrent activations share one bus channel; events are distinguished by **payload content**, not by which activation produced them. The one exception: `BlockTaskBoard` routes results to the originating `BlockTaskParameter` callbacks.

## Composition

This spec sits on top of `MICROBOARD_UI.md` / `MICROBOARD_NONUI.md` — those describe where the board lives; this describes how it talks. ModulePlugin registration shapes are in `PLUGINS_INTEGRATION.md`.

## Lifecycle

### `complete()` semantics

`complete()` tells the motherboard: *this board is fully done — release it.* Calling it twice raises an assertion.

| Board type | Call `complete()`? | Reason |
|------------|--------------------|--------|
| Stateless VIP board | ❌ usually NOT | nothing to release; motherboard manages lifecycle |
| Flow Board (coordinator root) | ✅ after `sendOutput()` | release self once flow ends |
| Viewless Board (with Controller) | ✅ after streams terminated | releases Controller + attached objects |
| BlockTaskBoard | ❌ framework auto-completes | calling manually breaks per-task routing |

Before calling `complete()`:
1. All flows / observers / buses for this board are disconnected or terminated.
2. No further events will arrive at this board.
3. No other object retains a reference that will fire into it.

Order: `sendOutput()` BEFORE `complete()`. After `complete()`, the board is gone.

## Navigation adapters

```swift
motherboard.putIntoContext(viewController)
rootViewController.show(viewController, sender: self) // UIKit dependency-free default
```

Use a project-bound navigation adapter only when UIKit `show(_:sender:)` cannot express a specialized
transition, return-context behavior, or host-controlled container. Such an adapter—including
SiFUtilities when a project explicitly approves it—belongs in the outward navigation shell and does
not become a Domain/Application dependency. For embedded surfaces follow `COMPOSABLE_BOARD.md`.

## Testing

- Bus consumers: assert that `transport(input:)` invokes the connected closure with the expected payload.
- Flow listeners: integration-test by activating a fake child board and asserting the parent's reaction (next activation / bus fire).
- Command / interaction: assert the active board's command handler is invoked with the right enum case.
- `complete()` paths: assert exactly one call per session — easiest via a mock motherboard recording `complete()` invocations.

## Pitfalls

- ❌ `registerFlows()` inside `activate()` → handlers stack per activation.
- ❌ Storing or retrieving controller references to communicate → use buses connected in `activate()`. `watch(content:)` is for lifecycle only.
- ❌ NotificationCenter / global singletons for board events → use Flow pillar or `Bus<T>`.
- ❌ `transport()` before `connect()` / `deliver()` → fires into the void.
- ❌ `sendOutput()` AFTER `complete()` → board already released.
- ❌ `complete()` called twice → assertion. Fix the double-path, don't catch it.
- ❌ `broadcastAction()` to notify direct parent → use `sendOutput()`.
- ❌ Command used child→parent → wrong direction; use `sendOutput()`.
- ❌ `sendOutput()` to push into an already-active child → wrong direction; use Command.
- ❌ Distinguishing per-input results on a regular board → only `BlockTaskBoard` routes per-activation.

## References

- `MICROBOARD_UI.md` / `MICROBOARD_NONUI.md` (where these patterns live)
- `IO_INTERFACE.md` (the types these channels carry)
- `PER_ACTIVATION_RESOURCES.md` (`attachObject` + `complete()` interaction)
- `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded)
- `QUICK_REF.md` §4 rules 7, 8, 12, 13, 14
