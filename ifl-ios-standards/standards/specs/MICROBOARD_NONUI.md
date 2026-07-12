<!-- Created by claude-opus-4-7 on 2026-05-09 -->
<!-- Retrofitted to SPEC_CONTRACT 12 sections on 2026-05-23 -->

# SPEC: Microboard without UI (Non-UI Boards)

> Reference: *Modern large-scale iOS app development* — Micro-services Composable pillar.
> Companion specs: `MICROBOARD_UI.md` (UI variant), `COMMUNICATION.md` (flow + bus patterns), `EXAMPLES_NONUI_BOARDS.md` / `EXAMPLES_VIEWLESS_BOARD.md` (worked skeletons), `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded).

## When to use

Decision tree (answer in order):

```
Does the board show UI?  YES → MICROBOARD_UI.md.  NO → continue.

Coordinator that orchestrates child boards?
  STOP: does an existing VIP board already serve as the entry point?
        YES → let that VIP board coordinate via registerFlows(). No Non-UI wrapper.
        NO  → continue.
  Needs conditional entry gate before the first UI screen?  → FlowBoard as CHILD of UI entry board.
  Needs to be reused from multiple distinct entry points?    → FlowBoard.
  Needs to STORE child A's output to pass into child B?     → Viewless Board.
  Pure stateless pass-through routing?                       → FlowBoard.

Single async operation, caller wants per-activation result?
  YES → BlockTaskBoard (BlockTaskParameter; .concurrent supported).

Single async operation, result goes to motherboard output stream?
  Multiple activations in flight? → BlockTaskBoard (.concurrent).
  Sequential, one at a time?      → TaskBoard.
  Single activation, no side effects → ResultTaskBoard.

Block an action until a prerequisite completes?  → BarrierBoard.
Fully custom?                                    → Empty Board.
```

## When NOT to use

- Existing VIP UI board can own the coordination. Don't wrap it in a Non-UI FlowBoard.
- The board needs to render anything → that's a UI board, use `MICROBOARD_UI.md`.
- The "board" is really a service or repository → it belongs in `Sources/Services/`, not `Sources/Microboards/`.

## Forces

- **Stateless Flow vs stateful Viewless** (`BRD-VIEWLESS-001`): stateless wins on simplicity but cannot carry state between child boards. Adding `private var someState` to a Flow board is the most common drift — promote it to Viewless.
- **Direct controller refs vs event buses (Viewless)**: storing the controller breaks re-activation; bus-based wiring is correct but costs one `Bus<T>` per action. Pay the cost.
- **Controller attachment context — Board lifecycle ≠ Controller lifecycle**: a Board has its own lifecycle independent of any controller; binding a Controller's lifetime to the Board's by default causes drift and surprise releases. The attach context is `AnyObject` (most commonly a UIViewController, but not pinned to it). Default to explicit input context for max control, fall back to root context, treat board context as last resort. Cost: one extra `context` field in `Input` (typically `UIViewController?`) for the common case; pay it.
- **Bus identity-filter applies to round-trips, not Board-originated transport**. Controller → Board delegate → Bus → Controller round-trips need an identity payload (`Bus<{Board}Controllable>` or a tuple containing it) so the subscriber can `guard target === source`; closing over a local controller variable does *not* work because the closure outlives the activation. Board-originated transport (e.g. child flow → Board → Controller) needs no identity payload — `bus.connect(target:)` weak-binds the live Controller.
- **BlockTask `.concurrent` vs `.flow` listening** (`BRD-BLOCKTASK-001`): `.flow` is shared across concurrent activations and cannot distinguish callers; parameter callbacks (`onSuccess`/`onError`) are the only safe routing.

## Files

The bundled CLI creates the public contract separately from the implementation:

```text
IO/{Board}/
├── {Board}IOInterface.swift            ← public BoardID + destination/factory
├── {Board}InOut.swift                  ← public Input/Output/Command/Action
└── ServiceMap+{Board}.swift            ← public module ServiceMap accessor

