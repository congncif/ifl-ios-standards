<!-- Created by claude-opus-4-7 on 2026-05-09 -->
# iOS Standards Specs

Reusable design and execution standards for modular iOS apps, including pattern-neutral guidance plus Boardy/VIP, plugin composition, and domain-driven layering references.

---

## Five Pillars

| # | Pillar | Rule home |
|---|--------|-----------|
| 1 | SDK-first | `standards/specs/SDK_FIRST.md` |
| 2 | Modular + Interface Module | `standards/specs/MODULE_CREATION.md`, `standards/specs/IO_INTERFACE.md` |
| 3 | Plugin Architecture | `standards/specs/PLUGINS_INTEGRATION.md` |
| 4 | Micro-services Composable | `standards/specs/MICROBOARD_UI.md`, `standards/specs/MICROBOARD_NONUI.md`, `standards/specs/COMMUNICATION.md`, `standards/specs/COMPOSABLE_BOARD.md` |
| 5 | Domain-driven Layered | `standards/specs/ARCHITECTURE.md`, `standards/specs/LAYERING.md`, `standards/specs/SERVICE_LAYER.md`, `standards/specs/VIP_COMPONENTS.md` |

---

## Quick Start

1. Install and enable the `ifl-ios-standards` plugin.
2. Seed the target project bindings with `ifl-init` or `/ifl-ios-standards:init`.
3. Fill the target repo's `CLAUDE.md` / `AGENTS.md` project values: workspace, scheme, simulator, module root, base branch, app entry file.
4. Use `standards/specs/ADOPTION.md` as the migration checklist when adopting the standards in an existing project.
5. Keep project-specific examples out of reusable rule files; place them in the consuming repo's `CLAUDE.md`, `AGENTS.md`, `.claude/project/PROJECT_CONFIG.md`, or feature PRDs.

---

## Task Routing

Use `${CLAUDE_PLUGIN_ROOT}/standards/specs/...` paths when referencing these files from Claude Code skills/agents. Under Codex, resolve the same paths relative to the plugin root.

| I want to... | Load |
|--------------|------|
| Pick a pattern (Board type / ID prefix / bus shape / resource scope) | `standards/specs/DECISION_TREES.md` |
| Adopt pack into a legacy UIKit project (brownfield) | `standards/specs/BROWNFIELD_MIGRATION.md` |
| Stand up a new iOS app on the pack (greenfield) | `standards/specs/GREENFIELD_SETUP.md` |
| Debug a symptom / lint failure / runtime crash | `standards/specs/TROUBLESHOOTING.md` |
| Understand architecture | `standards/brain/rulebook/` → `standards/specs/ARCHITECTURE.md` |
| Choose or add a dependency | `standards/specs/SDK_FIRST.md` |
| Create a module | `standards/specs/MODULE_CREATION.md` → `standards/specs/IO_INTERFACE.md` |
| Define public board IO | `standards/specs/IO_INTERFACE.md` |
| Build a UI board | `standards/specs/MICROBOARD_UI.md` → `standards/specs/VIP_COMPONENTS.md` |
| Build a non-UI board | `standards/specs/MICROBOARD_NONUI.md` |
| Wire board communication | `standards/specs/COMMUNICATION.md` |
| Add plugin integration | `standards/specs/PLUGINS_INTEGRATION.md` |
| Share service across modules | `standards/specs/CROSS_MODULE_DI.md` |
| Implement service layer | `standards/specs/SERVICE_LAYER.md` → `standards/specs/LAYERING.md` |
| Write tests | `standards/specs/TESTING.md` |
| Review code — procedural runbook (triage, categorize, comment templates) | `standards/specs/REVIEW_PLAYBOOK.md` |
| Review code — exhaustive rule reference | `standards/specs/REVIEWER_CHECKLIST.md` |
| Refactor — split/merge module, extract/move Board, rename public symbol | `standards/specs/REFACTOR_PLAYBOOK.md` |
| Find skeleton code | `standards/specs/EXAMPLES.md` → one matching `EXAMPLES_*.md` |

---

## Assumed Project Shape

The specs support modular iOS projects with:

- Module root such as `{ModuleRoot}/{ModuleName}/`.
- Interface target `{ModuleName}` containing `IO/**/*.swift`.
- Implementation target `{ModuleName}Plugins` containing `Sources/**/*.swift`.
- App-level dependency configuration such as `Podfile`, `BUILD.bazel`, `Package.swift`, or equivalent package wiring.
- Optional Boardy `Motherboard`, `BoardProducer`, and `ServiceMap` usage when the project adopts Boardy/VIP.
- Optional plugin host that installs `LauncherPlugin`s before launch.
- Build/test commands documented outside reusable specs, referenced via the consuming repo's `CLAUDE.md` / `AGENTS.md` or `.claude/project/PROJECT_CONFIG.md`.

If your project uses different folders or package tooling, update the consuming repo's project bindings; do not hard-code those values into reusable rules.

---

## Terminology Map

| Canonical term | Common alias |
|----------------|--------------|
| Interface Module | IO module / public target |
| Implementation Module | Plugins module / Sources target |
| Business Application Layer | VIP layer / Microboards |
| Domain Layer | Services/Domain |
| Infrastructure Layer | Services/Infra, Tracking, concrete Builders |
| Plugin host | `PluginLauncher` |
| Service registry | `BoardProducer` |
| Service gateway | Motherboard |
| Service contract | `ActivatableBoard`, `InteractableBoard` |
| Service request | `BoardID` + Input |
| Service response | Output flow |
| Service command | Interaction command |

---

## Non-Negotiables

- Start from the consuming repo's `CLAUDE.md` / `AGENTS.md` bindings, then load the relevant plugin skill/spec/process docs.
- Keep Interface Modules public and Implementation Modules internal.
- Consumers import Interface Modules only, never Plugins.
- Board → Controller communication uses event buses, not stored/retrieved controller references.
- `watch(content:)` is lifecycle tracking only.
- Duplicate-activation guard only when a board is explicitly single-session.
- Presenter is the only Domain → ViewModel mapper.
- Domain stays pure: no UIKit, Boardy, networking SDKs, DTOs, or vendor types.
- Concrete Builder structs are composition roots; Board depends on `Buildable` protocol only.
- Project-specific values live in the consuming repo's project bindings.
