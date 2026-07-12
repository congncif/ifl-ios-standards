<!-- Created by claude-opus-4-7 on 2026-05-09 -->
# EXAMPLES: Full VIP UI Board — UIKit adapter

All 6 files for one UIKit UI microboard (Protocols + Board + Interactor + Presenter + ViewController + Builder).
Placeholders: `{Name}` = board name, `{Module}` = module name.
All files live in `Sources/Microboards/{Name}/`.

For SwiftUI, keep the same Board, Interactor, Presenter, typed intents, and display-ready state; replace
the rendering adapter with the MainActor presentation-store + View + hosting shape in
`MICROBOARD_UI.md` or the `ifl-new-board ... swiftui` scaffold.

---

```swift
// {Name}Protocols.swift
import UIKit

// Inward: Board can push commands into Interactor
protocol {Name}Controllable: AnyObject {}

// Outward: ViewController sends UI events to Board
protocol {Name}ActionDelegate: AnyObject {
    func close(_ isDone: Bool)
}

// Outward: Interactor sends domain events to Board
protocol {Name}ControlDelegate: AnyObject {
    func performCompletion()
    func presentChildBoard(with data: SomeData)
}

// Board conforms to this combined delegate
protocol {Name}Delegate: {Name}ActionDelegate, {Name}ControlDelegate {}

struct {Name}Interface {
    let userInterface: UIViewController
    let controller: {Name}Controllable
}

protocol {Name}Buildable {
    func build(withDelegate delegate: {Name}Delegate?,
               input: {Name}Input) -> {Name}Interface
}
```

```swift
// {Name}Board.swift
import Boardy
import Foundation
import SiFUtilities
import UIKit

final class {Name}Board: ModernContinuableBoard, GuaranteedBoard,
    GuaranteedOutputSendingBoard, GuaranteedActionSendingBoard, GuaranteedCommandBoard {

    typealias InputType = {Name}Input
    typealias OutputType = {Name}Output
    typealias FlowActionType = {Name}Action
    typealias CommandType = {Name}Command

    private let builder: {Name}Buildable
    private let completeBus = Bus<Bool>()

    init(identifier: BoardID, builder: {Name}Buildable, producer: ActivatableBoardProducer) {
        self.builder = builder
        super.init(identifier: identifier, boardProducer: producer)
        registerFlows()
    }

    func activate(withGuaranteedInput input: InputType) {
        let component = builder.build(withDelegate: self, input: input)
        watch(content: component.controller)
        motherboard.putIntoContext(component.userInterface)
        rootViewController.show(component.userInterface)
        completeBus.connect(target: self) { target, isDone in
            target.rootViewController.returnHere { [weak target] in
                target?.complete(isDone)
            }
        }
    }

    func activationBarrier(withGuaranteedInput input: InputType) -> ActivationBarrier? { nil }
    func interact(guaranteedCommand: CommandType) {}
}

extension {Name}Board: {Name}Delegate {
    func close(_ isDone: Bool) { completeBus.transport(input: isDone) }
    func performCompletion() { completeBus.transport(input: true) }
    func presentChildBoard(with data: SomeData) {
        motherboard.serviceMap.mod{Module}
            .io{Child}.activation.activate(with: data)
    }
}

private extension {Name}Board {
    func registerFlows() {
        motherboard.serviceMap.mod{Module}
            .io{Child}.flow.addTarget(self) { target, output in
                switch output {
                case .done: target.completeBus.transport(input: true)
                }
            }
    }
    func complete(_ isDone: Bool) {
        sendOutput(isDone ? .completed : .cancelled)
    }
}
```