Sources/Microboards/{Board}/
├── {Board}BoardIOInterface.swift       ← internal alias to the public ID
├── {Board}BoardInOut.swift             ← internal aliases to public InOut
└── ServiceMap+{Board}.swift            ← Plugins ServiceMap accessor
```

`IO/**` is public. `Sources/**` stays internal, except for an explicitly justified public
composition type under `Sources/Plugins/**`.

### Flow Board (stateless coordinator)

```text
Sources/Microboards/{Board}/
└── {Board}Board.swift                  ← orchestration shell; no per-activation state
```

### Viewless Board (stateful coordinator)
```text
Sources/Microboards/{Board}/
├── {Board}Protocols.swift              ← Controllable / ControlDelegate / Delegate / Interface / Buildable
├── {Board}Controller.swift             ← NSObject; owns input + UseCases + state
├── {Board}Builder.swift                ← creates Controller, injects deps
└── {Board}Board.swift                  ← thin shell; registers flows; attaches Controller
```

### BlockTaskBoard / TaskBoard / ResultTaskBoard
```text
Sources/Microboards/{Board}/
└── {Board}BoardFactory.swift           ← enum factory returning the appropriate task Board
```

### BarrierBoard / Empty Board — minimal subset of the above as required.

## Naming

- A scaffolded public BoardID is exactly `"pub.mod.{Module}.{Board}"` and lives in `IO/{Board}/`.
  The implementation aliases that public ID instead of creating a competing internal literal.
- A genuinely module-private board may use `"mod.{Module}.{Board}"`, but the current CLI always
  creates public IO and therefore is not the tool for silently making an internal-only contract.
- Factory pattern: `enum {Board}BoardFactory { static func make(...) -> ActivatableBoard }` — never a class with `init`.
- Buses: `private let {action}Bus = Bus<{Type}>()`. Default name `finishBus` for the input-completion bus.

## Communication

### Scaffold boundary

```bash
ifl-new-board <Module> <Board> <viewless|flow|blocktask> \
  --root=. --module-root=<repo-owned-module-root>
```

The command also accepts `--dry-run`; `--root` defaults to the current directory. Module and Board
names must start uppercase. It requires the module directory to exist and refuses to write when
either `IO/{Board}/` or `Sources/Microboards/{Board}/` already exists.

The CLI creates public IO and a type-specific implementation starter. It does not infer domain
behavior, child flows, attachment ownership, dependencies, registration, or tests. After generation,
define real InOut types, fill the TODOs, register the Board in `{Module}ModulePlugin`, and reconcile
new IO dependencies with the consuming repository's build system.

The `blocktask` selector emits `BlockTaskParameter` public IO and a `BlockTaskBoard` factory with a
fail-fast execution placeholder. Replace that placeholder with project-owned async behavior and
MainActor completion before activation; never replace per-activation callbacks with shared flow
listeners when concurrency is allowed.

For a generated Viewless board, the skeleton applies input context → root context. Use board context
only as an explicit last-resort product decision; the generator does not silently choose it.

All paths, target labels, dependencies, destinations, and verification commands are consuming-repo
values; do not copy a product-specific scaffold default into the design.

### Flow Board
```swift
final class {Board}Board: ModernContinuableBoard, GuaranteedBoard,
    GuaranteedOutputSendingBoard, GuaranteedActionSendingBoard, GuaranteedCommandBoard {

    typealias InputType = {Board}Input
    typealias OutputType = {Board}Output
    typealias FlowActionType = {Board}Action
    typealias CommandType = {Board}Command

    private let finishBus = Bus<Void>()

    init(identifier: BoardID, producer: ActivatableBoardProducer) {
        super.init(identifier: identifier, boardProducer: producer)
        registerFlows()
    }

    func activate(withGuaranteedInput input: InputType) {
        motherboard.serviceMap.mod{Module}Plugins
            .ioChildBoard.activation.activate(with: ChildBoardInput(context: input.context))
        finishBus.deliver { input.completion?() }
    }

    func activationBarrier(withGuaranteedInput input: InputType) -> ActivationBarrier? { nil }
    func interact(guaranteedCommand: CommandType) {}
}

private extension {Board}Board {
    func registerFlows() {
        motherboard.serviceMap.mod{Module}Plugins
            .ioChildBoard.flow.addTarget(self) { target, output in
                switch output {
                case .done:
                    target.finishBus.transport()
                    target.complete()
                }
            }
    }
}
```

`finishBus.deliver {}` for closure-only callbacks; `finishBus.connect(target:) {}` when you need a weak object reference.

### Viewless Board

Board is stateless; Controller is `NSObject` and holds everything. All Board→Controller comms via `Bus<T>`:

```swift
final class {Board}Board: ModernContinuableBoard, ... {
    private let builder: {Board}Buildable
    private let childOutputBus = Bus<ChildOutputType>()

    init(identifier: BoardID, builder: {Board}Buildable, producer: ActivatableBoardProducer) {
        self.builder = builder
        super.init(identifier: identifier, boardProducer: producer)
        registerFlows()
    }

    func activate(withGuaranteedInput input: {Board}Input) {
        let component = builder.build(withDelegate: self, input: input)
        childOutputBus.connect(target: component.controller) { controller, output in
            controller.didReceiveChildOutput(output)
        }
        attachObject(component.controller)
        component.controller.start()
    }
}

extension {Board}Board: {Board}Delegate {
    func activateChildBoard(context: UIViewController?) { /* serviceMap.ioChild.activation.activate */ }
    func finishFlow(output: {PublicBoard}Output) { sendOutput(output); complete() }
}

