<!-- Created by claude-opus-4-7 on 2026-05-09 -->
# REVIEWER_CHECKLIST

> Load this file (+ QUICK_REF.md) for ALL code review tasks.
> Do NOT load individual specs for review -- everything needed is here.
>
> **Looking for the *procedure* (triage order, categorization, comment templates, escalation)?**
> → `REVIEW_PLAYBOOK.md`. This file is the rules reference; the playbook is how to apply them.

---

## Architecture Rules (check every PR)

- [ ] **Humble View (`UI-HUMBLE-001`…`004`)** — renders display-ready state, may branch on presenter-encoded loading/content/empty/error state, owns only UX-local interaction state and geometry/visual interpolation, and forwards typed intent; no raw/domain formatting, product or analytics meaning, business/navigation-policy decisions, business I/O, or dependency construction
- [ ] Unidirectional flow only (`BRD-VIP-001`): View -> Interactor -> UseCase -> Presenter -> View
- [ ] String literals are classified by meaning before localization: user-facing text content uses Localizable strings (SwiftGen/module strings); URLs, identifiers, keys, file names, analytics event names, and config values are not localized unless they need locale-specific variants
- [ ] IO exports the minimum public domain contract; `Sources/**` is internal except the minimum App boot construction surface in `Sources/Plugins/**` (`CORE-API-001`)
- [ ] No feature module imports another `{ModuleNamePlugins}` target; feature-to-feature dependencies use IO contracts only (`CORE-COMP-001`)
- [ ] UIKit rendering and SwiftUI presentation-store mutation run on the declared MainActor boundary (`UI-ISOLATION-001`)
- [ ] `weak var view` in every Presenter; `weak var delegate` in every Interactor
- [ ] `registerFlows()` called in `init`, never in `activate()`
- [ ] Domain layer: no UIKit, no Boardy, no network frameworks
- [ ] SDK-first checked: native/platform option preferred before new third-party dependency
- [ ] `sharedRepository` / `sharedTracker` are stored properties on ModulePlugin, not locals
- [ ] **Board is STATELESS** — no per-session input/context/flags on Board; UI session state lives in Interactor and Viewless session state lives in Controller (`BRD-LIFE-001`)
- [ ] **Board → Controller communication uses event buses** — Board never stores/retrieves controller references to communicate; lifecycle tracing/duplicate checks must not become a communication path
- [ ] **Correct communication mechanism chosen** — `sendOutput()` for child→direct parent; `broadcastAction()` for signals targeting one or more upstream ancestors; Command for Motherboard→already-activated child or sibling→sibling within the same Motherboard

---

## Per-Activation Resources (check boards wrapping external services)

- [ ] No per-activation service stored as Board property — service created inside `activate()` only
- [ ] `attachObject(service)` called immediately after service creation in `activate()`
- [ ] `complete()` called after `sendOutput()` to release attached object
- [ ] Concurrency guard is a dedicated class shared via LauncherPlugin, not a flag on Board or Controller
- [ ] Routing/provider config injected into Controller (via Builder), not stored on Board
- [ ] Protocol splits activation into per-provider methods when routing varies; Board impls are pure ServiceMap calls

---

## Activation Barrier (check boards that gate another board's activation)

- [ ] `activationBarrier(withGuaranteedInput:)` returns non-nil only when the board is intentionally gated
- [ ] Uses `.barrier(with: {BarrierBoard}Input(...))` — not `.barrier()` — when barrier board InputType ≠ Void
- [ ] Correct scope: `.mainboard` for per-session gates; `.application` for app-wide singleton gates
- [ ] Barrier board (`{BarrierBoard}`) calls `complete()` in **every** exit path (`sendOutput` then `complete()`)
- [ ] Barrier board `OutputType` carries a typed result enum when callers need to distinguish outcomes (not `Void`)
- [ ] All controller exit paths pass the result to `delegate?.finish(_ result:)` before `complete()`
- [ ] Gated board's implementation target declares its dependency on `{BarrierModule}` with the
  consuming repository's bound package/build adapter
- [ ] No double-`complete()` on barrier board (all exit paths lead to exactly one `complete()`)

---

## Extensible Provider Architecture (check modules with multiple external providers/frameworks)

