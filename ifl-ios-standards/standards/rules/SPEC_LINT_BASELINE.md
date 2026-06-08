# SPEC_LINT_BASELINE — initial audit 2026-05-23

Run: `swift ${CLAUDE_PLUGIN_ROOT}/standards/scripts/spec_doc_lint.swift ${CLAUDE_PLUGIN_ROOT}/standards/specs`

Result on initial run: **18 / 18 non-conforming** — every pattern spec predates `SPEC_CONTRACT.md` and uses ad-hoc section headings.

Current state (2026-05-23, after batch 5): **0 / 18 non-conforming** — retrofit complete. Cleared:
- Batch 1 — `MICROBOARD_UI.md`, `VIP_COMPONENTS.md`, `IO_INTERFACE.md`
- Batch 2 — `MICROBOARD_NONUI.md`, `COMPOSABLE_BOARD.md`, `PER_ACTIVATION_RESOURCES.md`
- Batch 3 — `COMMUNICATION.md`, `CONTEXT_NAVIGATION.md`, `CROSS_MODULE_DI.md`
- Batch 4 — `SERVICE_LAYER.md`, `PLUGINS_INTEGRATION.md`, `EXTENSIBLE_PROVIDER.md`
- Batch 5 — `ACTIVATION_BARRIER.md`, `LAYERING.md`, `MODULE_CREATION.md`, `ARCHITECTURE.md`, `SDK_FIRST.md`, `TESTING.md`

## Retrofit batches

Retrofit one batch per session to keep diffs reviewable. After each batch, re-run the lint.

| Batch | Specs | Priority reason |
|-------|-------|-----------------|
| 1 | `MICROBOARD_UI.md`, `VIP_COMPONENTS.md`, `IO_INTERFACE.md` | Hottest paths — coder + architect load these most often |
| 2 | `MICROBOARD_NONUI.md`, `COMPOSABLE_BOARD.md`, `PER_ACTIVATION_RESOURCES.md` | Board variants — decision-tree leaves |
| 3 | `COMMUNICATION.md`, `CONTEXT_NAVIGATION.md`, `CROSS_MODULE_DI.md` | Wiring + nav specs |
| 4 | `SERVICE_LAYER.md`, `PLUGINS_INTEGRATION.md`, `EXTENSIBLE_PROVIDER.md` | Service / DI specs |
| 5 | `ACTIVATION_BARRIER.md`, `LAYERING.md`, `MODULE_CREATION.md`, `ARCHITECTURE.md`, `SDK_FIRST.md`, `TESTING.md` | Architecture + module-scoped specs |

## Rule

Until a spec is retrofitted, agents may still load it — `SPEC_CONTRACT.md` governs **new** specs strictly; old specs are grandfathered until their batch lands. Compact specs (`compact/*.compact.md`) are exempt by design.

## Exit criteria

Lint exits `0` against `${CLAUDE_PLUGIN_ROOT}/standards/specs/` and is wired into pre-merge checks (manual until CI exists).