private extension {Board}Board {
    func registerFlows() {
        motherboard.serviceMap.mod{Module}Plugins
            .ioChildBoard.flow.addTarget(self) { target, output in
                target.childOutputBus.transport(input: output)
            }
    }
}

final class {Board}Controller: NSObject {
    weak var delegate: {Board}ControlDelegate?
    private let input: {Board}Input
    private let someUseCase: SomeUseCase
    private var state: Bool = false

    init(input: {Board}Input, someUseCase: SomeUseCase) {
        self.input = input; self.someUseCase = someUseCase
    }
}

extension {Board}Controller: {Board}Controllable {
    func start() { delegate?.activateChildBoard(context: input.context) }
    func didReceiveChildOutput(_ o: ChildOutputType) {
        Task { [weak self] in
            let result = try await self?.someUseCase.execute()
            await MainActor.run { [weak self] in
                self?.state = true
                self?.delegate?.activateChildBoard(context: self?.input.context)
            }
        }
    }
}
```

### Controller Attachment Context (Viewless)

A Viewless Controller needs to be retained until its job is done. Boardy's attach context is `AnyObject` — typically a `UIViewController`, but any reference type whose lifecycle is the right anchor will do. Choose the attachment context in this priority order — the higher choices give you tighter, more explicit lifecycle control:

| Priority | Choice | When |
|---|---|---|
| **1** | **Explicit input context** — `attachObject(component.controller, context: input.context)` | Default. Controller's lifetime tracks a specific object the caller already owns (most commonly the UIViewController that spawned the flow, but any `AnyObject` will do). Caller passes `context` via `Input`; Board attaches Controller to it. Frees automatically when that object dies. |
| **2** | **Root context** — `attachObject(component.controller, context: rootViewController)` | When the flow must outlive any single screen but ends with the navigation root (logout flow, global splash). Avoids accidentally being tied to a transient VC. |
| **3** | **Board context** — `attachObject(component.controller)` (no context) | Last resort: only when the work is intrinsically Board-bound (one-shot orchestration whose end signal is `complete()` itself, no external lifetime to anchor to). Controller released only on `complete()` / `detachObject(_:)` — easy to forget and leak. |

There are two Board→Controller bus shapes; pick by where the trigger comes from:

**(A) Round-trip (Controller → Board delegate → Bus → Controller).** Identity-filter is needed because re-activations can leave older Controllers connected to the same Bus. The Controller passes `self` as the source; the bus payload carries it; the subscriber gates with `target === source`. Closing over a local controller variable does **not** prove identity — the closure outlives the activation.

```swift
private let childOutputBus = Bus<{Board}Controllable>()   // payload carries source

func activate(withGuaranteedInput input: {Board}Input) {
    let component = builder.build(withDelegate: self, input: input)

    childOutputBus.connect(target: component.controller) { target, source in
        guard target === source else { return }      // ✅ identity filter
        target.didReceiveChildOutput()
    }

    // Priority 1 — explicit input context (preferred)
    if let context = input.context {
        attachObject(component.controller, context: context)
    } else {
        // Priority 2 — root context
        attachObject(component.controller, context: rootViewController)
    }
    // Priority 3 — `attachObject(component.controller)` only when neither applies.

    component.controller.start()
}

extension {Board}Board: {Board}Delegate {
    func didReceiveChildOutput(from controller: {Board}Controllable) {
        childOutputBus.transport(input: controller)  // forward source
    }
}
```

When the round-trip carries richer data, use a tuple/struct including the source: `Bus<({Board}Controllable, OutputPayload)>`.

**(B) Board-originated transport (e.g. child board's flow → Board → Controller).** No round-trip; the trigger has no Controller identity to forward. `bus.connect(target:)` already weak-binds the target — only the live Controller fires. Plain `Bus<Void>` (or payload-only) is correct; **do not** retrieve `attachedObject(...)` to fabricate a source (that violates "never retrieve controller refs").

```swift
private let childFlowBus = Bus<Void>()

