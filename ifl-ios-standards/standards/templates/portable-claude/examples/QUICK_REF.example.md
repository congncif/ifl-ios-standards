<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->

# QUICK_REF.example.md — SHAPE REFERENCE (Boardy+VIP flavor)

> ⚠️ **DO NOT COPY VALUES.** This file shows the *shape* of a project-level `QUICK_REF.md` when the chosen presentation pattern is **Boardy+VIP**.
>
> **Pattern-specific.** If the project chose MVVM / MVP / MVI / TCA / Composable / custom, regenerate this file with that pattern's conventions instead. The generic brain rulebook (`.ai/brain/rulebook/`) stays pattern-neutral; pattern-specific naming/code-patterns belong in this binding file.
>
> When SETUP.md generates the real file:
> - Replace `<SpecsRoot>` with the project's chosen specs folder (declared in `PROJECT_CONFIG.md`).
> - Replace `<BindingsRoot>` with the chosen bindings root (default `.ai/rules/`).
> - Replace illustrative module names (`Auth`, `Profile`) with the project's actuals.
> - Keep ONLY the sections relevant to the chosen pattern; drop the rest.
> - This file is OPTIONAL — generate only if the project has ≥3 task-specific specs.

---

# QUICK_REF — Project Task → Spec Routing (Boardy+VIP)

> Read this file **first** for every task. Then load exactly the one task-specific spec from the routing table below. Do not pre-load specs speculatively.

---

## 1. Task → Spec Routing

| Task | Load next |
|------|-----------|
| Architecture overview / runtime composition | `<SpecsRoot>/ARCHITECTURE.md` |
| SDK-first / dependency choice | `<SpecsRoot>/SDK_FIRST.md` |
| 3-layer dependency rule / cross-layer boundary | `<SpecsRoot>/LAYERING.md` |
| Project-specific values (scheme, simulator, paths) | `<BindingsRoot>/PROJECT_CONFIG.md` |
| New module | `<SpecsRoot>/MODULE_CREATION.md` |
| IO / BoardID / InOut / ServiceMap | `<SpecsRoot>/IO_INTERFACE.md` |
| Microboard with UI (VIP) | `<SpecsRoot>/MICROBOARD_UI.md` + `<SpecsRoot>/VIP_COMPONENTS.md` |
| Microboard without UI | `<SpecsRoot>/MICROBOARD_NONUI.md` (read Decision Tree first!) |
| Cross-module service sharing | `<SpecsRoot>/CROSS_MODULE_DI.md` |
| Service / UseCase / Repository / Infra | `<SpecsRoot>/SERVICE_LAYER.md` |
| Board communication / Bus / flows | `<SpecsRoot>/COMMUNICATION.md` |
| Context navigation / backToPrevious / returnHere / alerts | `<SpecsRoot>/CONTEXT_NAVIGATION.md` |
| Plugin / LauncherPlugin | `<SpecsRoot>/PLUGINS_INTEGRATION.md` |
| ComposableBoard / TabBar | `<SpecsRoot>/COMPOSABLE_BOARD.md` |
| Per-activation services / concurrency guard / routing config in Controller | `<SpecsRoot>/PER_ACTIVATION_RESOURCES.md` |
| Multiple interchangeable providers / OCP extensible backend selection | `<SpecsRoot>/EXTENSIBLE_PROVIDER.md` |
| Gate board activation behind another board | `<SpecsRoot>/ACTIVATION_BARRIER.md` |
| Testing | `<SpecsRoot>/TESTING.md` |
| Code review | `<SpecsRoot>/REVIEWER_CHECKLIST.md` only |
| Code example | `<SpecsRoot>/EXAMPLES.md` (index) → load matching `EXAMPLES_*.md` |

> **Non-UI Board type — decide before writing any code:**
> 0. Does a VIP UI board already serve as the entry point to this flow? → Let that VIP board be the coordinator via `registerFlows()`. Do NOT wrap it with a Non-UI FlowBoard.
> 1. Single async task then done? → **BlockTask Board**
> 2. Coordinator that must remember a child board's output for a later step? → **Viewless Board**
> 3. Pure pass-through routing with NO UI anchor, OR reused from multiple entry points, OR conditional gate logic? → **Flow Board** (`finishBus` is the only stored property allowed)

