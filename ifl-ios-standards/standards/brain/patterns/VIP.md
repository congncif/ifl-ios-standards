<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->
<!-- brain-version: 1.0.0 · last-updated: 2026-05-18 -->

# VIP — View / Interactor / Presenter (Recommended Presentation Pattern)

> **Status**: Optional pattern guide. The brain rulebook is pattern-neutral; this file is loaded only by projects that adopt VIP as their presentation pattern.
> **Recommended**: VIP is the **default recommendation** for modular iOS systems — with or without Boardy. It enforces unidirectional flow, humble views, and single-source ViewModel mapping that align with the rulebook's hard rules (`rulebook/09-ui-layer-rules.md`, `rulebook/11-state-management-rules.md`).
> **Boardy is optional**. Pure VIP works standalone with any router/coordinator. Boardy adds lifecycle + composition primitives on top; see §9 for the optional Boardy integration notes.

---

## 1. Why VIP

| Goal | How VIP enforces it |
|------|---------------------|
| Humble view | View renders ViewModels and forwards user intent only. No business logic, no domain types, no formatting decisions. |
| Unidirectional flow | Strict pipeline: `View → Interactor → UseCase → Presenter → View`. No back-channels. |
| Single ViewModel mapper | Presenter is the **only** owner of domain → ViewModel translation. Interactor never builds ViewModels; View never reads domain types. |
| Testable presentation | Each role has one input protocol and one output protocol. Mock one boundary at a time. |
| Replaceable view tech | Swapping UIKit ↔ SwiftUI changes only the View; Interactor/Presenter/UseCase stay intact. |

VIP is preferred over MVVM/MVC when the view layer must stay strictly humble across many screens, and over TCA when the team wants protocol-based seams instead of a single store + reducer system.

---

## 2. Component Roles

| Component | Owns | Knows about | Must not |
|-----------|------|-------------|----------|
| **View** (`ViewController` or SwiftUI view) | Rendering, user input forwarding | `ViewModel` types, `ActionDelegate` protocol | Hold domain types, format data, call UseCases, decide navigation policy |
| **Interactor** | Business orchestration for the screen | UseCase protocols, domain models, Presenter input protocol | Build ViewModels, hold view references, touch UIKit |
| **Presenter** | Domain → ViewModel mapping (single source) | Domain models (read-only), View output protocol | Run business logic, call UseCases, store state |
| **UseCase** | One business capability (pure orchestration of domain + repository) | Domain models, Repository protocols | Know about View, Presenter, UI types |
| **Router / Coordinator** (optional) | Navigation policy, screen-to-screen wiring | Builder factories, navigation context | Run business logic |
| **Builder** | Compose the screen (instantiate concrete types at the composition root) | All concrete classes for this screen | Be reused by other screens (one Builder per screen) |

---

## 3. Unidirectional Flow

```
User taps   →  View                      (forwards intent)
                ↓ Interactable
            Interactor                    (orchestrates use cases)
                ↓ calls UseCase
            UseCase                       (business logic, returns domain result)
                ↑ returns domain result
            Interactor                    (passes domain result inward)
                ↓ Presentable
            Presenter                     (maps domain → ViewModel)
                ↓ Viewable
            View                          (renders ViewModel)
```

The arrows are protocol calls. Each step is a one-way handoff. **No skipping** (View ⇄ Presenter direct is forbidden). **No reversing** (Presenter calling Interactor is forbidden).

---

## 4. Protocol Contracts

Each direction has one protocol. Name them after the role of the **receiver**.

| Direction | Protocol | Owner file (declares) | Conformer (implements) |
|-----------|----------|------------------------|------------------------|
| View → Interactor | `{Name}Interactable` | `{Name}ViewController.swift` | Interactor |
| Interactor → Presenter | `{Name}Presentable` | `{Name}Interactor.swift` | Presenter |
| Presenter → View | `{Name}Viewable` | `{Name}Presenter.swift` | ViewController |
| View → Router/Coordinator (navigation intent) | `{Name}ActionDelegate` | `{Name}Protocols.swift` | Router/Coordinator/Board |
| Interactor → Router/Coordinator (control / completion) | `{Name}ControlDelegate` | `{Name}Protocols.swift` | Router/Coordinator/Board |
| Builder contract | `{Name}Buildable` | `{Name}Protocols.swift` | Builder struct |

**Weak references** at every back-edge:

```swift
final class Presenter: Presentable {
    weak var view: Viewable!         // Presenter → View (back-edge)
}

final class Interactor: Interactable {
    weak var delegate: ControlDelegate!  // Interactor → Router (back-edge)
    // NEVER declare a view or ActionDelegate here
}

final class ViewController: Viewable {
    weak var interactor: Interactable!         // View → Interactor (forward — but still weak: VC owned by container)
    weak var actionDelegate: ActionDelegate!   // View → Router (back-edge for direct nav intent)
}
```

