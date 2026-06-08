<!-- Retrofitted to SPEC_CONTRACT 12 sections on 2026-05-23 -->

# SPEC: Architecture (Top-Level Overview)

> Reference: *Modern large-scale iOS app development* (PDF at `.ai/references/Modern large-scale iOS app development.pdf`).
> Companion specs: `SDK_FIRST.md`, `MODULE_CREATION.md`, `IO_INTERFACE.md`, `PLUGINS_INTEGRATION.md`, `MICROBOARD_UI.md`, `MICROBOARD_NONUI.md`, `COMMUNICATION.md`, `COMPOSABLE_BOARD.md`, `LAYERING.md`, `SERVICE_LAYER.md`, `VIP_COMPONENTS.md`, `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded).

## When to use

Read FIRST, before any per-spec rule. Use as the orientation map for:

- New contributors learning the system.
- Cross-cutting refactors that touch multiple pillars.
- Deciding which sibling spec applies to a given task.
- Translating PDF reference vocabulary into codebase terms.

## When NOT to use

- Implementing a single, scoped change inside one Board — the relevant per-spec is more useful.
- Lookups for project-specific names (workspace / scheme / simulator) → those live in `.claude/project/PROJECT_CONFIG.md`.
- Daily operational routing — that's `.claude/rules/QUICK_REF.md`.

## Forces

- Boardy is the pinned UI/coordination engine — non-negotiable across all features.
- Interface Module / Implementation Module split keeps cross-module imports honest: only `{Module}` is consumed externally.
- 5 pillars are orthogonal — applying one in isolation usually leaves dangling violations of another (e.g. adding a Board without splitting IO defeats Pillar 2).
- Terminology drift between PDF and codebase is real; canonical map below prevents review churn.
- App entry file is project-specific (`SceneDelegate` vs `AppDelegate` vs SwiftUI App) — resolve via PROJECT_CONFIG, don't hardcode.

## Files

This spec is governance, not generative — no file shape produced. Touches:

```
.ai/specs/                                  ← all per-pillar specs sit here
.ai/specs/compact/BOARDY_CHEATSHEET.compact.md
.claude/rules/QUICK_REF.md                  ← operational routing index
.claude/project/PROJECT_CONFIG.md           ← project-specific bindings
.ai/references/Modern large-scale iOS app development.pdf
```

Module anatomy this architecture mandates:

```
{ModuleRoot}/{Module}/
├── {Module}.podspec               ← Interface Module (public)
├── {Module}Plugins.podspec        ← Implementation Module (internal)
├── IO/                            ← BoardID, InOut, ServiceMap (public)
│   ├── {Module}ServiceMap.swift
│   └── {Board}/
│       ├── {Board}IOInterface.swift
│       ├── {Board}InOut.swift
│       └── ServiceMap+{Board}.swift
└── Sources/                       ← Implementation (hidden)
    ├── Plugins/                   ← ModulePlugin + LauncherPlugin
    ├── Microboards/{Board}/       ← BA (VIP) per Board
    └── Services/                  ← Domain + Application + Infra + Tracking
