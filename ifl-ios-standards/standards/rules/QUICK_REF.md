# QUICK_REF — Boardy+VIP binding

> Read this **first** for any task on this project. Then load **one** task-specific spec from the routing table below.
> Generic engineering loop + hard rules live in `${CLAUDE_PLUGIN_ROOT}/standards/brain/QUICK_REF.md`. Boardy/VIP patterns + naming + skeletons live in `${CLAUDE_PLUGIN_ROOT}/standards/specs/compact/BOARDY_CHEATSHEET.compact.md`. This file is the **glue**: which spec / cheatsheet / rule fires for which task.

## Companion canonicals (do not duplicate here)

| Layer | File | What it covers |
|-------|------|----------------|
| Pattern-neutral brain | `${CLAUDE_PLUGIN_ROOT}/standards/brain/QUICK_REF.md` | Operating loop, 10 architecture hard rules, rulebook routing |
| Boardy+VIP cheatsheet | `${CLAUDE_PLUGIN_ROOT}/standards/specs/compact/BOARDY_CHEATSHEET.compact.md` | File layout, naming tables (Module / BoardID / VIP), skeletons, anti-patterns |
| Testing cheatsheet | `${CLAUDE_PLUGIN_ROOT}/standards/specs/compact/TESTING.compact.md` | Mock + interactor-test + stub skeletons |
| Briefing handoff | `${CLAUDE_PLUGIN_ROOT}/standards/rules/BRIEFING_HANDOFF.md` | Briefing schema, discovery cache, delegation prompt |

## 1. Task → spec routing

| Task | Load next |
|------|-----------|
| Pick a pattern (Board type / ID prefix / bus shape / scope) — read FIRST | `${CLAUDE_PLUGIN_ROOT}/standards/specs/DECISION_TREES.md` |
| Adopt pack into existing UIKit project | `${CLAUDE_PLUGIN_ROOT}/standards/specs/BROWNFIELD_MIGRATION.md` |
| Stand up a new app from scratch on the pack | `${CLAUDE_PLUGIN_ROOT}/standards/specs/GREENFIELD_SETUP.md` |
| Debug a symptom / look up an error → cause → fix | `${CLAUDE_PLUGIN_ROOT}/standards/specs/TROUBLESHOOTING.md` |
| Architecture overview / runtime composition | `${CLAUDE_PLUGIN_ROOT}/standards/specs/ARCHITECTURE.md` |
| SDK-first / dependency choice | `${CLAUDE_PLUGIN_ROOT}/standards/specs/SDK_FIRST.md` |
| 3-layer dependency rule / boundary | `${CLAUDE_PLUGIN_ROOT}/standards/specs/LAYERING.md` |
| Project-specific values (scheme, simulator, paths) | the project's configuration — see the consuming repo's `CLAUDE.md` (project config section) |
| Module layout, categories, discovery commands | the project's structure docs — see the consuming repo's `CLAUDE.md` |
| Structural decision rationale / ADRs | the project's ADR / decisions location, if it keeps one |
| Plan execution / verification cadence | `${CLAUDE_PLUGIN_ROOT}/standards/rules/PLAN_EXECUTION.md` |
| Spec sync discipline / pre-completion checklist | `${CLAUDE_PLUGIN_ROOT}/standards/rules/SPEC_SYNC.md` |
| Briefing handoff between sub-agents | `${CLAUDE_PLUGIN_ROOT}/standards/rules/BRIEFING_HANDOFF.md` |
| Commit / push approval rules | `${CLAUDE_PLUGIN_ROOT}/standards/rules/COMMIT_WORKFLOW.md` |
| New module | `${CLAUDE_PLUGIN_ROOT}/standards/specs/MODULE_CREATION.md` |
| IO / BoardID / InOut / ServiceMap | `BOARDY_CHEATSHEET.compact.md` → full `${CLAUDE_PLUGIN_ROOT}/standards/specs/IO_INTERFACE.md` on demand |
| Microboard with UI (VIP) | `BOARDY_CHEATSHEET.compact.md` → `MICROBOARD_UI.md` + `VIP_COMPONENTS.md` |
| Microboard without UI | `${CLAUDE_PLUGIN_ROOT}/standards/specs/MICROBOARD_NONUI.md` (read Decision Tree first!) |
| Cross-module service sharing | `${CLAUDE_PLUGIN_ROOT}/standards/specs/CROSS_MODULE_DI.md` |
| Service / UseCase / Repository / Infra | `${CLAUDE_PLUGIN_ROOT}/standards/specs/SERVICE_LAYER.md` |
| Board communication / Bus / flows | `BOARDY_CHEATSHEET.compact.md` → `COMMUNICATION.md` for edge cases |
| Context navigation / backToPrevious / returnHere | `${CLAUDE_PLUGIN_ROOT}/standards/specs/CONTEXT_NAVIGATION.md` |
| Plugin / LauncherPlugin | `${CLAUDE_PLUGIN_ROOT}/standards/specs/PLUGINS_INTEGRATION.md` |
| ComposableBoard / TabBar | `${CLAUDE_PLUGIN_ROOT}/standards/specs/COMPOSABLE_BOARD.md` |
| Per-activation services / concurrency guard | `${CLAUDE_PLUGIN_ROOT}/standards/specs/PER_ACTIVATION_RESOURCES.md` |
| Multiple interchangeable providers / extensible backend | `${CLAUDE_PLUGIN_ROOT}/standards/specs/EXTENSIBLE_PROVIDER.md` |
| Gate activation behind another board | `${CLAUDE_PLUGIN_ROOT}/standards/specs/ACTIVATION_BARRIER.md` |
| Tests | `${CLAUDE_PLUGIN_ROOT}/standards/specs/compact/TESTING.compact.md` → full `TESTING.md` on demand |
| Code review — procedure / triage / comment templates | `${CLAUDE_PLUGIN_ROOT}/standards/specs/REVIEW_PLAYBOOK.md` |
| Refactor — split/merge module, extract/move Board, rename public symbol | `${CLAUDE_PLUGIN_ROOT}/standards/specs/REFACTOR_PLAYBOOK.md` |
| Code review — exhaustive rule reference | `${CLAUDE_PLUGIN_ROOT}/standards/specs/REVIEWER_CHECKLIST.md` |
| Code example | `${CLAUDE_PLUGIN_ROOT}/standards/specs/EXAMPLES.md` (index) → matching `EXAMPLES_*.md` |

