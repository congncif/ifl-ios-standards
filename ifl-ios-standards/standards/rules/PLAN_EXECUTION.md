<!-- Created by claude-opus-4-7 on 2026-05-19 -->
# SPEC: Plan Execution Workflow

> **Purpose**: Define reusable execution cadence for long implementation plans.

## Long Plan Build Optimization

When executing a multi-step plan (3+ tasks), **skip `xcodebuild` after each individual task**.

Instead:
- Implement all tasks without per-task build verification.
- Create **one dedicated final task** at the end of the plan: `"Final review & build verification"`.
- That final task runs the project's canonical build command (defined in the consuming repo's `CLAUDE.md`) and reports results once.

**Rationale**: `xcodebuild` is slow (~60–120s per run). Running it after every task wastes time and blocks execution flow. A single end-of-plan build catches all compile errors in one pass.

**Exception**: run an intermediate build only if:
- A task introduces a new file, target, or dependency that must be linked before the next task can compile.
- The user explicitly requests a mid-plan build check.

## Task List Requirement

For any 3+ task plan, include a final task named:

```text
Final review & build verification
```

That task owns:
- final code review
- architecture compliance check when relevant
- canonical build/test verification
- factual report of pass/fail output