---

## 2. Naming — Module Level

| Concept | No Prefix | With Prefix `EXA` |
|---------|-----------|-------------------|
| Module name | `Auth` | `EXAAuth` |
| IO podspec | `Auth` | `EXAAuth` |
| Plugins podspec | `AuthPlugins` | `EXAAuthPlugins` |
| No-prefix name (VIP classes) | `Auth` | `Auth` |
| IO ServiceMap class | `AuthServiceMap` | `EXAAuthServiceMap` |
| IO ServiceMap var | `modAuth` | `modEXAAuth` |
| Plugins ServiceMap class | `AuthPluginsServiceMap` | `EXAAuthPluginsServiceMap` |
| Plugins ServiceMap var | `modAuthPlugins` | `modEXAAuthPlugins` |

---

## 3. Naming — BoardID

| Type | Pattern | Example |
|------|---------|---------|
| Public (IO/) | `pub.mod.{ModuleName}.{BoardName}` | `pub.mod.Auth.SignIn` |
| Internal (Sources/) | `mod.{ModuleName}.{BoardName}` | `mod.Auth.SignIn` |
| Internal aliases public | `static let modXxx: BoardID = .pubXxx` | direct alias |

```swift
public extension BoardID { static let pubSignIn: BoardID = "pub.mod.Auth.SignIn" }
extension BoardID { static let modSignIn: BoardID = "mod.Auth.SignIn" }
```

---

## 4. Naming — VIP Classes

| Component | Pattern | Example |
|-----------|---------|---------|
| Board | `{Name}Board` | `SignInBoard` |
| Builder | `{Name}Builder` | `SignInBuilder` |
| Interactor | `{Name}Interactor` | `SignInInteractor` |
| Presenter | `{Name}Presenter` | `SignInPresenter` |
| ViewController | `{Name}ViewController` | `SignInViewController` |
| UseCase protocol | `{Action}UseCase` | `AuthenticateUseCase` |
| UseCase impl | `{Action}UseCaseInteractor` | `AuthenticateUseCaseInteractor` |

---

## 5. Protocol Location Rules

| Protocol | Lives in | Conformed by |
|----------|---------|-------------|
| `{Name}Interactable` | `{Name}ViewController.swift` | Interactor |
| `{Name}Presentable` | `{Name}Interactor.swift` | Presenter |
| `{Name}Viewable` | `{Name}Presenter.swift` | ViewController |
| `{Name}Controllable` | `{Name}Protocols.swift` | Interactor (UI) or Controller (Viewless) |
| `{Name}ActionDelegate` | `{Name}Protocols.swift` | Board |
| `{Name}ControlDelegate` | `{Name}Protocols.swift` | Board |
| `{Name}UserInterface` | `{Name}Protocols.swift` | ViewController |
| `{Name}Buildable` | `{Name}Protocols.swift` | Builder struct |

---

## 6. Key Code Patterns (Boardy+VIP)

### Weak references — always
```swift
weak var delegate: {Name}ControlDelegate!       // Interactor → Board
weak var actionDelegate: {Name}ActionDelegate!  // ViewController → Board
weak var view: {Name}Viewable!                  // Presenter → ViewController
```

### Async/await — mandatory pattern
```swift
Task { [weak self] in
    guard let self else { return }
    do {
        let result = try await useCase.execute()
        await MainActor.run { [weak self] in
            guard let self else { return }
            presenter.presentResult(result)
        }
    } catch {
        await MainActor.run { [weak self] in
            guard let self else { return }
            presenter.presentError(error)
        }
    }
}
```

### registerFlows — always in init, never activate
```swift
init(identifier: BoardID, ...) {
    super.init(identifier: identifier, boardProducer: producer)
    registerFlows()  // LAST line of init
}
```