```

## Naming

Canonical (PDF) ↔ codebase alias:

| Canonical (PDF) | Codebase alias |
|---|---|
| Interface Module | IO module / `{Module}` target |
| Implementation Module | Plugins module / `{Module}Plugins` target |
| Business Application Layer | VIP layer (Microboards) |
| Domain Layer | Services/Domain |
| Infrastructure Layer | Services/Infra |
| Plugin host | `PluginLauncher` |
| Service registry | `BoardProducer` |
| Service gateway | Motherboard |
| Service contract | `ActivatableBoard`, `InteractableBoard` |
| Service request | `BoardID` + `Input` |
| Service response | `Output` (flow) |
| Service command | `Command` (interaction) |

Left column is canonical; right column appears in legacy code/specs.

## Communication

### 5 pillars

| # | Pillar | Goal | Spec |
|---|---|---|---|
| 1 | **SDK-first** | Prefer first-party platform frameworks; minimize 3rd-party surface | `SDK_FIRST.md` |
| 2 | **Modular + Interface Module** | Split each feature into public `{Module}` (IO) + private `{Module}Plugins` (Sources). Cross-module deps only on the Interface Module. | `MODULE_CREATION.md`, `IO_INTERFACE.md` |
| 3 | **Plugins composition** | Apps assemble at runtime via `PluginLauncher` + `LauncherPlugin` + `ModulePlugin` + `URLOpenerPlugin`. Host = app entry from PROJECT_CONFIG. | `PLUGINS_INTEGRATION.md` |
| 4 | **Micro-services Composable (Boardy)** | Boards are independently activatable services; Motherboard is gateway; `BoardProducer` is registry; `ActivatableBoard`/`InteractableBoard` are contracts. | `MICROBOARD_UI.md`, `MICROBOARD_NONUI.md`, `COMMUNICATION.md`, `COMPOSABLE_BOARD.md` |
| 5 | **Domain-Driven Layering** | Pure Domain core; BA (VIP) on top; Infra & UI at edges. Deps point inward. | `LAYERING.md`, `SERVICE_LAYER.md`, `VIP_COMPONENTS.md` |

### Runtime composition

```
              ┌────────── App entry file ───────────────┐
              │ PluginLauncher                           │
              │   .install({Module}LauncherPlugin()) ×N  │
              │   .initialize()                          │
              │   .launch(in: window) { mainboard in ... }│
              └──────────────┬──────────────────────────┘
                             │
                    Mainboard (gateway)
                             │
          ┌──────────────────┼──────────────────┐
          ▼                  ▼                  ▼
   {ModuleA}             {ModuleB}          {ModuleC}
   ServiceMap            ServiceMap         ServiceMap
       │                     │                  │
   .ioBoardX           .ioBoardY (cross-module via IO only)
```

Activation always: `motherboard.serviceMap.mod{Module}.io{Board}.activation.activate(with:)` — never a direct class reference. See `COMMUNICATION.md`.

### Per-Board VIP

```
   ViewController ──interactor──► Interactor ──► UseCase ──► Repository
        ▲                            │
        │ Viewable (ViewModel)       │ Presentable (domain model)
        │                            ▼
   Presenter ◄─────────────────────┘
                  weak view

   ViewController ──actionDelegate──► Board ──► child board activations
   Interactor    ──delegate──────────► Board (control delegate)
