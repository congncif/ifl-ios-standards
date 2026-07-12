<!-- Retrofitted to SPEC_CONTRACT 12 sections on 2026-05-23 -->

# SPEC: VIP Components

> Reference: *Modern large-scale iOS app development* — Business Application layer inside Domain-driven Layered pillar.
> Companion specs: `ARCHITECTURE.md` (overall picture), `MICROBOARD_UI.md` (Board shell), `EXAMPLES_VIP_BOARD.md` (concrete skeleton), `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded).

## When to use

When implementing the Interactor / Presenter / ViewController / Builder / Protocols set for a Microboard with UI. Load alongside `MICROBOARD_UI.md` when authoring a new UI board.

## When NOT to use

- A board without a UIViewController — use `MICROBOARD_NONUI.md` decision tree (BlockTask / Viewless / Flow).
- A board that is purely a parent/container hosting other boards — `COMPOSABLE_BOARD.md`.
- A standalone view component used by multiple features — that's a shared View library, not VIP.

## Forces

- VIP keeps the View dumb so UseCase + Presenter are unit-testable. The cost is five files per board; the payoff is replaceability of any single component.
- The Board-as-delegate split (ActionDelegate for nav intents vs ControlDelegate for domain events) prevents the Interactor from becoming a router. Collapsing them saves a protocol but creates a god-Interactor.
- `Controllable` exists primarily as a watch handle for `watch(content:)`; collapsing it into the Interactor's main protocol breaks Boardy's lifecycle assumptions.

## Files

```
Sources/Microboards/{FeatureName}/
├── {FeatureName}IOInterface.swift    ← BoardID, MainDestination typealias
├── {FeatureName}InOut.swift          ← Input, Output, Command, Action
├── {FeatureName}Protocols.swift      ← Controllable / ActionDelegate / ControlDelegate / Delegate / UserInterface / Interface / Buildable
├── {FeatureName}Board.swift          ← Board: lifecycle + delegate impl (see MICROBOARD_UI.md)
├── {FeatureName}Builder.swift        ← DI wiring, returns Interface struct
├── {FeatureName}Interactor.swift     ← Business logic + Presentable protocol
├── {FeatureName}Presenter.swift      ← ViewModel mapping + ViewModels + Viewable protocol
├── {FeatureName}ViewController.swift ← Humble VC + Interactable protocol
├── ServiceMap+{FeatureName}.swift    ← Extension on module Plugins ServiceMap
└── Views/                            ← Sub-views, cells (optional)
```

## Naming

See `QUICK_REF.md` §3 (Protocol location) and `BOARDY_CHEATSHEET.compact.md` Naming. Quick reference:

| Type | Naming |
|------|--------|
| Class | `{FeatureName}{Role}` — `Interactor`, `Presenter`, `ViewController`, `Builder`, `Board` |
| ViewModel struct | `{FeatureName}ViewModel` (inside Presenter file) |
| State enum | `{FeatureName}State` (inside Presenter file) |
| Combined delegate | `{FeatureName}Delegate` (in Protocols file; Board conforms) |
| Build output | `{FeatureName}Interface` (struct with `userInterface` + `controller`) |

VIP class names are **never** prefixed even when the module is prefixed.

## Communication

Direction matrix:

| From | To | Channel |
|------|----|---------|
| User | ViewController | UIKit actions |
| ViewController | Interactor | `Interactable` (defined in VC file) |
| ViewController | Board | `ActionDelegate` (defined in Protocols.swift) — pure-navigation intents only |
| Interactor | UseCase | direct call |
| Interactor | Presenter | `Presentable` (defined in Interactor file) |
| Interactor | Board | `ControlDelegate` (defined in Protocols.swift) |
| Presenter | ViewController | `Viewable` (defined in Presenter file) |
| Board | Interactor | `Controllable` (defined in Protocols.swift) — usually empty marker |

Unidirectional flow: `VC → Interactor → UseCase → Presenter → VC`. The only allowed sidestep is `VC → ActionDelegate(Board)` for navigation intents the Interactor would only forward.

```swift
// Protocols.swift
protocol {FeatureName}Controllable: AnyObject {}
protocol {FeatureName}ActionDelegate: AnyObject {
    func close(_ isDone: Bool)
    func exitFlow()
}
protocol {FeatureName}ControlDelegate: AnyObject {
    func loadData()
    func performCompletion(_ isDone: Bool)
}
protocol {FeatureName}Delegate: {FeatureName}ActionDelegate, {FeatureName}ControlDelegate {}
protocol {FeatureName}UserInterface: UIViewController {}
struct {FeatureName}Interface {
    let userInterface: {FeatureName}UserInterface
    let controller: {FeatureName}Controllable
}
protocol {FeatureName}Buildable {
    func build(withDelegate delegate: {FeatureName}Delegate?, input: {FeatureName}Input) -> {FeatureName}Interface
}

// Interactor.swift
protocol {FeatureName}Presentable: AnyObject {
    func present{State}(_ model: {DomainModel})
    func presentOverlayLoading()
    func dismissOverlayLoading()
    func presentError(_ error: any Error)
}

final class {FeatureName}Interactor {
    weak var delegate: {FeatureName}ControlDelegate!
    private let presenter: {FeatureName}Presentable
    private let input: {FeatureName}Input
    private let someUseCase: SomeUseCase

    init(presenter: {FeatureName}Presentable, input: {FeatureName}Input, someUseCase: SomeUseCase) {
        self.presenter = presenter; self.input = input; self.someUseCase = someUseCase
    }
}

