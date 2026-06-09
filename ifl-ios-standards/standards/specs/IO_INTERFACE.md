<!-- Created by claude-opus-4-7 on 2026-05-09 -->
<!-- Retrofitted to SPEC_CONTRACT 12 sections on 2026-05-23 -->

# SPEC: IO Interface Definition

> Reference: *Modern large-scale iOS app development* — Interface Module contract from Modular + Interface Module pillar. PDF synonym: **Interface Module**.
> Companion: `EXAMPLES_IO.md` (4-file skeleton), `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded).

## When to use

Whenever a module exposes a board to other modules, or defines an internal board with typed inputs/outputs. Every module ships at least one IO target; every board it offers gets a 3-file IO folder under `IO/{Board}/`.

## When NOT to use

- A board is purely scoped inside one module's `Sources/` and consumed only via parent boards there — internal-only boards skip the public IO path but still get an InOut file under `Sources/Microboards/{Board}/`.
- A pure domain type (`Result<...>` value, error enum used inside one module) — those belong in `Domain/`, not IO.
- **Construction wiring** (LauncherPlugin init arguments — provider configurations, options structs, marker protocols the App passes when instantiating `{Module}LauncherPlugin`). These are registration-time plumbing, NOT domain meaning. They live next to the LauncherPlugin under `Sources/Plugins/`, even though they must be `public` for the App to construct them. See §"Domain meaning vs construction wiring" below.

## Domain meaning vs construction wiring

The Interface module (`IO/`) exposes **domain meaning only**: what the module DOES (board activations, inputs, outputs, commands, actions). It does NOT expose HOW the module is wired up at App boot.

| Belongs in IO/ (domain) | Belongs in Sources/Plugins/ (construction) |
|-------------------------|-------------------------------------------|
| BoardID + MainDestination + factory | LauncherPlugin struct |
| Input / Output / Command / Action | LauncherPlugin init arguments (provider configs, options) |
| Module IO ServiceMap | Marker protocols for those arguments (e.g. `{Module}ProviderConfiguration`) |
| Cross-module callable surface | ModulePlugin + Plugins ServiceMap |

Test: ask "does a client module call this to USE the feature, or does App call this to BOOT the feature?" If boot-only → Sources/Plugins/. If use → IO/. Provider configurations fail the test: clients never reference them; only App-boot wiring does.

This is why `Sources/Plugins/**` is the **public-export zone**: it's where LauncherPlugin and its construction inputs live, and the `io_visibility` lint allows `public` there.

## Forces

- Public IO is the only cross-module surface; everything else costs encapsulation. Keep `IO/` minimal — leak nothing you don't intend to support.
- The InOut split (Input / Output / Command / Action) front-loads design but yields a stable cross-module contract; collapsing it (e.g. one `Params` struct) saves files but breaks the destination factory shape.
- BoardID strings are the runtime handle — once published, renaming is breaking. Pick names with the namespacing rules in mind.

## Files

```
IO/
├── {ModuleName}ServiceMap.swift            ← module IO ServiceMap class (one per module)
└── {Board}/
    ├── {Board}IOInterface.swift            ← BoardID + MainDestination typealias + motherboard factory
    ├── {Board}InOut.swift                  ← Input, Output, Command, Action
    └── ServiceMap+{Board}.swift            ← Extension on module IO ServiceMap

Sources/
├── Plugins/{ModuleName}PluginsServiceMap.swift    ← internal ServiceMap
└── Microboards/{InternalBoard}/
    ├── {InternalBoard}IOInterface.swift    ← internal BoardID + typealias
    ├── {InternalBoard}InOut.swift          ← typealiases to public types, or new internal types
    └── ServiceMap+{InternalBoard}.swift    ← extension on Plugins ServiceMap
```

## Naming

- Module IO ServiceMap class: `{ModuleName}ServiceMap` — `public final class`
- Module IO ServiceMap accessor: `mod{ModuleName}` on `ServiceMap`
- Plugins ServiceMap class: `{ModuleName}PluginsServiceMap` — internal, no `public`
- Plugins ServiceMap accessor: `mod{ModuleName}Plugins` on `ServiceMap`
- Public BoardID: `"pub.mod.{ModuleName}IO.{Board}"`, declared as `static let pub{Board}: BoardID`
- Internal BoardID: `"mod.{ModuleName}.{Board}"`, declared as `static let mod{Board}: BoardID`
- MainDestination typealias: `{Board}MainDestination`
- Motherboard factory: `io{Board}(_ identifier:)`

Optional `DAD` prefix applies to module identifiers only — see `QUICK_REF.md` §2.

## Communication

The IO layer defines the **shape** of communication, not the channels.

- `Input` flows: caller → board on `activate(withGuaranteedInput:)`.
- `Output` flows: board → caller via `sendOutput`.
- `Command` flows: caller → live board via `interact(guaranteedCommand:)`.
- `Action: BoardFlowAction` flows: board → motherboard via `sendAction`.

Channel mechanics (buses, flow listeners, delegates) live in `COMMUNICATION.md`. IO only types the payloads.

```swift
// IO/{Module}ServiceMap.swift
public final class {ModuleName}ServiceMap: ServiceMap {}
public extension ServiceMap {
    var mod{ModuleName}: {ModuleName}ServiceMap { link() }
}

// IO/{Board}/{Board}IOInterface.swift
public extension BoardID {
    static let pub{Board}: BoardID = "pub.mod.{ModuleName}IO.{Board}"
}

public typealias {Board}MainDestination = MainboardGenericDestination<
    {Board}Input, {Board}Output, {Board}Command, {Board}Action
>

extension MotherboardType where Self: FlowManageable {
    func io{Board}(_ identifier: BoardID = .pub{Board}) -> {Board}MainDestination {
        {Board}MainDestination(destinationID: identifier, mainboard: self)
    }
}

// IO/{Board}/{Board}InOut.swift
public struct {Board}Input {
    public weak var context: UIViewController?
    public let completion: (() -> Void)?
    public init(context: UIViewController? = nil, completion: (() -> Void)? = nil) {
        self.context = context; self.completion = completion
    }
}
public typealias {Board}Parameter = BlockTaskParameter<{Board}Input, {Board}Output>
public typealias {Board}Output = Void                       // or: public enum {Board}Output { ... }
public typealias {Board}Command = Void                      // or: public enum {Board}Command { ... }
public enum {Board}Action: BoardFlowAction {}

// IO/{Board}/ServiceMap+{Board}.swift
public extension {ModuleName}ServiceMap {
    var io{Board}: {Board}MainDestination { mainboard.io{Board}() }
}
```

For internal boards, drop `public`, replace `pub.mod.{Module}.{Board}` with `mod.{Module}.{Board}`, and extend `{Module}PluginsServiceMap`.

## Concurrency

IO declarations themselves are non-concurrent — they are `struct` / `enum` / `typealias` definitions. The board's `activate` and command handling run on the main actor by Boardy convention; IO does not impose extra constraints. `weak var context: UIViewController?` is the one concurrency-adjacent rule: the caller must not extend the VC's lifetime through `Input`.

## Composition

- IO is consumed in two places: the module's own `ModulePlugin` (`PLUGINS_INTEGRATION.md`) and any other module that depends on this module's IO target.
- Cross-module clients import the IO pod (`{ModuleName}`), never the Plugins pod (`{ModuleName}Plugins`).
- The IO ServiceMap is the only piece of state shared across modules; everything else flows through the motherboard via destinations.

## Lifecycle

- `Input` lifetime: bounded by one activation. Boards must not store the `Input` past `complete()`.
- `weak` context: the presenting VC must outlive the activation but the board must not retain it.
- BoardID is process-global and stable across activations.

## Testing

- `Input.init` stub factories live in test bundles per `compact/TESTING.compact.md`.
- `Output` / `Command` enums are tested through Interactor / Presenter tests — they have no behavior of their own.
- IO module itself has no unit tests; correctness is enforced by `forbidden_imports` + `io_visibility` lints (bundled lint scripts under `${CLAUDE_PLUGIN_ROOT}/standards/scripts/`).

## Pitfalls

- ❌ `public` types in `Sources/Microboards/**`, `Sources/Services/**` — only IO and `Sources/Plugins/**` may export `public`.
- ❌ Putting provider configurations / LauncherPlugin init arguments in `IO/` "because they're public" — confuses domain with construction wiring; they belong in `Sources/Plugins/` next to LauncherPlugin.
- ❌ `s.dependency '{Other}Plugins'` in a podspec — depend on IO target, never on Plugins.
- ❌ Strong `context: UIViewController` — must be `weak`.
- ❌ Renaming a published BoardID — breaks every caller silently at runtime.
- ❌ Extension on global `ServiceMap` (instead of the module's `ServiceMap`) — leaks the board into every consumer's namespace.
- ❌ Importing UIKit in InOut just for `UIViewController` when the board has no UI — drop the field, drop the import.

## References

- `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded)
- `EXAMPLES_IO.md` (worked 4-file skeleton)
- `MODULE_CREATION.md` (full new-module flow)
- `PLUGINS_INTEGRATION.md` (how this IO is registered)
- `COMMUNICATION.md` (channel mechanics on top of these types)
- `QUICK_REF.md` §2 (naming with optional prefix), §4 rules 3, 4

## Access modifier summary

| File | Element | Access |
|------|---------|--------|
| `IO/{ModuleName}ServiceMap.swift` | Class + accessor | `public` |
| `IO/{Board}/{Board}IOInterface.swift` | BoardID, typealias, factory | `public` |
| `IO/{Board}/{Board}InOut.swift` | Input/Output/Command/Action | `public` |
| `IO/{Board}/ServiceMap+{Board}.swift` | Extension accessor | `public` |
| `Sources/Plugins/{ModuleName}PluginsServiceMap.swift` | Class + accessor | internal |
| `Sources/Plugins/{ModuleName}LauncherPlugin.swift` | LauncherPlugin struct + init | `public` (construction wiring) |
| `Sources/Plugins/{ModuleName}{Feature}ProviderConfiguration.swift` | Marker protocol + concrete config | `public` (construction wiring) |
| `Sources/Plugins/{ModuleName}ModulePlugin.swift` | Class | internal |
| `Sources/Microboards/{Board}/{Board}IOInterface.swift` | All | internal |
| `Sources/Microboards/{Board}/ServiceMap+{Board}.swift` | Extension accessor | internal |
| `Sources/Services/**` | All | internal |