---

## 5. Skeleton — Per Screen

Recommended folder layout for one VIP screen (`{Name}` = screen name, e.g. `SignIn`, `ProfileDetail`):

```
{ModuleRoot}/{ModuleName}/Sources/Screens/{Name}/
├── {Name}Protocols.swift       ← {Name}Buildable, {Name}ActionDelegate, {Name}ControlDelegate
├── {Name}Builder.swift          ← assembles VC + Interactor + Presenter; wires protocols
├── {Name}ViewController.swift  ← declares {Name}Interactable; conforms to {Name}Viewable
├── {Name}Interactor.swift      ← declares {Name}Presentable; conforms to {Name}Interactable
├── {Name}Presenter.swift       ← declares {Name}Viewable + ViewModel types; conforms to {Name}Presentable
└── {Name}Router.swift           ← (optional) navigation, conforms to {Name}ActionDelegate
```

Minimal skeleton (no Boardy, plain VIP + manual router):

```swift
// {Name}Protocols.swift
protocol {Name}Buildable {
    func build(input: {Name}Input, actionDelegate: {Name}ActionDelegate) -> UIViewController
}
protocol {Name}ActionDelegate: AnyObject {
    func {name}DidRequestClose()
    // navigation intents only
}
protocol {Name}ControlDelegate: AnyObject {
    func {name}DidFinish(result: {Name}Result)
}

// {Name}ViewController.swift
protocol {Name}Interactable: AnyObject {
    func viewDidLoad()
    func didTapPrimaryAction()
}
final class {Name}ViewController: UIViewController, {Name}Viewable {
    var interactor: {Name}Interactable!
    weak var actionDelegate: {Name}ActionDelegate!
    func render(_ viewModel: {Name}ViewModel) { /* update UI */ }
    func showError(_ message: String) { /* show alert */ }
}

// {Name}Interactor.swift
protocol {Name}Presentable: AnyObject {
    func presentResult(_ result: {Name}DomainResult)
    func presentError(_ error: Error)
}
final class {Name}Interactor: {Name}Interactable {
    private let useCase: {Action}UseCase
    private let presenter: {Name}Presentable
    weak var delegate: {Name}ControlDelegate!
    init(useCase: {Action}UseCase, presenter: {Name}Presentable) {
        self.useCase = useCase; self.presenter = presenter
    }
    func viewDidLoad() { /* trigger initial load */ }
    func didTapPrimaryAction() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await useCase.execute()
                await MainActor.run { [weak self] in
                    self?.presenter.presentResult(result)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.presenter.presentError(error)
                }
            }
        }
    }
}

// {Name}Presenter.swift
protocol {Name}Viewable: AnyObject {
    func render(_ viewModel: {Name}ViewModel)
    func showError(_ message: String)
}
struct {Name}ViewModel { /* display-ready fields */ }
final class {Name}Presenter: {Name}Presentable {
    weak var view: {Name}Viewable!
    func presentResult(_ result: {Name}DomainResult) {
        let vm = {Name}ViewModel(/* map domain → display */)
        view.render(vm)
    }
    func presentError(_ error: Error) {
        view.showError(error.localizedDescription)
    }
}

// {Name}Builder.swift
struct {Name}Builder: {Name}Buildable {
    func build(input: {Name}Input, actionDelegate: {Name}ActionDelegate) -> UIViewController {
        let presenter = {Name}Presenter()
        let interactor = {Name}Interactor(
            useCase: {Action}UseCaseFactory.make(),
            presenter: presenter
        )
        let vc = {Name}ViewController()
        vc.interactor = interactor
        vc.actionDelegate = actionDelegate
        presenter.view = vc
        interactor.delegate = /* router */
        return vc
    }
}
```

---

## 6. Naming Conventions

| Concept | Pattern | Example |
|---------|---------|---------|
| Screen | `{Name}` | `SignIn`, `ProfileDetail`, `CartCheckout` |
| ViewController class | `{Name}ViewController` | `SignInViewController` |
| Interactor class | `{Name}Interactor` | `SignInInteractor` |
| Presenter class | `{Name}Presenter` | `SignInPresenter` |
| Builder struct | `{Name}Builder` | `SignInBuilder` |
| Router class (optional) | `{Name}Router` | `SignInRouter` |
| ViewModel type | `{Name}ViewModel` (or `{Name}.ViewModel` namespaced) | `SignInViewModel` |
| UseCase protocol | `{Action}UseCase` | `AuthenticateUseCase` |
| UseCase impl | `{Action}UseCaseInteractor` (or `Default{Action}UseCase`) | `AuthenticateUseCaseInteractor` |

