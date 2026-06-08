<!-- Created by claude-opus-4-7 on 2026-05-09 -->
# Boardy+VIP Rules Pack

Generic design and execution standards for modular iOS apps built with Boardy, VIP, plugin composition, and domain-driven layering.

---

## Five Pillars

| # | Pillar | Rule home |
|---|--------|-----------|
| 1 | SDK-first | `.ai/specs/SDK_FIRST.md` |
| 2 | Modular + Interface Module | `.ai/specs/MODULE_CREATION.md`, `.ai/specs/IO_INTERFACE.md` |
| 3 | Plugin Architecture | `.ai/specs/PLUGINS_INTEGRATION.md` |
| 4 | Micro-services Composable | `.ai/specs/MICROBOARD_UI.md`, `.ai/specs/MICROBOARD_NONUI.md`, `.ai/specs/COMMUNICATION.md`, `.ai/specs/COMPOSABLE_BOARD.md` |
| 5 | Domain-driven Layered | `.ai/specs/ARCHITECTURE.md`, `.ai/specs/LAYERING.md`, `.ai/specs/SERVICE_LAYER.md`, `.ai/specs/VIP_COMPONENTS.md` |

---

## Quick Start

1. Copy `.ai/specs/` and `@.claude/agents/` into the target project.
2. Fill `.claude/project/PROJECT_CONFIG.md` with project-specific values: workspace, scheme, simulator, module root, base branch, app entry file.
3. Ensure project `@CLAUDE.md` says: load `.claude/rules/QUICK_REF.md` first, then task-specific specs.
4. Use `.ai/specs/ADOPTION.md` as the migration checklist.
5. Keep project-specific examples out of generic rule files; place them in `.claude/project/PROJECT_CONFIG.md`, project `@CLAUDE.md`, or feature PRDs.

---

## Task Routing

| I want to... | Load |
|--------------|------|
| Pick a pattern (Board type / ID prefix / bus shape / resource scope) | `.ai/specs/DECISION_TREES.md` |
| Adopt pack into a legacy UIKit project (brownfield) | `.ai/specs/BROWNFIELD_MIGRATION.md` |
| Stand up a new iOS app on the pack (greenfield) | `.ai/specs/GREENFIELD_SETUP.md` |
| Debug a symptom / lint failure / runtime crash | `.ai/specs/TROUBLESHOOTING.md` |
| Understand architecture | `.claude/rules/QUICK_REF.md` → `.ai/specs/ARCHITECTURE.md` |
| Choose or add a dependency | `.claude/rules/QUICK_REF.md` → `.ai/specs/SDK_FIRST.md` |
| Create a module | `.claude/rules/QUICK_REF.md` → `.ai/specs/MODULE_CREATION.md` → `.ai/specs/IO_INTERFACE.md` |
| Define public board IO | `.claude/rules/QUICK_REF.md` → `.ai/specs/IO_INTERFACE.md` |
| Build a UI board | `.claude/rules/QUICK_REF.md` → `.ai/specs/MICROBOARD_UI.md` → `.ai/specs/VIP_COMPONENTS.md` |
| Build a non-UI board | `.claude/rules/QUICK_REF.md` → `.ai/specs/MICROBOARD_NONUI.md` |
| Wire board communication | `.claude/rules/QUICK_REF.md` → `.ai/specs/COMMUNICATION.md` |
| Add plugin integration | `.claude/rules/QUICK_REF.md` → `.ai/specs/PLUGINS_INTEGRATION.md` |
| Share service across modules | `.claude/rules/QUICK_REF.md` → `.ai/specs/CROSS_MODULE_DI.md` |
| Implement service layer | `.claude/rules/QUICK_REF.md` → `.ai/specs/SERVICE_LAYER.md` → `.ai/specs/LAYERING.md` |
| Write tests | `.claude/rules/QUICK_REF.md` → `.ai/specs/TESTING.md` |
| Review code — procedural runbook (triage, categorize, comment templates) | `.claude/rules/QUICK_REF.md` → `.ai/specs/REVIEW_PLAYBOOK.md` |
| Review code — exhaustive rule reference | `.claude/rules/QUICK_REF.md` → `.ai/specs/REVIEWER_CHECKLIST.md` |
| Refactor — split/merge module, extract/move Board, rename public symbol | `.claude/rules/QUICK_REF.md` → `.ai/specs/REFACTOR_PLAYBOOK.md` |
| Find skeleton code | `.claude/rules/QUICK_REF.md` → `.ai/specs/EXAMPLES.md` → one matching `EXAMPLES_*.md` |

---

## Assumed Project Shape

The pack assumes an iOS project with:

- Module root such as `{ModuleRoot}/{ModuleName}/`.
- Interface target `{ModuleName}` containing `IO/**/*.swift`.
- Implementation target `{ModuleName}Plugins` containing `Sources/**/*.swift`.
- App-level dependency configuration such as `Podfile` or equivalent package wiring.
- Boardy `Motherboard`, `BoardProducer`, and `ServiceMap` usage.
- Plugin host that installs `LauncherPlugin`s before launch.
- Build/test commands documented outside generic specs, referenced via `.claude/project/PROJECT_CONFIG.md`.

If your project uses different folders or package tooling, update `.claude/project/PROJECT_CONFIG.md` and project `@CLAUDE.md`; do not hard-code those values into generic rules.

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

- Load `.claude/rules/QUICK_REF.md` first.
- Keep Interface Modules public and Implementation Modules internal.
- Consumers import Interface Modules only, never Plugins.
- Board → Controller communication uses event buses, not stored/retrieved controller references.
- `watch(content:)` is lifecycle tracking only.
- Duplicate-activation guard only when a board is explicitly single-session.
- Presenter is the only Domain → ViewModel mapper.
- Domain stays pure: no UIKit, Boardy, networking SDKs, DTOs, or vendor types.
- Concrete Builder structs are composition roots; Board depends on `Buildable` protocol only.
- Project-specific values live in `.claude/project/PROJECT_CONFIG.md`.
