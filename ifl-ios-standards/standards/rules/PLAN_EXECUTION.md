# SPEC: Plan Execution Workflow

> **Superseded — single source of truth is the process standard.**
> Plan-execution cadence (TDD tiering, checkpoint-based verification, plan phase structure) is
> defined by `${CLAUDE_PLUGIN_ROOT}/standards/process/lean-verification.md`. Read that. This file
> remains only as a stable routing target.

## TL;DR (full detail in lean-verification.md)

- **Tier every task** before coding: Tier 1 full TDD (core logic, public API, money/auth, regressions),
  Tier 2 test-after-batched (adapters, CRUD, wiring), Tier 3 no tests (config, types, docs).
- **Verify at checkpoints, not per task** — cheapest sufficient level: L0 compile → L1 changed-module
  tests → L2 full suite (phase end) → L3 full gate (once, before "done"). Never a full build+suite after
  each task.
- **Plan structure**: group tasks into phases of 3–7; verification only at phase boundaries; each phase
  declares its checkpoint level; each task carries its tier.

For the iOS build/test commands themselves, see the project's `CLAUDE.md` (Bazel/xcodebuild bindings).
