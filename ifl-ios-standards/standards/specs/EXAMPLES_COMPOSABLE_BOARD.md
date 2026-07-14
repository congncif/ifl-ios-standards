<!-- Created by claude-opus-4-7 on 2026-05-23 -->
# EXAMPLES: Composable Board (TabBar / multi-child container)

End-to-end skeleton for a Composable parent Board that drives a container ViewController hosting N children. Children activate themselves into the container via `putToComposer(elementAction: .update(element: UIElement(...)))` — they never call `show()`.

Companion spec: `COMPOSABLE_BOARD.md`. Cross-module dep: Plugins podspec must `s.dependency 'UIComposable'`.

Placeholders: `{Parent}` = parent Board name (e.g. `MainTab`), `{Module}` = parent module, `{ChildA}` / `{ChildB}` = child Board names, `{ChildAModule}` / `{ChildBModule}` = child modules.

Files live in `Sources/Microboards/{Parent}/` for the parent and the container, and in each child module's `Sources/Microboards/{ChildX}/` for children.

---

## 1. Parent Composable Board

```swift
// Sources/Microboards/{Parent}/{Parent}Board.swift
import Boardy
import Foundation
import UIComposable
import UIKit

final class {Parent}Board: ModernContinuableBoard, GuaranteedBoard,
    GuaranteedOutputSendingBoard, GuaranteedActionSendingBoard, GuaranteedCommandBoard {

    typealias InputType  = {Parent}Input
    typealias OutputType = {Parent}Output
    typealias FlowActionType = {Parent}Action
    typealias CommandType    = {Parent}Command

    private let builder: {Parent}Buildable

    init(identifier: BoardID, builder: {Parent}Buildable, producer: ActivatableBoardProducer) {
        self.builder = builder
        super.init(identifier: identifier, boardProducer: producer)
    }

    func activate(withGuaranteedInput input: InputType) {
        // 1. Build the container VC (must conform to ComposableInterface).
        let component = builder.build(input: input)
        watch(content: component.controller)
        // Connect any parent navigation buses to component.viewController here, before exposure.
        motherboard.putIntoContext(component.viewController)

        // 2. Mount a Composable motherboard onto the prepared container VC.
        //    This returns a board whose serviceMap is the activation surface for children.
        let composableBoard = attachComposableMotherboard(to: component.viewController)

        // 3. Activate each child through composableBoard.serviceMap — NOT motherboard.serviceMap.
        //    The child's BoardID must be registered against the composable motherboard
        //    (typically in the parent's ModulePlugin via .composing(...) — see COMPOSABLE_BOARD.md).
        composableBoard.serviceMap.mod{ChildAModule}
            .io{ChildA}.activation.activate(with: {ChildA}Input(identifier: "tab.a"))

        composableBoard.serviceMap.mod{ChildBModule}
            .io{ChildB}.activation.activate(with: {ChildB}Input(identifier: "tab.b"))

        // 4. Show container as usual.
        rootViewController.show(component.viewController, sender: self)
    }

    func activationBarrier(withGuaranteedInput input: InputType) -> ActivationBarrier? { nil }
    func interact(guaranteedCommand: CommandType) {}
}
```

---

## 2. Container ViewController (`ComposableInterface`)

```swift
// Sources/Microboards/{Parent}/{Parent}TabContainer.swift
import UIComposable
import UIKit

final class {Parent}TabContainer: UITabBarController, ComposableInterface {

    // ComposableInterface requirement: a stable list of UIElements (one per tab slot).
    var composedElements: [UIElement] = []

    func composeInterface(elements: [UIElement]) {
        composedElements = elements

        // Map each UIElement to a UIViewController for the tab bar.
        let tabs: [UIViewController] = elements.compactMap { element in
            guard let child = element.contentViewController else { return nil }
            // Children typically arrive already wrapped in UINavigationController;
            // if not, wrap here. tabBarItem must be set on the nav controller (or the child itself).
            return child
        }
        setViewControllers(tabs, animated: false)
    }
}
```

> The container is dumb: it owns no business logic, only the visual arrangement. All child wiring happens in step 3 above.

---

## 3. Parent Builder

```swift
// Sources/Microboards/{Parent}/{Parent}Builder.swift
import Foundation
import UIKit

struct {Parent}Interface {
    let controller: AnyObject              // any reference type; container view controller works
    let viewController: UIViewController
}

protocol {Parent}Buildable {
    func build(input: {Parent}Input) -> {Parent}Interface
}

struct {Parent}Builder: {Parent}Buildable {
    func build(input: {Parent}Input) -> {Parent}Interface {
        let vc = {Parent}TabContainer()
        return {Parent}Interface(controller: vc, viewController: vc)
    }
}
```

---

## 4. Child Board (one slot in the container)