**Non-UI Board decision tree** — answer in order:
0. Does a VIP UI board already serve as entry point? → Let that VIP board coordinate via `registerFlows()`. No Non-UI wrapper.
1. Single async task then done? → **BlockTask Board**
2. Coordinator that must remember a child board's output for a later step? → **Viewless Board**
3. Pure pass-through routing with no UI anchor, reused from multiple entry points, or conditional gate logic? → **Flow Board** (`finishBus` is the only stored property allowed)

## 2. Module naming with optional prefix

The cheatsheet has the no-prefix case. When the project applies a prefix (e.g. `DAD`), prefix only the **public-facing identifiers**; VIP class names stay no-prefix:

| Concept | No prefix | With `DAD` prefix |
|---------|-----------|-------------------|
| Module name | `Profile` | `DADProfile` |
| Module pod | `Profile` | `DADProfile` |
| Plugins pod | `ProfilePlugins` | `DADProfilePlugins` |
| IO ServiceMap class | `ProfileServiceMap` | `DADProfileServiceMap` |
| IO ServiceMap accessor | `modProfile` | `modDADProfile` |
| Plugins ServiceMap class | `ProfilePluginsServiceMap` | `DADProfilePluginsServiceMap` |
| Plugins ServiceMap accessor | `modProfilePlugins` | `modDADProfilePlugins` |
| VIP class names (Board, Builder, Interactor, …) | `ProfileDetail*` | `ProfileDetail*` (no prefix) |

## 3. Protocol location

| Protocol | Lives in | Conformed by |
|----------|---------|-------------|
| `{Name}Interactable` | `{Name}ViewController.swift` | Interactor |
| `{Name}Presentable` | `{Name}Interactor.swift` | Presenter |
| `{Name}Viewable` | `{Name}Presenter.swift` | ViewController |
| `{Name}Controllable` | `{Name}Protocols.swift` | Interactor (UI) or Controller (Viewless) |
| `{Name}ActionDelegate` / `{Name}ControlDelegate` / `{Name}Delegate` | `{Name}Protocols.swift` | Board |
| `{Name}UserInterface` | `{Name}Protocols.swift` | ViewController |
| `{Name}Buildable` | `{Name}Protocols.swift` | Builder struct |

## 4. The 14 rules (never break)