private func registerFlows() {
    motherboard.serviceMap.mod{Module}Plugins
        .ioChildBoard.flow.addTarget(self) { target, _ in
            target.childFlowBus.transport(input: ())
        }
}
```

Rules:
- **Round-trip buses carry the source Controller**; subscriber gates with `guard target === source`. Closing over a local controller variable is not a filter.
- **Board-originated buses** rely on `bus.connect`'s weak target binding — no identity payload, no retrieval.
- **Never bind the Board itself to a Controller's lifetime** — Board outlives or pre-dates the Controller; the relationship is one-way (Board owns Controller).
- `Input.context` is conventionally typed `weak var context: UIViewController?` (see `IO_INTERFACE.md`) — that covers the common case; broader anchor types are possible when the caller genuinely owns a non-VC reference.

### BlockTaskBoard
```swift
enum {Board}BoardFactory {
    static func make(identifier: BoardID, executingType: ExecutingType = .concurrent) -> ActivatableBoard {
        BlockTaskBoard<{Board}Input, {Board}Output>(
            identifier: identifier,
            executingType: executingType
        ) { _, input, completion in
            Task {
                let result = try await someAsyncWork(input)
                await MainActor.run { completion(.success(result)) }   // ⚠ MainActor required
            }
            return .none
        }
    }
}
```

Caller side: `let param = {Board}Parameter(input: ...).onSuccess(target: self) { t, r in ... }; motherboard.io{Board}().activation.activate(with: param)`.

### TaskBoard / ResultTaskBoard / BarrierBoard / Empty
- **TaskBoard**: like BlockTask but plain `Input`; output goes to motherboard stream; `processingHandler` / `errorHandler` are board-level.
- **ResultTaskBoard**: single activation, `BoardResult<Success, Failure>`.
- **BarrierBoard**: `typealias {Board}BarrierBoard = BarrierBoard<{Board}Input>` + caller activates with `.wait { result in ... }`; `.overcome(...)` / `.cancel` to release.
- **Empty Board**: same class skeleton as Flow but no `finishBus` and no `registerFlows`.

## Concurrency

- `BlockTaskBoard` / `TaskBoard` completion **always** wrapped in `await MainActor.run { completion(.success(...)) }`. Motherboard runs on main; the executor may run on a background thread.
- Viewless Controller async branches: `Task { [weak self] in ... await MainActor.run { [weak self] in ... } }`.
- `Bus<T>.transport(input:)` is synchronous; consumers that touch UIKit must hop to MainActor themselves.
- `weak var delegate` on Viewless Controller; Board adopts the matching Delegate.

## Composition

ModulePlugin registration shapes:

```swift
// Flow board (no Builder)
{Board}Board(identifier: identifier, producer: internalContinuousProducer)

// BlockTask / Task / ResultTask (factory)
BoardRegistration(.mod{Module}{Board}) { id in
    {Board}BoardFactory.make(identifier: id /*, deps */)
}