extension {FeatureName}Interactor: {FeatureName}Interactable {
    func didBecomeActive() {
        delegate?.loadData()
        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await someUseCase.execute()
                await MainActor.run { [weak self] in
                    self?.presenter.present{State}(result)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.presenter.presentError(error)
                }
            }
        }
    }
}

extension {FeatureName}Interactor: {FeatureName}Controllable {}

// Presenter.swift
protocol {FeatureName}Viewable: AnyObject {
    func setState(_ state: {FeatureName}State)
    func showHUDLoading()
    func hideHUDLoading()
    func showErrorSnackMessage(_ message: String)
}

final class {FeatureName}Presenter {
    weak var view: {FeatureName}Viewable!
}

extension {FeatureName}Presenter: {FeatureName}Presentable { /* present* maps to view.setState */ }

enum {FeatureName}State { case loading; case loaded({FeatureName}ViewModel); case error(String) }
struct {FeatureName}ViewModel { let title: String; let subtitle: String? }

// ViewController.swift
protocol {FeatureName}Interactable {
    func didBecomeActive()
    func userDidTapSubmit(with data: SomeData)
}

final class {FeatureName}ViewController: UIViewController, {FeatureName}UserInterface {
    weak var actionDelegate: {FeatureName}ActionDelegate!
    var interactor: {FeatureName}Interactable!

    override func viewDidLoad() {
        super.viewDidLoad()
        interactor.didBecomeActive()
    }

    func setState(_ state: {FeatureName}State) { /* render */ }
    @IBAction func didTapSubmit(_ s: UIButton) { interactor.userDidTapSubmit(with: getData()) }
    @IBAction func didTapClose(_ s: UIButton) { actionDelegate.close(false) }
}

extension {FeatureName}ViewController: {FeatureName}Viewable {}

// Builder.swift
struct {FeatureName}Builder: {FeatureName}Buildable {
    let someRepository: SomeRepository
    func build(withDelegate delegate: {FeatureName}Delegate?, input: {FeatureName}Input) -> {FeatureName}Interface {
        let vc = {FeatureName}ViewController()
        vc.actionDelegate = delegate

        let useCase = SomeUseCaseInteractor(repository: someRepository)
        let presenter = {FeatureName}Presenter()
        presenter.view = vc

        let interactor = {FeatureName}Interactor(presenter: presenter, input: input, someUseCase: useCase)
        interactor.delegate = delegate
        vc.interactor = interactor

        return {FeatureName}Interface(userInterface: vc, controller: interactor)
    }
}
```

## Concurrency

- Every async branch starts with `Task { [weak self] in ... }`.
- Every UI mutation hops to MainActor: `await MainActor.run { [weak self] in ... }`.
- `weak var view`, `weak var delegate`, `weak var actionDelegate` — three required weak captures.
- ViewController's `interactor` is non-weak (Board holds it indirectly via `watch(content:)`).

## Composition

- Builder is the DI seam. It receives `Delegate?` (the Board) and `Input`, returns `{FeatureName}Interface { userInterface, controller }`.
- The `controller` field MUST be the Interactor (because Interactor conforms to `Controllable`); the Board uses this for `watch(content:)`.
- The Builder owns construction of UseCase / Repository / Service for this board only; shared repositories come from the parent ModulePlugin.

## Lifecycle

- `viewDidLoad` is the only entry point that triggers `interactor.didBecomeActive()` — never call it from the Board.
- Interactor is retained by the Board indirectly (through `controller` in the Interface). When the Board completes, the interactor releases.
- Presenter is retained by the Interactor; the View is weak from the Presenter side and strong from the Board's watched controller side.
- Do not invoke `complete()` from within the Interactor — go through `delegate.performCompletion(_:)` so the Board owns lifecycle.

## Testing

- Interactor tests (priority 1): `didBecomeActive` → UseCase + delegate.loadData; user actions → correct UseCase + presenter calls; error paths.
- Presenter tests (priority 2): every `present*` maps to a `setState` / overlay / error call with the right ViewModel.
- UseCase tests (priority 3): happy / error / edge values.
- See `compact/TESTING.compact.md` for mock + stub skeletons.

## Pitfalls

- ❌ Interactor referencing `ActionDelegate` — Interactor only emits domain events via `ControlDelegate`.
- ❌ Pure-navigation intents routed through the Interactor — go `VC → ActionDelegate` directly.
- ❌ ViewModels declared in their own file — they live inside the Presenter file (private to the board).
- ❌ Storyboard-only VCs without a programmatic init — every VC must support `init()` for tests and the `ifl-new-board` template.
- ❌ Strong `delegate` / `view` / `actionDelegate` — retain cycles, leaked boards.
- ❌ Business logic in `setState` — that's Presenter's job.

## References

- `MICROBOARD_UI.md` (the Board class that owns this VIP)
- `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded, naming + skeletons)
- `compact/TESTING.compact.md` (default-loaded by ios-tester)
- `EXAMPLES_VIP_BOARD.md` (worked example)
- `COMMUNICATION.md` (bus / flow / delegate semantics)
- `QUICK_REF.md` §3 (Protocol location), §4 rules 1, 2, 5, 6

## Protocol location summary

| Protocol | Defined in | Conformed by |
|----------|-----------|--------------|
| `{Name}Interactable` | ViewController file | Interactor |
| `{Name}Presentable` | Interactor file | Presenter |
| `{Name}Viewable` | Presenter file | ViewController |
| `{Name}Controllable` | Protocols.swift | Interactor |
| `{Name}ActionDelegate` | Protocols.swift | Board |
| `{Name}ControlDelegate` | Protocols.swift | Board |
| `{Name}Delegate` | Protocols.swift | Board |
| `{Name}UserInterface` | Protocols.swift | ViewController |
| `{Name}Buildable` | Protocols.swift | Builder struct |
