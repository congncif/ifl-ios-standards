---
name: boardy-vip
description: >-
  Read FIRST for any task on a Boardy+VIP iOS project (this repo's iOS architecture standard).
  Use when working on iOS Swift modules built with Boardy + VIP — creating modules or boards,
  wiring IO/BoardID/ServiceMap, board communication/buses, services/use-cases, plugin composition,
  testing, code review, refactoring, troubleshooting, or adopting the pattern. Routes the task to
  the right bundled spec and to the matching `/ifl-ios-standards:boardy-{task}` skill, and states
  the 14 non-negotiable rules + naming/protocol-placement conventions.
---

# Boardy+VIP — task router

This is the entry point for the **ifl-ios-standards** pack. It tells you which bundled
reference doc and which task skill to load for the work at hand. All reference content ships
inside the plugin at `${CLAUDE_PLUGIN_ROOT}/standards/…` (read it on demand — do not guess).

> **Runtime note.** Paths shown as `${CLAUDE_PLUGIN_ROOT}/standards/…` point at this plugin's
> installed root. Claude Code substitutes the variable inline. **Under Codex** (which does not
> expand it), read the same paths **relative to this plugin's root directory** — e.g.
> `standards/specs/IO_INTERFACE.md` within the installed plugin.

**Per-project values** (scheme, simulator, module roots, build/test commands, base branch, git
remote, naming prefix, ADR/decisions location) are **not** in this pack — they live in the
consuming repo's `CLAUDE.md`. Read that for anything project-specific.

The multi-agent pipeline workspace (work-item artifacts under `docs/02-working-docs/work-items/` per
the docs-organization process standard) is **optional** — only the delegated orchestrator flow uses
it. Single-agent tasks ignore it.

## 1. Task → load next

| Task | Skill | Bundled doc |
|------|-------|-------------|
| Pick a pattern (Board type / ID prefix / bus shape / scope) — FIRST | — | `${CLAUDE_PLUGIN_ROOT}/standards/specs/DECISION_TREES.md` |
| New module | `/ifl-ios-standards:boardy-new-module` | `${CLAUDE_PLUGIN_ROOT}/standards/specs/MODULE_CREATION.md` |
| New board (UI / viewless / flow / blocktask) | `/ifl-ios-standards:boardy-new-board` | `${CLAUDE_PLUGIN_ROOT}/standards/specs/MICROBOARD_UI.md`, `MICROBOARD_NONUI.md` |
| IO / BoardID / InOut / ServiceMap | `/ifl-ios-standards:boardy-io-interface` | `${CLAUDE_PLUGIN_ROOT}/standards/specs/IO_INTERFACE.md` |
| Board communication / Bus / flows / context nav | `/ifl-ios-standards:boardy-communication` | `${CLAUDE_PLUGIN_ROOT}/standards/specs/COMMUNICATION.md`, `BUS_PATTERNS.md`, `CONTEXT_NAVIGATION.md` |
| Service / UseCase / Repository / Infra / layering / cross-module DI | `/ifl-ios-standards:boardy-service-layer` | `${CLAUDE_PLUGIN_ROOT}/standards/specs/SERVICE_LAYER.md`, `LAYERING.md`, `CROSS_MODULE_DI.md` |
| Plugin / LauncherPlugin / ComposableBoard / TabBar / providers / barrier | `/ifl-ios-standards:boardy-plugin-composition` | `${CLAUDE_PLUGIN_ROOT}/standards/specs/PLUGINS_INTEGRATION.md`, `COMPOSABLE_BOARD.md`, `EXTENSIBLE_PROVIDER.md`, `ACTIVATION_BARRIER.md` |
| Tests | `/ifl-ios-standards:boardy-testing` | `${CLAUDE_PLUGIN_ROOT}/standards/specs/compact/TESTING.compact.md` → `TESTING.md` |
| Code review | `/ifl-ios-standards:boardy-review` | `${CLAUDE_PLUGIN_ROOT}/standards/specs/REVIEW_PLAYBOOK.md`, `REVIEWER_CHECKLIST.md` |
| Refactor (split/merge module, extract/move board, rename public symbol) | `/ifl-ios-standards:boardy-refactor` | `${CLAUDE_PLUGIN_ROOT}/standards/specs/REFACTOR_PLAYBOOK.md` |
| Debug a symptom / error → cause → fix | `/ifl-ios-standards:boardy-troubleshoot` | `${CLAUDE_PLUGIN_ROOT}/standards/specs/TROUBLESHOOTING.md` |
| Init a project's CLAUDE.md + AGENTS.md bindings | `/ifl-ios-standards:init` | runs `${CLAUDE_PLUGIN_ROOT}/bin/ifl-init` + template starter |
| Adopt into existing app / greenfield setup | `/ifl-ios-standards:boardy-adopt` | `${CLAUDE_PLUGIN_ROOT}/standards/specs/BROWNFIELD_MIGRATION.md`, `GREENFIELD_SETUP.md`, `ADOPTION.md` |
| Architecture overview / runtime composition | — | `${CLAUDE_PLUGIN_ROOT}/standards/specs/ARCHITECTURE.md` |
| Code example | — | `${CLAUDE_PLUGIN_ROOT}/standards/specs/EXAMPLES.md` (index) → one `EXAMPLES_*.md` |

**Process-stage skills** (pattern-neutral, brain-rulebook-driven — pick by *stage* of work rather
than Boardy topic): `/ifl-ios-standards:brain-design`, `:brain-architect`, `:brain-plan`,
`:brain-execute`, `:brain-testing`, `:brain-review`. End-to-end automation:
`/ifl-ios-standards:brain-flow` (auto-detects the Boardy binding and forwards back to the table above).

Companion canonicals (don't duplicate — read on demand):
- Operating loop + 10 architecture hard rules: `${CLAUDE_PLUGIN_ROOT}/standards/brain/QUICK_REF.md`
- Boardy+VIP cheatsheet (layout, naming tables, skeletons): `${CLAUDE_PLUGIN_ROOT}/standards/specs/compact/BOARDY_CHEATSHEET.compact.md`
- Full routing reference: `${CLAUDE_PLUGIN_ROOT}/standards/rules/QUICK_REF.md`

Process standards (apply to every task):
- Where project docs/plans/handoffs live: `${CLAUDE_PLUGIN_ROOT}/standards/process/docs-organization.md`
- Checkpoint economics (TDD tiers, review/gate ownership, evidence reuse): `${CLAUDE_PLUGIN_ROOT}/standards/process/lean-verification.md`

## 2. The 14 rules (never break)

1. View is humble — it renders display-ready state and forwards typed intent. It may branch on
   Presenter-encoded presentation state, own transient UX-local state, and calculate geometry-only
   visual values. Formatting raw/domain values, deriving product or analytics meaning, deciding
   business/navigation policy, fetching/persisting data, and constructing business dependencies stay
   outside the View.
2. Unidirectional flow: `VC → Interactor → UseCase → Presenter → VC`. Exception: `VC → ActionDelegate(Board)` for pure-navigation intents the Interactor would only forward.
3. IO modules are `public`; `Sources/**` is `internal` EXCEPT `Sources/Plugins/**` (may be `public` for LauncherPlugin wiring). Provider configs live in `Sources/Plugins/`, never IO.
4. Never import `{ModuleName}Plugins` from another module — only IO.
5. UI and presentation-store mutation runs on an explicit MainActor boundary. Code already isolated
   to MainActor calls that boundary directly; code crossing from nonisolated work uses `await
   MainActor.run { [weak self] in ... }` or an equivalent `@MainActor` hop.
6. `weak var view` in Presenter; `weak var delegate` in Interactor; `weak var actionDelegate` in ViewController. Interactor must NOT declare actionDelegate.
7. `registerFlows()` called in Board's `init`, never in `activate()`.
8. Double-activation guard only when the Board is explicitly single-session. All Board→Controller communication uses event buses, never retrieved controller references.
9. Domain layer is pure Swift — no UIKit, no Boardy, no networking.
10. `sharedRepository` is a stored property on ModulePlugin — never created inside closures.
11. Classify string literals before localizing: user-facing → Localizable (SwiftGen); URLs/identifiers/keys/event names/config values stay inline.
12. `complete()` called at most once, only after the Board released all streams/observers. `BlockTaskBoard` never needs it. Double-`complete()` raises an assertion.
13. Viewless boards attach Controller with context priority: explicit `input.context` → `rootViewController` → `attachObject(controller)`. Board lifecycle independent of Controller's. Bus identity-filter applies only to round-trips.
14. `BlockTaskBoard` with `.concurrent` — use parameter callbacks (`onSuccess`/`onError`); `.flow.addTarget` is unreliable across concurrent activations.

Full detail + protocol-location table (§3) + naming-with-prefix table (§2) + canonical module
skeleton (§5): `${CLAUDE_PLUGIN_ROOT}/standards/rules/QUICK_REF.md`.

## 3. Specialist agents (delegated pipeline)

For multi-step feature delivery, delegate to the 9 bundled agents. Claude Code exposes them in
`/agents`; Codex exposes them after `ifl-init` installs the project-scoped `.codex/agents/` templates:
`ios-orchestrator` (tech lead), `ios-planner`, `ios-researcher`, `ios-architect`, `ios-coder`,
`ios-tester`, `ios-reviewer`, `ios-review-triage`, `ios-doc-scribe`. Start with `ios-orchestrator`
for large/critical delivery or when multiple semantic checkpoints require coordinated specialist
ownership. File count alone does not select a workflow or checkpoint. Model-tier rationale per agent:
`${CLAUDE_PLUGIN_ROOT}/standards/AGENT_MODEL_TIERING.md`.

## 4. Scaffolders (on PATH when this plugin is enabled)

- `ifl-init` — seed a project's `CLAUDE.md` + `AGENTS.md` bindings (detects git/manager/module-root). See `/ifl-ios-standards:init`.
- `ifl-new-module <Name>` — scaffold the Boardy public-IO and Plugins source boundary; the consuming
  repository owns build/package configuration.
- `ifl-new-board <Module> <Board> <ui|swiftui|viewless|flow|blocktask>` — scaffold a board source
  skeleton with UIKit or SwiftUI selected explicitly.

See `/ifl-ios-standards:init`, `:boardy-new-module`, `:boardy-new-board`.
