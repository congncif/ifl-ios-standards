<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->
<!-- brain-version: 1.0.0 · last-updated: 2026-05-18 -->

# VIP — View / Interactor / Presenter (Recommended Presentation Pattern)

> **Status**: Optional pattern guide. The brain rulebook is pattern-neutral; this file is loaded only by projects that adopt VIP as their presentation pattern.
> **Recommended**: VIP is the **default recommendation** for modular iOS systems — with or without Boardy. It supports unidirectional flow, humble Views, and single-source ViewModel mapping. Canon Rules selected by the project's active Profiles remain authoritative.
> **Boardy is optional**. Pure VIP works standalone with any router/coordinator. Boardy adds lifecycle + composition primitives on top; see §10 for the optional Boardy integration notes.

---

## 1. Why VIP

| Goal | How VIP enforces it |
|------|---------------------|
| Humble view | View renders display-ready state, may branch on presenter-encoded presentation state, owns UX-local interaction state, and forwards typed intent. It never derives product meaning or formats raw/domain values. |
| Unidirectional flow | Strict pipeline: `View → Interactor → UseCase → Presenter → View`. No back-channels. |
| Single ViewModel mapper | Presenter is the **only** owner of domain → ViewModel translation. Interactor never builds ViewModels; View never reads domain types. |
| Testable presentation | Each role has one input protocol and one output protocol. Mock one boundary at a time. |
| Replaceable view tech | Swapping UIKit ↔ SwiftUI changes only the View; Interactor/Presenter/UseCase stay intact. |

VIP is preferred over MVVM/MVC when the view layer must stay strictly humble across many screens, and over TCA when the team wants protocol-based seams instead of a single store + reducer system.

---

## 2. Component Roles

| Component | Owns | Knows about | Must not |
|-----------|------|-------------|----------|
| **View** (`ViewController` or SwiftUI view) | Rendering, presentation-state branching, UX-local interaction state, user input forwarding | Display-ready `ViewModel` types, `ActionDelegate` protocol | Hold domain types, format raw values, derive product meaning, call UseCases, decide business/navigation policy |
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

**Weak references** at every back-edge; forward edges remain strong:

```swift
final class Presenter: Presentable {
    weak var view: Viewable!         // Presenter → View (back-edge)
}

final class Interactor: Interactable {
    weak var delegate: ControlDelegate!  // Interactor → Router (back-edge)
    // NEVER declare a view or ActionDelegate here
}

final class ViewController: Viewable {
    var interactor: Interactable!              // View → Interactor (strong forward edge)
    weak var actionDelegate: ActionDelegate!   // View → Router (back-edge for direct nav intent)
}
```

The Builder establishes the strong `View → Interactor → Presenter` ownership chain. Container or Board
ownership is not a reason to weaken a forward edge: doing so can release the Interactor before the View
forwards its next intent. Only the return edges to View, Router, Coordinator, or Board are weak.

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

## 7. Canon-Linked VIP Checklist

This is derived guidance for a project that selects the relevant UI and, when applicable, `boardy-vip`
Profiles. The cited Canon Rule supplies the actual scope, level, and exception policy.

1. **View is humble (`UI-HUMBLE-001`…`004`).** It renders display-ready state, branches on presentation decisions already encoded as loading/content/empty/error, owns transient UX-local state, calculates only geometry/visual interpolation, and forwards typed intent. It does not format dates/currency/quantities/errors, derive user-visible or analytics meaning, decide eligibility/pricing/retry/navigation policy, fetch or persist business data, or construct dependencies.
2. **Unidirectional pipeline (`BRD-VIP-001`).** `View → Interactor → UseCase → Presenter → View`. Skipping or reversing is a quick-fail.
3. **Presenter is the single ViewModel mapper (`UI-HUMBLE-001`).** Interactor passes domain models to Presenter; Presenter builds display-ready ViewModels. The View does not derive product-facing presentation values.
4. **View consumes display-ready state (`UI-HUMBLE-001`, `UI-HUMBLE-003`, `UI-HUMBLE-004`).** Raw or domain values are mapped before rendering; the View does not format them or derive product or analytics meaning from them.
5. **Framework boundary (`CORE-DEP-001`…`003`, `UIKIT-RENDER-001` when UIKit applies).** Keep Domain and Application dependencies inward, and give the rendering adapter immutable display-ready state rather than domain responsibilities.
6. **Weak back-edges (`BRD-REF-001`).** `Presenter.view`, `Interactor.delegate`, `ViewController.actionDelegate` are always `weak`. Forward edges (View → Interactor, Interactor → Presenter) are owned-and-strong from the Builder.
7. **UI isolation (`UI-ISOLATION-001`).** UIKit rendering and SwiftUI presentation-store mutation run on the declared MainActor boundary. Wrap Presenter calls from asynchronous Interactor work in `await MainActor.run { [weak self] in … }`.
8. **Composition stays at a declared root (`CORE-COMP-001`).** In the conventional VIP shape, the Builder is that screen-level root; an equivalent declared composition root remains conforming.
9. **Navigation intent is explicit (`BRD-NAV-001` when Boardy applies).** The View forwards typed intent, the Board or coordinator owns navigation policy, and business completion uses the Interactor control boundary.