// Viewless (Builder injects use cases)
let builder = {Board}Builder(someUseCase: SomeUseCaseInteractor(repository: sharedRepository))
return {Board}Board(identifier: identifier, builder: builder, producer: internalContinuousProducer)
```

Internal IO alias when implementing a public ID:
```swift
extension BoardID { static let mod{Board}: BoardID = .pub{PublicBoard} }
```

## Lifecycle

- `registerFlows()` always in `init`, never in `activate` (`BRD-FLOW-001`). Flows transport via buses.
- `activationBarrier` returns `nil` unless implementing a Barrier.
- `attachObject(controller, context:)` (Viewless) — pick context per priority table in Communication §Controller Attachment Context. Lifecycle:
  - With **input context** (priority 1) or **root context** (priority 2) → Controller is released when the attached UIViewController is released; Board lifecycle stays independent.
  - With **board context** (priority 3, no `context:`) → Controller stays attached until `complete()` (ends session, releases all attached) or `detachObject(_:)` (release one). Forgetting either → re-activation stacks Controllers on the same buses → duplicate handler firings.
  - Only Controller→Board→Bus→Controller round-trips carry and compare source identity. Board-originated
    buses rely on `bus.connect(target:)` weak binding and do not fabricate a source (`BRD-VIEWLESS-001`).
- `complete()` decision per variant:

| Board type | Call `complete()`? |
|------------|-------------------|
| Stateless VIP / Flow leaf | Usually NOT — parent handles |
| Flow board that IS coordinator root | ✅ after `sendOutput()` |
| Viewless | ✅ after `sendOutput()`, after streams terminated |
| BlockTaskBoard | ❌ framework auto-completes |

- Double-`complete()` raises an assertion — confirm all streams are terminated before calling (`BRD-LIFE-001`).
- Always `sendOutput()` BEFORE `complete()`.

## Testing

- Flow board: assert child activation + completion bus delivery — usually integration tests against a fake child board.
- Viewless: priority on Controller tests (mock Delegate; use real Use Cases or stubbed). The Board class is rarely tested directly.
- BlockTask / Task / ResultTask: test the executor closure with a fake `completion` handler; assert MainActor hop happens (use `await Task.yield()` and check completion fires on main).
- BarrierBoard: test `.wait` / `.overcome` / `.cancel` paths through the motherboard.
- See `compact/TESTING.compact.md`.
- Never add a placeholder-only test to make a scaffold or test glob look complete.
- An executable scaffold change gets one targeted native signal from the consuming repository.
  Documentation-only changes get no build or test.
- Do not add verifier scripts, receipts, manifests, or custom workflow-state files. Report the direct
  native command result when an executable signal is required.

## Pitfalls

- ❌ Storing `input` / `context` on the Board — must live in Controller (Viewless) or be captured in closures (Flow).
- ❌ Calling `registerFlows()` from `activate()` → stacked handlers per activation.
- ❌ Storing the Controller reference on the Board → re-activation collisions; use buses + `attachObject`.
- ❌ `attachObject(controller)` without a `context:` when the work has a natural reference owner (typically a UIViewController, but any `AnyObject`) → Controller's lifetime drifts onto the Board's; use priority-1 input context or priority-2 root context instead.
- ❌ Binding Board lifecycle to Controller (e.g. completing the Board when the context object dies) → reverses the ownership direction; Board owns Controller, not the other way around.
- ❌ `Bus<Void>` + `guard target === component.controller` captured from the closure on a Controller→Board→Bus→Controller round-trip → not an identity filter; the local controller variable outlives the activation. Carry the source in the bus payload (`Bus<{Board}Controllable>`) and `guard target === source` instead.
- ❌ Calling `attachedObject(_:)` to fabricate a "source" for Board-originated transport → that's a retrieved controller reference (forbidden). Use plain `Bus<Void>` and rely on `bus.connect(target:)`'s weak binding.
- ❌ `completion(.success(...))` on a background thread → race with main-thread Motherboard updates.
- ❌ `BlockTaskBoard` with `.concurrent` listening via `.flow.addTarget` → results cannot be routed to the originating caller.
- ❌ Calling `complete()` twice → assertion.
- ❌ Wrapping a UI flow whose entry is already a VIP board → adds a useless coordinator layer.

## References

- `MICROBOARD_UI.md` (UI variant)
- `COMMUNICATION.md` (bus / flow / action semantics)
- `EXAMPLES_NONUI_BOARDS.md`, `EXAMPLES_VIEWLESS_BOARD.md` (worked examples)
- `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded)
- `PER_ACTIVATION_RESOURCES.md` (BlockTask concurrency guard)
- `ACTIVATION_BARRIER.md` (Barrier semantics)
- `QUICK_REF.md` §4 rules 7, 8, 12, 13, 14

## IO snippets

```swift
// IO/{Board}/{Board}IOInterface.swift
public extension BoardID {
    static let pub{Board}: BoardID = "pub.mod.{Module}.{Board}"
}

public typealias {Board}MainDestination = MainboardGenericDestination<
    {Board}Input, {Board}Output, {Board}Command, {Board}Action // BlockTask uses {Board}Parameter first
>

public extension MotherboardType where Self: FlowManageable {
    func io{Board}(_ identifier: BoardID = .pub{Board}) -> {Board}MainDestination {
        {Board}MainDestination(destinationID: identifier, mainboard: self)
    }
}

// Sources/Microboards/{Board}/{Board}BoardIOInterface.swift
extension BoardID { static let mod{Board}Board: BoardID = .pub{Board} }

// Sources/Microboards/{Board}/{Board}BoardInOut.swift
typealias {Board}Input = {PublicBoard}Input
typealias {Board}Parameter = BlockTaskParameter<{Board}Input, {Board}Output>
typealias {Board}Output = {PublicBoard}Output
typealias {Board}Command = {PublicBoard}Command
typealias {Board}Action = {PublicBoard}Action
```