```swift
// {Name}Interactor.swift
import Foundation

// Interactor -> Presenter (defined here, in Interactor file)
@MainActor
protocol {Name}Presentable: AnyObject {
    func presentData(_ data: {DomainModel})
    func presentOverlayLoading()
    func dismissOverlayLoading()
    func presentError(_ error: any Error)
}

final class {Name}Interactor {
    weak var delegate: {Name}ControlDelegate!
    private let presenter: {Name}Presentable
    private let input: {Name}Input
    private let useCase: {Action}UseCase

    init(presenter: {Name}Presentable,
         input: {Name}Input,
         useCase: {Action}UseCase) {
        self.presenter = presenter
        self.input = input
        self.useCase = useCase
    }
}

extension {Name}Interactor: {Name}Interactable {
    func didBecomeActive() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let data = try await useCase.execute()
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    presenter.presentData(data)
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    presenter.presentError(error)
                }
            }
        }
    }

    func userDidConfirm() {
        Task { [weak self] in
            guard let self else { return }
            await MainActor.run { [weak self] in self?.presenter.presentOverlayLoading() }
            do {
                try await useCase.submit()
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    presenter.dismissOverlayLoading()
                    delegate.performCompletion()
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    presenter.dismissOverlayLoading()
                    presenter.presentError(error)
                }
            }
        }
    }
}

extension {Name}Interactor: {Name}Controllable {}
```

```swift
// {Name}Presenter.swift
import Foundation

// Presenter -> ViewController (defined here, in Presenter file)
@MainActor
protocol {Name}Viewable: AnyObject {
    func setState(_ state: {Name}State)
    func showHUDLoading()
    func hideHUDLoading()
    func showErrorMessage(_ message: String)
}

// ViewModels defined here
enum {Name}State {
    case loading
    case loaded({Name}ViewModel)
    case error(String)
}

struct {Name}ViewModel {
    let title: String
    let subtitle: String?
    // Add display-ready fields here
}

@MainActor
final class {Name}Presenter {
    weak var view: {Name}Viewable!
}

extension {Name}Presenter: {Name}Presentable {
    func presentData(_ data: {DomainModel}) {
        view?.setState(.loaded(map(data)))
    }
    func presentOverlayLoading() { view?.showHUDLoading() }
    func dismissOverlayLoading() { view?.hideHUDLoading() }
    func presentError(_ error: any Error) {
        view?.showErrorMessage(error.localizedDescription)
    }
}

private extension {Name}Presenter {
    func map(_ data: {DomainModel}) -> {Name}ViewModel {
        {Name}ViewModel(title: data.name, subtitle: nil)
    }
}
```

```swift
// {Name}ViewController.swift
import UIKit

// ViewController -> Interactor (defined here, in ViewController file)
protocol {Name}Interactable {
    func didBecomeActive()
    func userDidConfirm()
}

final class {Name}ViewController: UIViewController {

    weak var actionDelegate: {Name}ActionDelegate!
    var interactor: {Name}Interactable!

    override func viewDidLoad() {
        super.viewDidLoad()
        interactor.didBecomeActive()
    }

    // Actions forward to interactor or actionDelegate -- ZERO logic here
    @IBAction func didTapConfirm(_ sender: UIButton) {
        interactor.userDidConfirm()
    }

    @IBAction func didTapClose(_ sender: UIButton) {
        actionDelegate.close(false)
    }
}

extension {Name}ViewController: {Name}Viewable {
    func setState(_ state: {Name}State) {
        // Render only -- switch on state, update UI elements
    }
    func showHUDLoading() { /* show spinner */ }
    func hideHUDLoading() { /* hide spinner */ }
    func showErrorMessage(_ message: String) { /* show alert/snack */ }
}
```

```swift
// {Name}Builder.swift
import UIKit

struct {Name}Builder: {Name}Buildable {
    let repository: {Entity}Repository

    func build(withDelegate delegate: {Name}Delegate?,
               input: {Name}Input) -> {Name}Interface {
        let vc = {Name}ViewController()
        vc.actionDelegate = delegate

        let presenter = {Name}Presenter()
        presenter.view = vc

        let interactor = {Name}Interactor(
            presenter: presenter,
            input: input,
            useCase: {Action}UseCaseInteractor(repository: repository)
        )
        interactor.delegate = delegate
        vc.interactor = interactor

        return {Name}Interface(userInterface: vc, controller: interactor)
    }
}
```