```swift
// {ChildAModule}/Sources/Microboards/{ChildA}/{ChildA}Board.swift
import Boardy
import Foundation
import UIComposable
import UIKit

final class {ChildA}Board: ModernContinuableBoard, GuaranteedBoard,
    GuaranteedOutputSendingBoard, GuaranteedActionSendingBoard, GuaranteedCommandBoard {

    typealias InputType  = {ChildA}Input
    typealias OutputType = {ChildA}Output
    typealias FlowActionType = {ChildA}Action
    typealias CommandType    = {ChildA}Command

    private let builder: {ChildA}Buildable

    init(identifier: BoardID, builder: {ChildA}Buildable, producer: ActivatableBoardProducer) {
        self.builder = builder
        super.init(identifier: identifier, boardProducer: producer)
    }

    func activate(withGuaranteedInput input: InputType) {
        let component = builder.build(withDelegate: self, input: input)
        watch(content: component.controller)
        // Connect any child navigation buses to component.viewController here, before exposure.
        motherboard.putIntoContext(component.viewController)

        // Wrap the child's VC in a nav controller and decorate the tab item.
        let nav = UINavigationController(rootViewController: component.viewController)
        nav.tabBarItem.title = input.title
        nav.tabBarItem.image = input.icon

        // Hand the element to the composer — this is the ONLY way a Composable child
        // surfaces its UI. Never call rootViewController.show(_:).
        putToComposer(elementAction: .update(
            element: UIElement(identifier: input.identifier, contentViewController: nav)
        ))
    }

    func activationBarrier(withGuaranteedInput input: InputType) -> ActivationBarrier? { nil }
    func interact(guaranteedCommand: CommandType) {}
}

extension {ChildA}Board: {ChildA}Delegate {
    func finish(from controller: {ChildA}Controllable, output: {ChildA}Output) {
        // Removing the element from the composer when the child completes:
        putToComposer(elementAction: .remove(identifier: controller.identifier))
        sendOutput(output)
        complete()
    }
}
```

> `UIElement.identifier` is the contract between child and container. Reuse the same identifier in `.update`/`.remove` so the composer can find the slot.

---

## 5. ModulePlugin registration (parent)

```swift
// Sources/Plugins/{Parent}ModulePlugin.swift
import Boardy
import Foundation

final class {Parent}ModulePlugin: ModulePlugin {

    var continuousRegistrations: [BoardRegistration] {
        [
            BoardRegistration(.pub{Parent}) { id in
                {Parent}Board(
                    identifier: id,
                    builder: {Parent}Builder(),
                    producer: $0
                )
            }
        ]
    }

    // Children of a Composable parent are registered against the composable motherboard
    // (so composableBoard.serviceMap resolves them). The exact syntax depends on the
    // composing helper in your project — see COMPOSABLE_BOARD.md §"Registering children".
    var composingRegistrations: [ComposingRegistration] {
        [
            .composing(parent: .pub{Parent}, children: [
                .pub{ChildA},
                .pub{ChildB}
            ])
        ]
    }
}
```

The ModulePlugin and composing registrations remain internal. Only the minimum LauncherPlugin
construction surface used by App boot may be public from `Sources/Plugins/**` (`CORE-API-001`).

---

## 6. Cross-module wiring (podspec)

```ruby
# {Module}/{Module}Plugins.podspec
Pod::Spec.new do |s|
  s.name = '{Module}Plugins'
  # ...
  s.dependency 'Boardy'
  s.dependency 'UIComposable'                 # required for attachComposableMotherboard / putToComposer
  s.dependency '{Module}'                     # own IO target
  s.dependency '{ChildAModule}'               # child IO targets
  s.dependency '{ChildBModule}'
end
```

---

## Direction matrix

| Direction | Mechanism |
|---|---|
| Parent → activates child | `composableBoard.serviceMap.mod{X}.ioY.activation.activate(with:)` (NOT `motherboard.serviceMap`) |
| Child → renders into container | `putToComposer(elementAction: .update(element: UIElement(...)))` (NEVER `rootViewController.show`) |
| Child → removes itself | `putToComposer(elementAction: .remove(identifier:))` then `sendOutput` + `complete()` |
| Parent ← child output | Standard `motherboard.serviceMap.mod{X}.ioY.flow.addTarget(self)` (parent listens via parent's serviceMap, not composableBoard's) |
| Container ← composer | `composeInterface(elements:)` callback driven by `putToComposer` calls |

## Pitfalls

- ❌ Activating children via `motherboard.serviceMap` instead of `composableBoard.serviceMap` → children spawn outside the container, container stays empty
- ❌ Child calls `rootViewController.show(...)` → bypasses the composer, double UI
- ❌ Forgetting `s.dependency 'UIComposable'` in Plugins podspec → build fails at `attachComposableMotherboard`
- ❌ Setting `tabBarItem` on the inner content VC instead of the wrapping `UINavigationController` → tab item invisible in some configurations; standardize on the nav wrapper
- ❌ Reusing the same `UIElement.identifier` across two children → composer overwrites the slot

## References

- `COMPOSABLE_BOARD.md` (full spec — pattern source)
- `MICROBOARD_UI.md` (UI Board lifecycle baseline)
- `PLUGINS_INTEGRATION.md` (ModulePlugin / `composingRegistrations` shape)
- `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded)