---

## 7. Non-Negotiable Rules (VIP-specific)

These extend the brain rulebook's hard rules. A project adopting VIP must enforce all of them:

1. **View has ZERO logic.** Renders ViewModels, forwards events. No `if/else` on domain data, no formatting, no navigation decisions beyond forwarding intent.
2. **Unidirectional pipeline.** `View → Interactor → UseCase → Presenter → View`. Skipping or reversing is a quick-fail.
3. **Presenter is the single ViewModel mapper.** Interactor passes domain models to Presenter; Presenter builds ViewModels. Building a ViewModel anywhere else is forbidden.
4. **No domain types in View.** Views import only ViewModel structs and protocol types. Domain models stay below the Interactor boundary.
5. **No UIKit / SwiftUI in Interactor or Presenter.** Presenter may import `Foundation` only (for `String`, `Date`, etc.). Interactor imports domain + UseCase contracts only.
6. **Weak back-edges.** `Presenter.view`, `Interactor.delegate`, `ViewController.actionDelegate` are always `weak`. Forward edges (View → Interactor, Interactor → Presenter) are owned-and-strong from the Builder.
7. **Async UI updates run on the main actor.** Wrap Presenter calls from Interactor's async work in `await MainActor.run { [weak self] in … }`.
8. **Builder is the only composition root for the screen.** Concrete `Interactor`/`Presenter`/`ViewController` types are instantiated only in the Builder.
9. **One Builder per screen.** Don't reuse a Builder across screens; copy the structure instead. Builders are composition, not abstraction.
10. **Navigation intent is explicit.** Direct navigation requests from View use `ActionDelegate` (forwarded to Router/Coordinator). Business completion uses `ControlDelegate` from Interactor. Never reach into a parent controller.

---

## 8. When VIP Fits — and When It Doesn't

**Fits well**:
- Modular apps where each screen is owned by a feature module.
- Teams that want strict protocol-based seams for testing.
- Projects with mixed UIKit/SwiftUI views — VIP keeps the seam stable across both.
- Apps with non-trivial domain → display mapping (formatting, locale, derived fields).

**Doesn't fit**:
- Trivial screens with no logic (a single static label) — VIP overhead is wasted.
- Pure SwiftUI screens with simple state — `@Observable` view models may be enough.
- Tightly-coupled real-time UIs (game loops, drawing surfaces) where the indirection cost dominates.

For prototypes or one-off screens, allow MVVM/MVC. Promote to VIP when the screen survives past the prototype phase.

---

## 9. Optional: Boardy Integration

[Boardy](https://github.com/dovecorp/Boardy) is an optional framework that adds **board lifecycle + composition primitives** on top of VIP. It contributes:

- `Board` — a lifecycle-aware container that activates a VIP screen, owns its `Interactor`/`Presenter`/`ViewController`, and wires `registerFlows()` for parent-child events.
- `BoardID` — stable string IDs for cross-module screen references.
- `ServiceMap` — DI registry that exposes a module's boards by ID.
- `Motherboard` / `ComposableBoard` — parent boards that activate child boards.
- `BlockTaskBoard` / `FlowBoard` / `Viewless board` — non-UI lifecycle wrappers for async tasks and routing logic.

**When to add Boardy**:
- Cross-module navigation that benefits from string IDs over typed factories.
- Need for non-UI board types (async tasks, routing gates, activation barriers).
- Many features composed dynamically at runtime (tab bar with pluggable tabs, gated flows).

**Skip Boardy when**:
- Single-target app with all-internal navigation.
- Team prefers typed factories + Coordinator pattern over string IDs.
- No need for non-UI board lifecycle primitives.

Pure VIP without Boardy is fully supported. Add a small `Router` or `Coordinator` per feature and wire screens manually. The protocols, skeleton, and 10 rules above all stay the same — Boardy just replaces "Router + manual Builder wiring" with `Board + registerFlows + Motherboard`.

---

## 10. Verification Checklist (pre-merge)

For every VIP screen added or modified:

- [ ] View imports only `UIKit`/`SwiftUI` + ViewModel types + protocol types
- [ ] No `import` of a use case or domain repository from the View file
- [ ] Presenter is the only file that constructs a `ViewModel`
- [ ] Interactor calls UseCase via protocol, never a concrete class
- [ ] `weak` keyword present on every back-edge reference
- [ ] Async path wraps Presenter calls in `await MainActor.run { [weak self] in … }`
- [ ] Builder is the only place that instantiates the Interactor / Presenter / View
- [ ] Tests cover: Interactor (with mock UseCase + mock Presenter), Presenter (with mock View + sample domain input), UseCase (pure)
