---
name: brain-flow
description: >-
  Use when the user wants the whole workflow automated end-to-end — analyze → design → architect
  → plan → execute → review → done — instead of driving each stage by hand. Pattern-neutral with
  auto-detection of a bound pattern (e.g. Boardy+VIP). Triggers: "take this feature from idea to
  done", "run the full workflow", "automate the whole process", "end-to-end on this task".
---

# Brain — Flow (end-to-end workflow automation)

Runs the brain stage skills in sequence as one pipeline. Each stage loads only its own rulebook
chapters (see the per-stage skills); this file only orchestrates.

## Stage 0 — Detect scale + pattern binding
1. Read the consuming repo's `CLAUDE.md` (+ bindings per `${CLAUDE_PLUGIN_ROOT}/standards/brain/QUICK_REF.md` §5).
   - Declares Boardy+VIP → **Boardy mode on**: stages also forward to the matching `boardy-*` skill (table below).
   - No pattern bound → run pure brain rulebook; no forwarding.
2. Size the task:
   - **Large** (spans >1 board/module, multi-file feature) **and** Boardy mode → delegate the whole
     delivery to the `ios-orchestrator` agent pipeline (briefing handoff per
     `${CLAUDE_PLUGIN_ROOT}/standards/rules/BRIEFING_HANDOFF.md`) and stop here — the orchestrator
     owns plan → code → test → review → PR.
   - **Small** (≤1 module/board, few files) → run the inline pipeline below.

## Inline pipeline (small tasks)
| Stage | Skill | Forward when Boardy mode |
|-------|-------|--------------------------|
| 1. Analyze | understand request, locate code, surface unknowns | `/ifl-ios-standards:boardy-vip` router for spec routing |
| 2. Design | `/ifl-ios-standards:brain-design` | `boardy-vip` → `DECISION_TREES.md` |
| 3. Architect | `/ifl-ios-standards:brain-architect` | `LAYERING.md`, `CROSS_MODULE_DI.md` via router |
| 4. Plan | `/ifl-ios-standards:brain-plan` — **stop for user approval** | phase along IO → Sources → Plugins seams |
| 5. Execute | `/ifl-ios-standards:brain-execute` | `:boardy-new-module` `:boardy-new-board` `:boardy-io-interface` `:boardy-communication` `:boardy-service-layer` `:boardy-plugin-composition` per change type |
| 6. Test | `/ifl-ios-standards:brain-testing` | `:boardy-testing` |
| 7. Review | `/ifl-ios-standards:brain-review` | `:boardy-review` |
| 8. Report | changed files, commands run, results, remaining work | — |

## Checkpoints
- Verify at phase boundaries only (`${CLAUDE_PLUGIN_ROOT}/standards/process/lean-verification.md`).
- Full build + full suite exactly once, before the final report.
- A failed checkpoint loops back to Execute on that phase — never skip forward past a red signal.

## Guardrails
- Stage 4 approval is mandatory — never execute an unapproved plan.
- Missing binding value → stop and ask, don't guess.
- Report states facts: what changed, what was verified, what remains.