- [ ] `public enum {Feature}ProviderConfiguration` does NOT exist — enum form is forbidden (OCP violation)
- [ ] `public protocol {Feature}ProviderConfiguration {}` is a marker only (no methods)
- [ ] `protocol Internal{Feature}ProviderConfiguration` is `internal`, has factory methods, lives in Sources/Plugins/
- [ ] Concrete configs are `public struct` conforming to the **internal** factory protocol
- [ ] Concrete config implements `func setup()` with SDK-specific initialization; SDK framework imported in config file only
- [ ] `{Type}ProviderInOut.swift` defines `typealias {Type}ProviderInput = Void` — alias lives here, not on the Board
- [ ] Provider boards use `typealias InputType = {Type}ProviderInput` — named InOut alias; **never** `typealias InputType = Void` directly (breaks IOInterface contract)
- [ ] Unified `BoardID` per service type (not per provider × type combination)
- [ ] `ModulePlugin.internalContinuousRegistrations` uses `as!` cast + factory dispatch — no `switch` on provider
- [ ] `hostProvider` is a stored property on `ModulePlugin`, created once in `prepareForLaunching`
- [ ] `launchSettings` in `ModuleComponent` calls `internalConfig.setup()` — SDK initialized once at launch
- [ ] Adding a new provider = new files only; zero existing file modifications

---

## Module Structure

- [ ] Module lives under the `{ModuleRoot}` declared by the consuming repository's root
  `CLAUDE.md` or `AGENTS.md` binding
- [ ] The native build/package adapter maps `IO/**` to the public Interface target and `Sources/**`
  to the internal Implementation target
- [ ] Cross-target dependencies preserve the Interface/Implementation direction in the repository's
  native manifest; manager-specific syntax is reviewed only when that adapter is actually used
- [ ] Any dependency refresh required by that adapter ran once for this completed structural slice
- [ ] LauncherPlugin is wired in the app entry file declared by project bindings via
  `.install(launcherPlugin:)` before `.initialize()`
- [ ] App entry file imports `{ModuleNamePlugins}`, not `{ModuleName}`

---

## IO Layer

- [ ] `{ModuleName}ServiceMap` is `public final class`; ServiceMap extension is `public`
- [ ] Public BoardID string format: `pub.mod.{ModuleName}.{BoardName}` (NB: no `IO` suffix on `{ModuleName}` — that was a 0.6.0 misconvention, corrected in 0.6.1)
- [ ] Internal BoardID string format: `mod.{ModuleName}.{BoardName}`
- [ ] All Input/Output/Command/Action types are `public`
- [ ] `context: UIViewController?` in Input is `weak var`
- [ ] `{Name}Action: BoardFlowAction` (usually empty enum — add cases only when one or more upstream ancestors need the signal via `broadcastAction()`; for direct parent use `sendOutput()` instead)
- [ ] `BlockTaskParameter<Input, Output>` typealias present
- [ ] ServiceMap extension is on `{ModuleName}ServiceMap`, not global `ServiceMap`

---

## Plugins Layer

- [ ] `{ModuleName}PluginsServiceMap` is `internal` (no `public` keyword)
- [ ] `ServiceType: CaseIterable` enum with one case per public board
- [ ] `ServiceType.identifier` maps to public BoardID from IO
- [ ] `sharedRepository` / `sharedTracker` declared as stored properties on plugin struct
- [ ] `internalContinuousRegistrations` uses result builder syntax (no `return`, no `[...]`)
- [ ] `build()` returns the coordinator/entry board for the active `service`
- [ ] `URLOpenerPlugin` activates via Plugins ServiceMap (`mod{ModuleName}Plugins`), not IO ServiceMap
- [ ] `LauncherPlugin` struct is `public`; `init()` is `public init() { /**/ }`
- [ ] `prepareForLaunching` maps `ServiceType.allCases` to plugin instances

---

## UI Board (Full VIP)

- [ ] Extends `ModernContinuableBoard` (not plain `Board`)
- [ ] All 4 `Guaranteed*` conformances + typealiases present
- [ ] `private let builder: {Name}Buildable` (dependencies via builder, not stored directly)
- [ ] `watch(content: component.controller)` called in `activate()` for lifecycle tracking when applicable
- [ ] `watch(content:)` / watched-content retrieval is not used for Board→Controller communication
- [ ] `motherboard.putIntoContext(viewController)` called BEFORE `show()`
- [ ] `rootViewController.show(viewController)` preferred — only deviate for custom navigation SiFUtilities `show(_:)` cannot express, or when embedding into a Composable surface (`COMPOSABLE_BOARD.md`)
- [ ] No custom `context:` on `show()` unless explicitly required (target a specific VC instead of inferring from root, or pin lifecycle to a known UIViewController)
- [ ] `completeBus` connected in `activate()` AFTER `show()`
- [ ] Board conforms to `{Name}Delegate` (ActionDelegate + ControlDelegate)
- [ ] Registered in `ModulePlugin.internalContinuousRegistrations`