1. **Humble View** (`UI-HUMBLE-001`…`004`): UIKit and SwiftUI Views render display-ready state and forward typed intent. They may branch on presentation state already encoded as loading/content/empty/error, own transient UX-local state (focus, highlight, gesture, animation, scroll, disclosure), and calculate geometry-only or visual interpolation values. They never format raw/domain values, derive product meaning, decide eligibility/pricing/retry/navigation policy, create analytics meaning, fetch/persist business data, or construct business dependencies.
2. **VIP flow** (`BRD-VIP-001`): `VC/View → Interactor → UseCase → Presenter → VC/View`. Exception: `VC/View → ActionDelegate(Board)` for pure-navigation intents the Interactor would only forward.
3. **Contract/export boundary** (`CORE-API-001`, `BRD-MOD-001`): IO modules are `public` domain contracts. `Sources/**` stays `internal` except `Sources/Plugins/**`, which may export the minimum LauncherPlugin construction surface (provider configs and init arguments). Provider configurations are boot-time wiring, never IO domain meaning.
4. **Cross-module dependency** (`CORE-COMP-001`): never import `{ModuleNamePlugins}` from another module — depend on its IO contract only.
5. **UI isolation** (`UI-ISOLATION-001`): UI and presentation-store mutation runs on the declared MainActor boundary; async UIKit updates use `await MainActor.run { [weak self] in ... }`.
6. **Weak back edges** (`BRD-REF-001`): `weak var view` in Presenter; `weak var delegate` in Interactor; `weak var actionDelegate` in ViewController. Interactor must not declare `actionDelegate`.
7. **Flow registration** (`BRD-FLOW-001`): call `registerFlows()` in Board `init`, never in `activate()`.
8. **Activation semantics** (`BRD-ACTIVATION-001`): add a double-activation guard only for an explicitly single-session Board. Board→Controller communication uses event buses, never retrieved controller references.
9. **Domain purity** (`BRD-MOD-001`): Domain is pure Swift — no UIKit, SwiftUI, Boardy, or networking.
10. **Shared ownership** (`BRD-REPOSITORY-001`): `sharedRepository` is a stored property on ModulePlugin, never created inside registration closures.
11. **Copy classification** (`UI-COPY-001`): localize user-facing copy (SwiftGen/module strings). URLs, identifiers, keys, event names, and config values stay inline unless the product explicitly defines locale variants.
12. **Completion lifecycle** (`BRD-LIFE-001`): call `complete()` at most once and only after releasing streams/observers. Stateless boards rarely need it; `BlockTaskBoard` never needs it. Double completion asserts.
13. **Viewless lifecycle** (`BRD-VIEWLESS-001`): attach Controller by priority: explicit `input.context`; `rootViewController`; then Board context as a last resort. Board lifecycle remains independent of Controller lifecycle. Identity filtering applies only to Controller→Board→Bus→Controller round-trips; Board-originated buses rely on the bus's weak target and never fabricate a source through `attachedObject(_:)`.
14. **Concurrent block task** (`BRD-BLOCKTASK-001`): with `executingType: .concurrent`, route each activation through parameter callbacks (`onSuccess`, `onError`), not shared `.flow`. Sequential mode may use `.flow`, though parameter callbacks remain preferred.

## 5. Module folder skeleton (canonical for this project)

```
{ModuleRoot}/{ModuleName}/
├── {ModuleName}.podspec             # IO target: source_files = 'IO/**/*.swift'
├── {ModuleNamePlugins}.podspec      # Plugins target: source_files = 'Sources/**/*.swift'
├── IO/
│   ├── {ModuleName}ServiceMap.swift
│   └── {Board}/
│       ├── {Board}IOInterface.swift
│       ├── {Board}InOut.swift
│       └── ServiceMap+{Board}.swift
└── Sources/
    ├── Plugins/{ModuleName}PluginsServiceMap.swift + {Module}ModulePlugin.swift
    ├── Microboards/{Board}/{Board}{Protocols,Board,Builder,Interactor,Presenter,ViewController}.swift + ServiceMap+{Board}.swift
    └── Services/{Domain, Application, Infra}/...
```

Podfile (hash-rocket only):
```ruby
pod '{Module}',        :path => '{ModuleRoot}/{Module}'
pod '{Module}Plugins', :path => '{ModuleRoot}/{Module}'
```

`s.dependency` carries a name only — never `:path`. `s.dependency 'Boardy', :path => '.'` breaks lint.

## 6. Example dictionary

Load `${CLAUDE_PLUGIN_ROOT}/standards/specs/EXAMPLES.md` (index, ~20 lines) → exactly one of `EXAMPLES_IO`, `EXAMPLES_PLUGIN`, `EXAMPLES_VIP_BOARD`, `EXAMPLES_VIEWLESS_BOARD`, `EXAMPLES_NONUI_BOARDS`, `EXAMPLES_SERVICE`.
