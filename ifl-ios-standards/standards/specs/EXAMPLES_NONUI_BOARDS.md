<!-- Created by claude-opus-4-7 on 2026-05-09 -->
<!-- Expanded with TaskBoard / ResultTaskBoard / Empty Board variants on 2026-05-23 -->
# EXAMPLES: Non-UI Boards (Flow + BlockTask + TaskBoard + ResultTaskBoard + Empty)

Five patterns for boards with no ViewController. Pick using the decision tree in `MICROBOARD_NONUI.md`. Quick guide:

| Variant | Use when |
|---|---|
| Flow Board | Orchestrate child boards; NO business logic, NO async work. |
| BlockTaskBoard | One async unit; concurrent activations allowed; per-caller success/error handlers. |
| TaskBoard | One async unit; sequential (one at a time); output broadcast to all subscribers. |
| ResultTaskBoard | One async unit; single activation; typed `BoardResult<Success, Failure>`. |
| Empty Board | Pure passthrough / placeholder; no async, no children, no business logic. |

Placeholders: `{Name}` = board name, `{Module}` = module name.

---

## Flow Board

Use when: orchestrating child boards in sequence/parallel with NO business logic.
No Builder. No UseCase calls. Pure routing.

```swift
// Sources/Microboards/{Name}/{Name}Board.swift
import Boardy
import Foundation
import UIKit

final class {Name}Board: ModernContinuableBoard, GuaranteedBoard,
    GuaranteedOutputSendingBoard, GuaranteedActionSendingBoard, GuaranteedCommandBoard {

    typealias InputType = {Name}Input
    typealias OutputType = {Name}Output
    typealias FlowActionType = {Name}Action
    typealias CommandType = {Name}Command

    private let finishBus = Bus<Void>()

    init(identifier: BoardID, producer: ActivatableBoardProducer) {
        super.init(identifier: identifier, boardProducer: producer)
        registerFlows()
    }

    func activate(withGuaranteedInput input: InputType) {
        motherboard.serviceMap.mod{Module}
            .io{ChildA}.activation.activate(with: ChildAInput(context: input.context))
        finishBus.deliver { input.completion?() }
    }

    func activationBarrier(withGuaranteedInput input: InputType) -> ActivationBarrier? { nil }
    func interact(guaranteedCommand: CommandType) {}
}

private extension {Name}Board {
    func registerFlows() {
        motherboard.serviceMap.mod{Module}
            .io{ChildA}.flow.addTarget(self) { target, output in
                switch output {
                case .next:
                    target.motherboard.serviceMap.mod{Module}
                        .io{ChildB}.activation.activate()
                case .done:
                    target.finishBus.transport()
                    target.sendOutput(.completed)
                    target.complete()
                }
            }

        motherboard.serviceMap.mod{Module}
            .io{ChildB}.flow.addTarget(self) { target, _ in
                target.finishBus.transport()
                target.sendOutput(.completed)
                target.complete()
            }
    }
}
```

---

## BlockTask Board

Use when: one discrete async operation, then done. No UI, no child boards.

```swift
// Sources/Microboards/{Name}/{Name}Board.swift
import Boardy
import Foundation

final class {Name}Board: ModernContinuableBoard, GuaranteedBoard,
    GuaranteedOutputSendingBoard, GuaranteedActionSendingBoard, GuaranteedCommandBoard {

    typealias InputType = {Name}Input
    typealias OutputType = {Name}Output
    typealias FlowActionType = {Name}Action
    typealias CommandType = {Name}Command

    private let useCase: {Action}UseCase

    init(identifier: BoardID, useCase: {Action}UseCase, producer: ActivatableBoardProducer) {
        self.useCase = useCase
        super.init(identifier: identifier, boardProducer: producer)
    }

    func activate(withGuaranteedInput input: InputType) {
        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await useCase.execute(input)
                await MainActor.run { [weak self] in
                    self?.sendOutput(.completed(result))
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.sendOutput(.failed(error))
                }
            }
        }
    }

    func activationBarrier(withGuaranteedInput input: InputType) -> ActivationBarrier? { nil }
    func interact(guaranteedCommand: CommandType) {}
}
```

---

## TaskBoard

Use when: one async unit, **sequential** (one activation at a time), output broadcast through motherboard's stream to all subscribers via `flow.addTarget`.

Difference from BlockTask: TaskBoard uses **plain `Input`** (no per-caller `BlockTaskParameter` with `.onSuccess` handlers). Output is published to the motherboard's flow stream, not delivered back through a per-caller closure.

```swift
// Sources/Microboards/{Name}/{Name}BoardFactory.swift
import Boardy
import Foundation

enum {Name}BoardFactory {
    static func make(identifier: BoardID) -> ActivatableBoard {
        TaskBoard<{Name}Input, {Name}Output>(
            identifier: identifier,
            // Board-level processing handler (fires per activation, before executor runs).
            processingHandler: { _ in /* e.g. log analytics */ },
            // Board-level error handler (fires on executor failure).
            errorHandler:      { _, error in /* e.g. log error */ }
        ) { _, input, completion in
            Task {
                do {
                    let result = try await someAsyncWork(input)
                    await MainActor.run { completion(.success(result)) }
                } catch {
                    await MainActor.run { completion(.failure(error)) }
                }
            }
            return .none
        }
    }
}
```