```

Invariants:
1. **View is humble** — zero logic; renders ViewModels, forwards events.
2. **Presenter is the only ViewModel mapper** — Interactor passes domain models only.
3. **Interactor never references `ActionDelegate`** — UI navigation goes `View → ActionDelegate(Board)`.
4. **Board is stateless** — per-session state lives in Interactor (UI) or Controller (Viewless).
5. **Unidirectional** — `View → Interactor → UseCase → Presenter → View`.

Full rules → `VIP_COMPONENTS.md`. UI boards → `MICROBOARD_UI.md`. Non-UI variants → `MICROBOARD_NONUI.md`.

### Cross-module service sharing

Per `CROSS_MODULE_DI.md`:
1. **Pattern A (preferred)** — wrap service in `BlockTaskBoard`, expose via owner's Interface Module. Consumers: `motherboard.serviceMap.mod{Owner}.io{Service}`.
2. **Pattern B (secondary)** — split protocol into `{Module}Core`; resolve via `Resolver` (`@LazyInjected`).

Never depend on `{Module}Plugins` from another module.

### Spec routing

`.claude/rules/QUICK_REF.md` is the daily operational index. This file is the high-level map.

| About to... | Read |
|---|---|
| Scaffold new module | `MODULE_CREATION.md` |
| Define public board IO | `IO_INTERFACE.md` |
| Build UI board | `MICROBOARD_UI.md` + `VIP_COMPONENTS.md` |
| Build non-UI board | `MICROBOARD_NONUI.md` (Decision Tree first) |
| Wire Plugin / Launcher | `PLUGINS_INTEGRATION.md` |
| Compose tabs / sections | `COMPOSABLE_BOARD.md` |
| Author UseCases / repos / models | `SERVICE_LAYER.md` + `LAYERING.md` |
| Connect boards | `COMMUNICATION.md` |
| Share service across modules | `CROSS_MODULE_DI.md` |
| Gate one board on another | `ACTIVATION_BARRIER.md` |
| Plug interchangeable SDKs | `EXTENSIBLE_PROVIDER.md` |
| Per-activation SDK resource | `PER_ACTIVATION_RESOURCES.md` |
| Write tests | `TESTING.md` |
| Review code | `REVIEWER_CHECKLIST.md` |
| Code skeleton | `EXAMPLES.md` |

## Concurrency

- Plugins assemble on main thread during `PluginLauncher.initialize()`.
- Mainboard activations dispatch on main; child Board activations follow Boardy's MainActor rule.
- Cross-module activation respects the target Board's concurrency contract — see `COMMUNICATION.md` Concurrency.

## Composition

- Pillars compose strictly inward: Pillar 5 (Layering) is innermost; Pillar 4 (Boardy) sits in the BA + UI shells; Pillar 3 (Plugins) is the runtime glue; Pillar 2 (Modular) is the build-time boundary; Pillar 1 (SDK-first) governs dependency choices across all.
- Module → ServiceMap → Board → VIP forms one composition tree per feature.
- Cross-module composition uses IO pod's `MainboardGenericDestination` only.

## Lifecycle

- This document — versionless governance; updated when a pillar's scope materially changes.
- Per-spec docs in `.ai/specs/` — versioned alongside code via git history.
- PDF reference — authoritative source for vocabulary; check it when terminology drift suspected.
- Pillars are stable; pattern specs (e.g. `EXTENSIBLE_PROVIDER`, `ACTIVATION_BARRIER`) accrete over time.

## Testing

- Architecture itself is not testable — but its rules are enforceable via lint:
  - `spec_doc_lint.swift` — every spec carries the 12-section contract
  - `forbidden_imports.swift` (planned) — Domain doesn't import UIKit/Boardy/networking; consumers don't `import {Module}Plugins`
  - `io_visibility.swift` (planned) — IO target types are `public`; Sources types are not
  - `boardid_naming.swift` (planned) — `pub.mod.{Module}.{Board}` and `mod.{Module}.{Board}` prefixes
- Spot-check that every new module follows the anatomy diagram (Files section).

## Pitfalls

- ❌ Treating one pillar in isolation (e.g. adding a Board without IO split) — leaves cross-cutting violations.
- ❌ Hardcoding workspace / scheme / simulator names in specs — those belong in `PROJECT_CONFIG.md`.
- ❌ Routing via this doc for daily work — `.claude/rules/QUICK_REF.md` is faster.
- ❌ Using legacy terminology in new code — prefer canonical column.
- ❌ Importing `{Module}Plugins` from another module — Pillar 2 violation; use IO pod.
- ❌ Skipping the PDF cross-reference when introducing a new pattern — drift accumulates.

## References

- `.ai/references/Modern large-scale iOS app development.pdf` (canonical text)
- `SDK_FIRST.md`, `MODULE_CREATION.md`, `IO_INTERFACE.md`, `PLUGINS_INTEGRATION.md`
- `MICROBOARD_UI.md`, `MICROBOARD_NONUI.md`, `COMMUNICATION.md`, `COMPOSABLE_BOARD.md`
- `LAYERING.md`, `SERVICE_LAYER.md`, `VIP_COMPONENTS.md`
- `CROSS_MODULE_DI.md`, `ACTIVATION_BARRIER.md`, `EXTENSIBLE_PROVIDER.md`, `PER_ACTIVATION_RESOURCES.md`
- `CONTEXT_NAVIGATION.md`, `TESTING.md`
- `DECISION_TREES.md` (pick-a-pattern navigator — read BEFORE choosing Board type / ID / bus shape)
- `.claude/rules/QUICK_REF.md` (operational routing)
- `.claude/project/PROJECT_CONFIG.md` (project bindings)
- `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded)
