<!-- Created by claude-opus-4-7 on 2026-05-09 -->
<!-- Retrofitted to SPEC_CONTRACT 12 sections on 2026-05-23 -->

# SPEC: Composable Board

> Reference: *Modern large-scale iOS app development* — Micro-services Composable pillar.
> Companion specs: `MICROBOARD_UI.md` (single VIP board), `COMMUNICATION.md` (flow patterns), `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded).

## When to use

A screen hosts multiple boards simultaneously and long-lived:

- TabBar main navigation where every tab is alive at once.
- Section-based feeds where each section is an independent board.
- Any container where N boards activate concurrently and each manages its own UI region without independent dismissal.

## When NOT to use

- Regular pushed/presented screens, one at a time → `MICROBOARD_UI.md` with `rootViewController.show()`.
- Modal overlay → normal board with `show()`.
- Wizard / multi-step flow → Non-UI Flow board (`MICROBOARD_NONUI.md`).
- Container hosts only one board → no composition needed; let the board own the screen.

## Forces

- Composable trades simplicity for parallel liveness. Activating N boards at once means each must be designed for long-lived presence (no `dismiss`, no `complete()` on user nav).
- The parent must own a `FlowComposableMotherboard`; that's a second motherboard inside the first. Children must activate against `composableBoard.serviceMap`, not the parent's `motherboard.serviceMap` — easy to get wrong, hard to debug.
- `UIElement` identity is the child's BoardID — renaming the BoardID renames the element key.

## Files

### Parent (composable host)
```
Sources/Microboards/{Parent}/
├── {Parent}IOInterface.swift
├── {Parent}InOut.swift
├── {Parent}Protocols.swift     ← UserInterface = UIViewController + ComposableInterface
├── {Parent}Board.swift         ← attaches FlowComposableMotherboard; activates children
├── {Parent}Builder.swift
├── {Parent}Interactor.swift    ← optional, often empty
├── {Parent}Presenter.swift     ← optional
├── {Parent}ViewController.swift ← UITabBarController subclass OR uses ComposableListViewController
└── ServiceMap+{Parent}.swift
```

### Child (composable element)
```
Sources/Microboards/{Child}/
├── {Child}IOInterface.swift
├── {Child}InOut.swift
├── {Child}Protocols.swift
├── {Child}Board.swift          ← putToComposer instead of show()
├── {Child}Builder.swift
├── {Child}Interactor.swift
├── {Child}Presenter.swift
├── {Child}ViewController.swift
└── ServiceMap+{Child}.swift
```

## Naming

- `{Parent}UserInterface: UIViewController, ComposableInterface` — both required.
- `UIElement(identifier: identifier, contentViewController: nav)` — `identifier` is the child Board's own BoardID.
- Bus naming as in `MICROBOARD_UI.md`.

## Communication

### Parent
```swift
import UIComposable

final class {Parent}Board: ModernContinuableBoard, GuaranteedBoard,
    GuaranteedOutputSendingBoard, GuaranteedActionSendingBoard, GuaranteedCommandBoard {

    typealias InputType = {Parent}Input
    typealias OutputType = {Parent}Output
    typealias FlowActionType = {Parent}Action
    typealias CommandType = {Parent}Command

    private let builder: {Parent}Buildable

    init(identifier: BoardID, builder: {Parent}Buildable, producer: ActivatableBoardProducer) {
        self.builder = builder
        super.init(identifier: identifier, boardProducer: producer)
        registerFlows()
    }

    func activate(withGuaranteedInput input: InputType) {
        let component = builder.build(withDelegate: self)
        let viewController = component.userInterface
        motherboard.putIntoContext(viewController)

        let composableBoard = attachComposableMotherboard(to: viewController)

        composableBoard.serviceMap.mod{Module}
            .ioChildA.flow.addTarget(self) { target, output in
                // react to child output
            }

        composableBoard.serviceMap.mod{Module}.ioChildA.activation.activate()
        composableBoard.serviceMap.mod{Module}.ioChildB.activation.activate()
        composableBoard.serviceMap.mod{Module}.ioChildC.activation.activate()

        switch input.presentation {
        case .rootContext: window.setRootViewController(viewController)
        case .present:     rootViewController.show(viewController)
        }
    }

    func activationBarrier(withGuaranteedInput _: InputType) -> ActivationBarrier? { nil }
    func interact(guaranteedCommand _: CommandType) {}
}
```

### Child
```swift
import UIComposable

final class {Child}Board: ModernContinuableBoard, ... {
    private let builder: {Child}Buildable
    private let returnBus = Bus<Void>()