---

## Non-UI Board

### Flow Board
- [ ] No builder, no use cases stored on board
- [ ] Uses `finishBus.deliver {}` for input completion callbacks
- [ ] Child board flows registered in `registerFlows()` called from `init`
- [ ] Double-activation guard only when the flow is explicitly single-session

### Viewless Board (Controller-based)
- [ ] `private let builder: {Name}Buildable` present
- [ ] Controller is `NSObject` subclass (required for Attachable)
- [ ] Controller attached with context per priority: **(1) explicit input context** → **(2) `rootViewController`** → **(3) Board context (no `context:`)**. Board context is the last resort; prefer explicit input context whenever the work has a natural reference owner (typically a UIViewController, but the attach context is `AnyObject` — not pinned to UIViewController). See `MICROBOARD_NONUI.md` §Controller Attachment Context.
- [ ] Round-trip buses (Controller → Board delegate → Bus → Controller) carry the **source Controller** in the payload (`Bus<{Name}Controllable>` or tuple) and subscriber gates with `guard target === source`. Closing over the local controller variable is **not** an identity filter.
- [ ] Board-originated buses (e.g. child flow → Board → Controller) use plain `Bus<Void>` (or payload-only); rely on `bus.connect(target:)`'s weak binding. **Never** call `attachedObject(_:)` to fabricate a source — that's a retrieved controller reference and is forbidden.
- [ ] **NO double-activation guard** — Board can be activated multiple times, each activation creates new controller session
- [ ] ALL state (input, use cases, flags) in Controller, not Board
- [ ] Controller's `delegate` is `weak var {Name}ControlDelegate?`
- [ ] Protocols file defines: Controllable, ControlDelegate, Delegate, Interface, Buildable
- [ ] **Event buses used for Board→Controller communication** — one bus per action/method
- [ ] **Buses connected in `activate()`** — `bus.connect(target: controller) { ... }`
- [ ] **Buses transported in `registerFlows()`** — `bus.transport(input: value)`
- [ ] **NEVER store or retrieve controller reference directly** — use event buses for all Board→Controller communication in viewless boards
- [ ] **Explicit controller release** — `attachObject` is self-managed; use `complete()` (end session) or `detachObject(_:)` (release controller, keep Board alive); without explicit release, re-activation stacks controllers on buses → duplicate handler execution per event

### BlockTask Board
- [ ] Performs one async operation then `sendOutput()`
- [ ] Handles both success and failure paths
- [ ] **Concurrent mode**: results via parameter callbacks (`.onSuccess`, `.onError`); `.flow.addTarget` unreliable — result cannot be matched to originating activation
- [ ] **Sequential mode**: `.flow.addTarget` acceptable; parameter callbacks preferred but optional
- [ ] When using parameter callbacks: at least `onSuccess` provided — omitting silently drops the result

---

## VIP Components

### Protocols.swift
- [ ] ALL protocols for one board in ONE file
- [ ] `{Name}Interactable` NOT in Protocols.swift (lives in ViewController file)
- [ ] `{Name}Presentable` NOT in Protocols.swift (lives in Interactor file)
- [ ] `{Name}Viewable` NOT in Protocols.swift (lives in Presenter file)

