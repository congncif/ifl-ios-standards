<!-- Created by claude-opus-4-7 on 2026-05-09 -->
# CONVENTIONS — Swift Style Companion

> `.claude/rules/QUICK_REF.md` is the canonical architecture and naming index. Load this file only when you need Swift style details not covered by task-specific specs.

---

## Canonical Sources

| Need | Use |
|------|-----|
| Architecture and task routing | `.claude/rules/QUICK_REF.md` |
| SDK-first dependency decisions | `.ai/specs/SDK_FIRST.md` |
| Module / IO / BoardID patterns | `.ai/specs/MODULE_CREATION.md`, `.ai/specs/IO_INTERFACE.md` |
| VIP rules | `.ai/specs/MICROBOARD_UI.md`, `.ai/specs/VIP_COMPONENTS.md` |
| Non-UI board selection | `.ai/specs/MICROBOARD_NONUI.md` |
| Service layer and DDD | `.ai/specs/LAYERING.md`, `.ai/specs/SERVICE_LAYER.md` |
| Code review rules | `.ai/specs/REVIEWER_CHECKLIST.md` |

Do not treat this file as an alternate architecture spec. If content conflicts, the canonical spec above wins.

---

## Swift Code Style

### Access modifiers

```swift
// Interface module — public API surface
public final class {ModuleName}ServiceMap: ServiceMap {}
public extension BoardID { static let pub{BoardName}: BoardID = "..." }
public typealias {BoardName}MainDestination = MainboardGenericDestination<...>
public struct {BoardName}Input { ... }

// Implementation module — internal by default
final class {ModuleName}PluginsServiceMap: ServiceMap {}
extension BoardID { static let mod{BoardName}: BoardID = "..." }
struct {ModuleName}ModulePlugin: ModuleBuilderPlugin { ... }
final class {BoardName}Board: ModernContinuableBoard, ... { ... }

// LauncherPlugin — explicitly public
public struct {ModuleName}LauncherPlugin: LauncherPlugin {
    public init() { /**/ }
    public func prepareForLaunching(...) -> ModuleComponent { ... }
}
```

### Async pattern

```swift
Task { [weak self] in
    guard let self else { return }
    do {
        let result = try await useCase.execute()
        await MainActor.run { [weak self] in
            guard let self else { return }
            presenter.presentData(result)
        }
    } catch {
        await MainActor.run { [weak self] in
            guard let self else { return }
            presenter.presentError(error)
        }
    }
}
```

### Weak references

```swift
weak var delegate: {Name}ControlDelegate!
weak var actionDelegate: {Name}ActionDelegate!
weak var view: {Name}Viewable!
```

### Import order

```swift
// 1. System frameworks
import Foundation
import UIKit

// 2. Third-party frameworks, alphabetical
import Boardy
import SiFUtilities

// 3. Internal interface modules, alphabetical
import {ModuleName}
```

---

## Style Rules

- Prefer `final class` for concrete classes unless subclassing is required.
- Prefer structs/enums for Domain models.
- Prefer explicit dependency injection through initializers or builders.
- Keep ViewControllers humble: render ViewModels and forward events only.
- Keep Presenter as the only Domain → ViewModel mapper.
- Keep Interactor free of UI types and `ActionDelegate` references.
- Keep Board stateless; per-session state lives in Controller/Interactor.
- Use event buses for Board → Controller communication.
- Use duplicate-activation guards only for boards explicitly designed as single-session.
- Do not add comments unless the reason is non-obvious.
