<!-- Created by claude-opus-4-7 on 2026-05-09 -->
# EXAMPLES: Viewless Board

All 4 files for a non-UI board that has stateful business logic (UseCase calls).
Pattern: like Full VIP Board but without Presenter and ViewController.
Placeholders: `{Name}` = board name, `{Module}` = module name, `{PubName}` = public board name in IO.
Files live in `Sources/Microboards/{Name}/`.

---

```swift
// {Name}Protocols.swift
import UIKit

// Inward: Board pushes lifecycle events into Controller
protocol {Name}Controllable: AnyObject {
    func start()
    func didReceiveChildOutput()   // called by Board from registerFlows
}

// Outward: Controller requests Board actions
// Each callback passes `self` so the Board can route via bus with an identity filter
protocol {Name}ControlDelegate: AnyObject {
    func activateChild(from controller: {Name}Controllable, context: UIViewController?)
    func finishFlow(from controller: {Name}Controllable, output: {PubName}Output)
}

// Board conforms to this
protocol {Name}Delegate: {Name}ControlDelegate {}

struct {Name}Interface {
    let controller: {Name}Controllable
}

protocol {Name}Buildable {
    func build(withDelegate delegate: {Name}Delegate?,
               input: {Name}Input) -> {Name}Interface
}
```

```swift
// {Name}Controller.swift
import Foundation

// NSObject required for Boardy Attachable conformance
final class {Name}Controller: NSObject {
    weak var delegate: {Name}ControlDelegate?

    private let input: {Name}Input
    private let useCase: {Action}UseCase
    private var hasCompleted = false   // state lives here, NOT in Board

    init(input: {Name}Input, useCase: {Action}UseCase) {
        self.input = input
        self.useCase = useCase
    }
}

extension {Name}Controller: {Name}Controllable {
    func start() {
        delegate?.activateChild(from: self, context: input.context)
    }

    func didReceiveChildOutput() {
        Task { [weak self] in
            guard let self else { return }
            let result = await useCase.execute()
            await MainActor.run { [weak self] in
                guard let self else { return }
                hasCompleted = true
                delegate?.finishFlow(from: self, output: .completed(result))
            }
        }
    }
}
```

```swift
// {Name}Builder.swift
import Foundation

struct {Name}Builder: {Name}Buildable {
    let useCase: {Action}UseCase

    func build(withDelegate delegate: {Name}Delegate?,
               input: {Name}Input) -> {Name}Interface {
        let controller = {Name}Controller(input: input, useCase: useCase)
        controller.delegate = delegate
        return {Name}Interface(controller: controller)
    }
}
```

```swift
// {Name}Board.swift
import Boardy
import Foundation
import UIKit

final class {Name}Board: ModernContinuableBoard, GuaranteedBoard,
    GuaranteedOutputSendingBoard, GuaranteedActionSendingBoard, GuaranteedCommandBoard {

    typealias InputType = {Name}Input
    typealias OutputType = {Name}Output
    typealias FlowActionType = {Name}Action
    typealias CommandType = {Name}Command

    private let builder: {Name}Buildable

    // Event buses for Board→Controller communication (one bus per action).
    // Bus payload carries the source controller for any round-trip path
    // (Controller → Board delegate → Bus → Controller) so subscriber can identity-filter.
    private let childOutputBus = Bus<{Name}Controllable>()
    // For Board-originated transport (e.g. child flow), bus.connect's weak target binding
    // is enough — payload need not carry identity.
    private let childFlowBus = Bus<Void>()

    init(identifier: BoardID, builder: {Name}Buildable, producer: ActivatableBoardProducer) {
        self.builder = builder
        super.init(identifier: identifier, boardProducer: producer)
        registerFlows()   // always in init
    }

    func activate(withGuaranteedInput input: {Name}Input) {
        let component = builder.build(withDelegate: self, input: input)

        // Identity-filtered bus (Controller → delegate → bus → Controller round-trip).
        // Source comes from the bus payload, not a captured local.
        childOutputBus.connect(target: component.controller) { target, source in
            guard target === source else { return }
            target.didReceiveChildOutput()
        }

        // Plain bus (Board-originated transport). bus.connect weak-binds target, so only
        // the live controller fires; no identity payload needed.
        childFlowBus.connect(target: component.controller) { target, _ in
            target.didReceiveChildOutput()
        }

        // Attach context priority: (1) explicit input.context → (2) rootViewController → (3) Board context (last resort)
        // Context type is AnyObject — typically a UIViewController, but any reference owner works.
        if let context = input.context {
            attachObject(component.controller, context: context)
        } else {
            attachObject(component.controller, context: rootViewController)
        }
        component.controller.start()
    }

    func activationBarrier(withGuaranteedInput input: InputType) -> ActivationBarrier? { nil }
    func interact(guaranteedCommand: CommandType) {}
}

extension {Name}Board: {Name}Delegate {
    // Controller passes `self` as the source — bus.transport then forwards it for identity-filter
    func activateChild(from controller: {Name}Controllable, context: UIViewController?) {
        motherboard.serviceMap.mod{Module}Plugins
            .io{Child}.activation.activate(with: ChildInput(context: context))
    }
    func finishFlow(from controller: {Name}Controllable, output: {PubName}Output) {
        sendOutput(output)
        complete()
    }
}

private extension {Name}Board {
    func registerFlows() {
        // Board-originated transport — childFlowBus is plain Bus<Void>; bus.connect's weak
        // target binding ensures only the live controller fires.
        motherboard.serviceMap.mod{Module}Plugins
            .io{Child}.flow.addTarget(self) { target, _ in
                target.childFlowBus.transport(input: ())
            }
    }
}
```