### Interactor
- [ ] `{Name}Presentable` protocol defined at top of Interactor file
- [ ] `{Name}Presentable` methods accept **domain model types only** — never ViewModels
- [ ] `weak var delegate: {Name}ControlDelegate!`
- [ ] `private let presenter: {Name}Presentable`
- [ ] `didBecomeActive()` is the VIP entry point (called by ViewController.viewDidLoad)
- [ ] Conforms to `{Name}Controllable` (marker for Board's `watch(content:)`)
- [ ] Async tasks: `Task { [weak self] in guard let self else { return } ... }`
- [ ] **NO ViewModel construction** — Interactor never instantiates `{Name}ViewModel`
- [ ] Interactor does not declare/reference `ActionDelegate`
- [ ] Direct UI navigation intents are not forwarded by Interactor; those are sent from ViewController to `ActionDelegate`

### Presenter
- [ ] `{Name}Viewable` protocol defined at top of Presenter file
- [ ] ViewModels (structs/enums) defined in Presenter file
- [ ] `weak var view: {Name}Viewable!`
- [ ] All raw/domain → display-ready mapping and formatting lives here, never in a UIKit/SwiftUI View
- [ ] Private `map(_ model:) -> ViewModel` function does all domain→ViewModel conversion

### ViewController
- [ ] `{Name}Interactable` protocol defined at top of ViewController file
- [ ] `weak var actionDelegate: {Name}ActionDelegate!`
- [ ] `viewDidLoad` calls `interactor.didBecomeActive()`
- [ ] Renders and forwards; conditionals inspect display-ready presentation state only, never raw/domain data
- [ ] Conforms to `{Name}Viewable`

### SwiftUI rendering adapter
- [ ] MainActor presentation store conforms to the same display port and receives the same semantic ViewModel as UIKit
- [ ] SwiftUI View observes display-ready state and forwards typed intent; it does not call UseCases or hold domain models
- [ ] `@State` / local observation owns UX-only focus, disclosure, gesture, animation, and scroll mechanics — never product/business state
- [ ] Same domain input produces equivalent loading/content/empty/error meaning in UIKit and SwiftUI; only rendering mechanics differ

### Builder
- [ ] Wires Presenter.view = viewController
- [ ] Wires interactor.delegate = delegate (Board)
- [ ] Wires viewController.interactor = interactor
- [ ] Wires viewController.actionDelegate = delegate (Board)
- [ ] Returns `{Name}Interface(userInterface: viewController, controller: interactor)`

---

## Service Layer

- [ ] Domain models: pure Swift structs/enums, no UIKit, no Boardy
- [ ] Error types: `enum {Name}Error: Error` in Domain/Models
- [ ] Repository protocols: in Domain/Repositories, no Codable
- [ ] UseCase naming: protocol = `{Action}UseCase`, impl = `{Action}UseCaseInteractor`
- [ ] UseCase impl does NOT have a `UseCaseInteractor` init that creates shared infra (pass via init)
- [ ] Infrastructure DTOs: Codable structs in Infra, not Domain
- [ ] `.toDomain()` mapping in Infra layer, never in Domain

---

## ComposableBoard (TabBar)

- [ ] ComposableBoard registered as `GuaranteedBoard` + activation sets up tabs
- [ ] Each tab = one child board activated in `activate()`
- [ ] Tab switching via `interaction` command, not direct board calls
- [ ] Read `COMPOSABLE_BOARD.md` from this plugin's `standards/specs/` for full rules (not duplicated here)

---

## Context Navigation (check every PR with navigation)

### Simple Back Navigation
- [ ] `backToPrevious()` called on **current ViewController** via bus (not rootViewController)
- [ ] Cancel/back bus declared in Board (e.g., `private let cancelBus = Bus<Void>()`)
- [ ] Bus connected to current ViewController in `activate()`: `cancelBus.connect(target: component.userInterface) { $0.backToPrevious() }`
- [ ] Bus transported from delegate method
- [ ] `sendOutput()` called after bus transport

### Targeted Return Navigation
- [ ] `returnHere()` called on **destination ViewController** via bus (not rootViewController)
- [ ] Return bus declared in **destination Board** (coordinator)
- [ ] Bus connected to destination's ViewController in `activate()`: `returnBus.connect(target: component.userInterface) { $0.returnHere() }`
- [ ] Coordinator's `registerFlows()` transports bus on child completion output
- [ ] Child boards send output only (no direct navigation)
- [ ] Never `rootViewController.returnHere()` or `rootViewController.backToPrevious()` — always via bus to specific ViewController

### Alert/Modal Presentation
- [ ] Current-screen alerts/sheets may be presented directly by the current ViewController when the message is pure rendering for that screen
- [ ] Cross-board, cross-flow, or stale-context-risk alerts/modals present on `rootViewController.topPresentedViewController`
- [ ] Never presents out-of-scope UI on bare `rootViewController` or stale `context`
- [ ] Sheet presentation configured if needed (detents, grabber)
- [ ] No "detached view controller" warnings in console

### Context Passing
- [ ] Context passed as `rootViewController` when child needs it
- [ ] Context used for child board activation, not stored on Board
- [ ] Context not passed for simple navigation stack pushes

### Bus Usage for Navigation
- [ ] No direct navigation method calls without bus
- [ ] All navigation triggered via bus transport
- [ ] Buses connected in `activate()`, transported in delegate methods or `registerFlows()`