---

## 8. UIKit and SwiftUI Rendering Adapters

UIKit and SwiftUI share the same Interactor, UseCase, Presenter, and display-ready state contract. A
framework choice changes only the rendering adapter (`UIKIT-RENDER-001`). Given the same domain input,
both adapters must receive the same semantic state; layout and interaction mechanics may differ.

The Presenter owns product presentation decisions:

```swift
struct {Name}ViewModel: Equatable {
    enum Phase: Equatable {
        case loading
        case content(Content)
        case empty(Empty)
        case error(ErrorContent)
    }

    let phase: Phase
}
```

A UIKit adapter receives immutable display-ready state through its display port. Its `switch` renders
the encoded phase; it does not reinterpret domain input:

```swift
protocol {Name}Viewable: AnyObject {
    @MainActor func render(_ viewModel: {Name}ViewModel)
}

@MainActor
final class {Name}ViewController: UIViewController, {Name}Viewable {
    func render(_ viewModel: {Name}ViewModel) {
        switch viewModel.phase {
        case .loading: renderLoading()
        case .content(let content): renderContent(content)
        case .empty(let empty): renderEmpty(empty)
        case .error(let error): renderError(error)
        }
    }
}
```

A SwiftUI adapter receives the same state through a MainActor presentation store. `@State` remains
limited to UX-local mechanics such as focus, disclosure, animation, gesture, and scroll position;
the store owns presentation state, while Interactor/UseCase own product behavior:

```swift
@MainActor
final class {Name}PresentationStore: ObservableObject, {Name}Viewable {
    @Published private(set) var viewModel: {Name}ViewModel

    func render(_ viewModel: {Name}ViewModel) {
        self.viewModel = viewModel
    }
}

struct {Name}View: View {
    @ObservedObject var store: {Name}PresentationStore
    @State private var isDisclosureExpanded = false // UX-only

    var body: some View {
        switch store.viewModel.phase {
        case .loading: ProgressView()
        case .content(let content): {Name}ContentView(content: content)
        case .empty(let empty): {Name}EmptyStateView(content: empty)
        case .error(let error): {Name}ErrorStateView(content: error)
        }
    }
}
```

Both examples permit conditionals that select an already-prepared presentation state. Formatting raw
dates, currency, quantities, labels, or errors in either View remains a boundary violation.

---

## 9. When VIP Fits — and When It Doesn't

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

## 10. Optional: Boardy Integration

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

## 11. Review Checklist

For every VIP screen added or modified:

- [ ] View imports only `UIKit`/`SwiftUI` + ViewModel types + protocol types
- [ ] No `import` of a use case or domain repository from the View file
- [ ] View conditionals inspect display-ready presentation state only; no raw/domain formatting or business decisions
- [ ] View-owned state is UX-local only; product/business state remains outside UIKit/SwiftUI state containers
- [ ] Presenter is the only file that constructs a `ViewModel`
- [ ] UIKit display port and SwiftUI presentation store consume equivalent semantic state for the same domain input
- [ ] Interactor calls UseCase via protocol, never a concrete class
- [ ] `weak` keyword present on every back-edge reference
- [ ] Async path wraps Presenter calls in `await MainActor.run { [weak self] in … }`
- [ ] Builder is the only place that instantiates the Interactor / Presenter / View
- [ ] Tests cover: Interactor (with mock UseCase + mock Presenter), Presenter (with mock View + sample domain input), UseCase (pure)