### Access modifiers
```swift
// IO/  → everything public
public final class AuthServiceMap: ServiceMap {}
public struct SignInInput { ... }

// Sources/  → everything internal
final class AuthPluginsServiceMap: ServiceMap {}
final class SignInBoard: ModernContinuableBoard, ... {}

// LauncherPlugin — explicitly public
public struct AuthLauncherPlugin: LauncherPlugin {
    public init() { /**/ }
}
```

---

## 7. Project-Specific Non-Negotiables (Boardy+VIP)

> Add to the generic brain hard rules (`.ai/brain/rulebook/20-non-negotiable-rules.md`):

1. View has ZERO logic — renders ViewModels, forwards events only.
2. Unidirectional flow: `ViewController → Interactor → UseCase → Presenter → ViewController`. Exception: direct UI navigation intents may go `ViewController → ActionDelegate(Board)`.
3. IO modules are `public`; Sources are `internal`.
4. Never import `{ModuleName}Plugins` from another module — only import IO.
5. `weak var view` in Presenter; `weak var delegate` in Interactor.
6. `registerFlows()` called in Board's `init`, never in `activate()`.
7. Double-activation guard only when the Board is explicitly single-session; Board→Controller communication uses event buses, not retrieved controller references.
8. `sharedRepository` as stored property on ModulePlugin — never created inside closures.
9. `complete()` called at most once; `BlockTaskBoard` auto-completes (never call manually).
10. Viewless boards using `attachObject` must release via `complete()` or `detachObject(_:)`; otherwise re-activation stacks controllers on buses.

---

## 8. Module Folder Skeleton

```
{ModuleRoot}/{ModuleName}/
├── {ModuleName}.podspec             ← IO target: source_files = 'IO/**/*.swift'
├── {ModuleName}Plugins.podspec      ← Plugins target: source_files = 'Sources/**/*.swift'
├── IO/
│   ├── {ModuleName}ServiceMap.swift
│   └── {BoardName}/
│       ├── {BoardName}IOInterface.swift
│       ├── {BoardName}InOut.swift
│       └── ServiceMap+{BoardName}.swift
└── Sources/
    ├── Plugins/
    │   ├── {ModuleName}PluginsServiceMap.swift
    │   └── {ModuleName}ModulePlugin.swift
    ├── Microboards/{BoardName}/
    │   ├── {BoardName}Protocols.swift
    │   ├── {BoardName}Board.swift
    │   ├── {BoardName}Builder.swift
    │   ├── {BoardName}Interactor.swift
    │   ├── {BoardName}Presenter.swift
    │   ├── {BoardName}ViewController.swift
    │   └── ServiceMap+{BoardName}.swift
    └── Services/
        ├── Domain/
        ├── Application/{Action}UseCase.swift
        └── Infra/
```

### Podfile entry
```ruby
pod '{ModuleName}',        :path => '{ModuleRoot}/{ModuleName}'
pod '{ModuleName}Plugins', :path => '{ModuleRoot}/{ModuleName}'
```

### s.dependency — name only, never :path
```ruby
s.dependency 'Boardy'          # correct
# s.dependency 'Boardy', :path => '.'  # WRONG — breaks lint
```

---

## 9. Example Dictionary

Load `<SpecsRoot>/EXAMPLES.md` (index) to find which example file to load. Each example file is a self-contained work unit — load exactly one.

| Work Unit | Example File |
|-----------|--------------|
| IO layer | `<SpecsRoot>/EXAMPLES_IO.md` |
| Plugin layer | `<SpecsRoot>/EXAMPLES_PLUGIN.md` |
| Full VIP UI Board (6 files) | `<SpecsRoot>/EXAMPLES_VIP_BOARD.md` |
| Viewless Board (4 files) | `<SpecsRoot>/EXAMPLES_VIEWLESS_BOARD.md` |
| Flow Board / BlockTask Board | `<SpecsRoot>/EXAMPLES_NONUI_BOARDS.md` |
| Service layer | `<SpecsRoot>/EXAMPLES_SERVICE.md` |