Caller side — output arrives via `flow.addTarget`, not a closure:

```swift
motherboard.serviceMap.mod{Module}
    .io{Name}.flow.addTarget(self) { target, output in
        // handle output
    }
motherboard.serviceMap.mod{Module}
    .io{Name}.activation.activate(with: {Name}Input(/* ... */))
```

---

## ResultTaskBoard

Use when: a **single** async unit per Board lifetime, typed `BoardResult<Success, Failure>` output. No concurrency, no broadcast — one shot, then done.

```swift
// Sources/Microboards/{Name}/{Name}BoardFactory.swift
import Boardy
import Foundation

enum {Name}BoardFactory {
    static func make(identifier: BoardID) -> ActivatableBoard {
        ResultTaskBoard<{Name}Input, {Name}Success, {Name}Failure>(
            identifier: identifier
        ) { _, input, completion in
            Task {
                do {
                    let value = try await someAsyncWork(input)
                    await MainActor.run { completion(.success(value)) }
                } catch let error as {Name}Failure {
                    await MainActor.run { completion(.failure(error)) }
                }
            }
            return .none
        }
    }
}
```

Caller side — activate with `BoardResultParameter` carrying a per-caller `onResult` closure:

```swift
let param = BoardResultParameter<{Name}Input, {Name}Success, {Name}Failure>(input: input)
    .onResult(target: self) { target, result in
        switch result {
        case .success(let value): target.handle(value)
        case .failure(let err):   target.handle(err)
        }
    }
motherboard.serviceMap.mod{Module}
    .io{Name}.activation.activate(with: param)
```

> Difference from BlockTask: BlockTask supports `.concurrent` (multiple parallel activations); ResultTask is **single activation only**. Use ResultTask when "one definite outcome per caller" is the contract (e.g. an authorize call, a one-shot validation).

---

## Empty Board

Use when: a Board ID needs to exist for routing or placeholder purposes but has **no async work, no children, and no business logic**. Same class skeleton as Flow Board but:
- No `finishBus`.
- No `registerFlows()`.
- `activate(...)` typically just `sendOutput(...)` + `complete()` or no-ops.

```swift
// Sources/Microboards/{Name}/{Name}Board.swift
import Boardy
import Foundation

final class {Name}Board: ModernContinuableBoard, GuaranteedBoard,
    GuaranteedOutputSendingBoard, GuaranteedActionSendingBoard, GuaranteedCommandBoard {

    typealias InputType  = {Name}Input
    typealias OutputType = {Name}Output
    typealias FlowActionType = {Name}Action
    typealias CommandType    = {Name}Command

    init(identifier: BoardID, producer: ActivatableBoardProducer) {
        super.init(identifier: identifier, boardProducer: producer)
        // No registerFlows() — there are no flows.
    }

    func activate(withGuaranteedInput input: InputType) {
        // No async, no children. Acknowledge and finish.
        sendOutput(.completed)
        complete()
    }

    func activationBarrier(withGuaranteedInput input: InputType) -> ActivationBarrier? { nil }
    func interact(guaranteedCommand: CommandType) {}
}
```

Use cases:
- Placeholder during scaffolding (will be filled in later).
- Routing hop in a coordinator graph that has no real work to do (e.g. "consume this trigger, emit `.done`, let the parent continue").
- Stub for a feature gated by a build flag.

---

## Variant comparison

| Variant | Async | Concurrent? | Output channel | Class shape |
|---|---|---|---|---|
| Flow | child boards only | n/a | own `sendOutput` after children finish | full `ModernContinuableBoard` |
| BlockTask | yes | `.concurrent` allowed | per-caller `BlockTaskParameter.onSuccess` | `BlockTaskBoard<I, O>` factory |
| Task | yes | sequential | broadcast via `flow.addTarget` | `TaskBoard<I, O>` factory |
| ResultTask | yes | single | per-caller `BoardResultParameter.onResult` | `ResultTaskBoard<I, S, F>` factory |
| Empty | no | n/a | immediate `sendOutput` (often) | full `ModernContinuableBoard`, no flows |

## Pitfalls

- ❌ TaskBoard with `flow.addTarget` listeners expecting per-caller delivery → output goes to ALL subscribers; use BlockTask `.onSuccess` for per-caller routing
- ❌ ResultTaskBoard re-activated → single-activation contract violated; framework asserts
- ❌ Empty Board with `registerFlows` left over from copy-paste → flows fire but Board has no logic to respond
- ❌ Forgetting `await MainActor.run { completion(...) }` in any of TaskBoard / BlockTask / ResultTask executors → main-thread checker fires in subscriber
- ❌ Manually calling `complete()` inside a TaskBoard / BlockTask / ResultTask executor → framework auto-completes; double-complete asserts

## References

- `MICROBOARD_NONUI.md` (full spec — decision tree at the top)
- `MICROBOARD_UI.md` (UI variant)
- `COMMUNICATION.md` (flow + bus patterns)
- `EXAMPLES_VIEWLESS_BOARD.md` (Viewless variant — Board + Controller + Builder)
- `EXAMPLES_BARRIER_BOARD.md` (BarrierBoard variant)
- `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded)