    func activate(withGuaranteedInput _: InputType) {
        let component = builder.build(withDelegate: self)
        let viewController = component.userInterface
        motherboard.putIntoContext(viewController)

        // TabBar style — wrap in nav, set tab item
        let nav = UINavigationController(rootViewController: viewController)
        nav.tabBarItem.title = "{Tab Title}"
        nav.tabBarItem.image = UIImage(named: "{tab-icon}")

        let element = UIElement(identifier: identifier, contentViewController: nav)
        putToComposer(elementAction: .update(element: element))

        returnBus.connect(target: viewController) { vc in vc.returnHere() }
    }
}
```

### `UIElement` actions
```swift
putToComposer(elementAction: .update(element: UIElement(identifier: identifier, contentViewController: vc)))
putToComposer(elementAction: .reload(identifier: identifier.rawValue))
putToComposer(elementAction: .removeContent(identifier: identifier.rawValue))
putToComposer(elementAction: .updateConfiguration(identifier: identifier.rawValue, configuration: badgeCount))
```

### Container

Conforms to `ComposableInterface`:
```swift
final class {Parent}ViewController: UITabBarController, {Parent}UserInterface {
    weak var actionDelegate: {Parent}ActionDelegate?
    var composedElements: [UIElement] = []
    var elementSortRule: ((UIElement, UIElement) -> Bool)? = nil

    func composeInterface(elements: [UIElement]) {
        composedElements = elements
        viewControllers = elements.compactMap { $0.contentViewController }
    }
}
```

For section lists, use built-in `ComposableListViewController` from `UIComposable` — no subclass needed.

## Concurrency

- All `UIElement` updates fire synchronously from `activate()`; the framework already runs on the main actor.
- Cross-child communication goes through the parent's `composableBoard.serviceMap`, never through retained child references — children are independent and may outlive each other.
- Bus connections in `activate()` retain `self` weakly via `target:` — no manual `[weak self]` capture required.

## Composition

- Add `UIComposable` to the **Plugins** podspec: `s.dependency 'UIComposable'`.
- Register parent + each child in `ModulePlugin.internalContinuousRegistrations`:

```swift
BoardRegistration(.mod{Parent}) { id in
    {Parent}Board(identifier: id, builder: {Parent}Builder(), producer: producer)
}
BoardRegistration(.mod{ChildA}) { id in
    {ChildA}Board(identifier: id, builder: {ChildA}Builder(), producer: producer)
}
BoardRegistration(.mod{ChildB}) { id in
    {ChildB}Board(identifier: id, builder: {ChildB}Builder(), producer: producer)
}
```

## Lifecycle

- Parent is typically a permanent entry point — no double-activation guard, no `complete()` on user nav.
- Child boards live as long as the composer keeps their `UIElement` — removing the element releases the child.
- Children must NOT call `rootViewController.show()`; they register via `putToComposer`. The composer owns presentation.
- `complete()` on a child is rare — usually the parent completes the whole composition.

## Testing

- Parent integration: assert each child board activates once after `activate()` runs.
- Child unit: same VIP test surface as `MICROBOARD_UI.md` — Interactor + Presenter tests dominate.
- `composeInterface(elements:)` is straightforward; one test verifies it forwards `contentViewController`s in order.

## Pitfalls

- ❌ Activating children via `motherboard.serviceMap` instead of `composableBoard.serviceMap` — they end up outside the container.
- ❌ Calling `show()` from a child → child presents itself separately from the container.
- ❌ `{Parent}UserInterface` missing `ComposableInterface` → `attachComposableMotherboard(to:)` won't compile.
- ❌ Forgetting `import UIComposable` in parent or child Board files.
- ❌ Reusing one BoardID across two `UIElement`s — they collide; each child needs a distinct ID.
- ❌ Long-lived child trying to `complete()` itself on user nav — composer expects the child to stay alive.

## References

- `MICROBOARD_UI.md` (single-board variant; required reading for the VIP basics)
- `COMMUNICATION.md` (flow / bus semantics)
- `PLUGINS_INTEGRATION.md` (registering parent + children with ModulePlugin)
- `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded)
- `QUICK_REF.md` §4 rules 5, 6, 7

## Checklist

### Parent
- [ ] `{Parent}UserInterface` extends `UIViewController` AND `ComposableInterface`
- [ ] `attachComposableMotherboard(to: viewController)` called in `activate()`
- [ ] Children activated via `composableBoard.serviceMap`
- [ ] No `rootViewController.show()` on a child board
- [ ] `import UIComposable` present in parent and every child Board

### Child
- [ ] `putToComposer(elementAction: .update(element:))` called in `activate()`
- [ ] `UINavigationController` wrap when used in TabBar (`tabBarItem.title` + `.image` set)
- [ ] `UIElement` uses the child's own `identifier`
- [ ] No `show(viewController)` anywhere in the child

### Container
- [ ] Conforms to `ComposableInterface` (`composedElements`, `composeInterface(elements:)`)
- [ ] TabBar: `composeInterface` sets `viewControllers` from elements
- [ ] List: uses `ComposableListViewController` (no subclass)
