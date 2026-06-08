<!-- Created by claude-haiku-4-5 on 2026-05-19 -->

# SPEC: Specification Sync Discipline

> **Purpose**: prevent drift between code and spec files. Load this file before declaring any non-trivial change set complete.
> **Trigger**: any code change that may touch a module category, structural convention, project value, workflow, or generic architecture rule.
> **Owner principle**: code is the source of truth for *instances*; specs hold *patterns*. ADRs record *decisions*.

---

## 1. Sync Detection Checklist

For each row, ask the question against the changes about to be completed. If **yes** → update the listed target **in the same change set**.

| # | Trigger | Update target |
|---|---------|---------------|
| 1 | Added a module that does NOT fit any category in the project's structure docs §2? | the project's structure docs §2 (add category) **+** new ADR explaining the new category |
| 2 | Changed the standard module folder layout, naming pattern, or target-split convention? | `PROJECT_STRUCTURE.md` §1 |
| 3 | Changed an allowed/forbidden dependency direction? | `PROJECT_STRUCTURE.md` §3 |
| 4 | Changed the composition root mechanism (app entry hook, plugin registration shape)? | `PROJECT_STRUCTURE.md` §4 |
| 5 | A new module deviates from the standard convention (skips a target, custom layout, etc.)? | New ADR in the project's decisions location, linked from the project's structure docs §1 or §2 |
| 6 | Changed scheme, simulator, destination, base branch, remote URL, module root, tooling, or naming prefix? | the project's configuration (relevant section — see the consuming repo's `CLAUDE.md`) |
| 7 | Changed a canonical build, test, or verification command? | the project's configuration, build/test commands section |
| 8 | Changed commit/push approval semantics or workflow? | `${CLAUDE_PLUGIN_ROOT}/standards/rules/COMMIT_WORKFLOW.md` |
| 9 | Changed long-plan execution cadence, build-verification rule, or task-batching convention? | `${CLAUDE_PLUGIN_ROOT}/standards/rules/PLAN_EXECUTION.md` |
| 10 | Introduced a task type not routed by `QUICK_REF.md` §1? | `${CLAUDE_PLUGIN_ROOT}/standards/rules/QUICK_REF.md` §1 (add row) |
| 11 | Changed a generic Boardy+VIP architecture rule, naming, protocol placement, or pattern? | Relevant file under `${CLAUDE_PLUGIN_ROOT}/standards/specs/` **+** `${CLAUDE_PLUGIN_ROOT}/standards/specs/REVIEWER_CHECKLIST.md` if review behavior changes |
| 12 | Made an architectural choice that future maintainers will second-guess without context (alternative SDK rejected, deliberate exception, non-obvious trade-off)? | New ADR in the project's decisions location |

If multiple rows fire, update all targets in the same change set. Partial sync = drift.

---

## 2. Anti-Drift Invariants

- **Code is the source of truth for instances.** Never list module names, scheme names, board names, or per-module responsibilities in any spec file. Use discovery commands from `PROJECT_STRUCTURE.md` §5.
- **Specs hold patterns, not inventories.** If you are about to write a list of concrete names in a spec, stop — replace with a discovery command or a category description.
- **Decisions go in ADRs, not in conventions.** The project's structure docs describe *what is normal*; the project's ADR/decisions location records *why a deviation exists*. Never inline rationale into convention files.
- **One change set = one synchronized state.** Code change that triggers any checklist row must ship with the spec update in the same commit/PR. Never "fix the spec later."

---

## 3. When NOT to Update Specs

Resist spec churn for:

- Adding, renaming, or removing a module *instance* (covered by discovery commands).
- Refactoring within an existing module category.
- Adding a feature inside an existing pattern.
- Changing implementation details that respect the existing public contract.
- Bug fixes, perf tweaks, or code-style adjustments.

---

## 4. Pre-Completion Self-Audit

Run this audit **before** declaring work done (before commit, before PR, before final report):

1. Walk §1 checklist against the diff about to be committed.
2. For each triggered row, confirm the matching spec file is in the staged set.
3. If a row is triggered but its target file is NOT staged → either stage the missing update now, OR explicitly tell the user that spec sync is incomplete and which row is unresolved.
4. In the task completion report, list the checklist rows that fired and the spec files that were updated as a result. If none fired, say "no sync triggers fired."

---

## 5. Routing

- Loaded by AI when about to complete a task that may touch spec-sensitive surfaces.
- Referenced from `CLAUDE.md` §11 (principle) and `${CLAUDE_PLUGIN_ROOT}/standards/rules/COMMIT_WORKFLOW.md` Step 2 (review phase).
- Routed in `${CLAUDE_PLUGIN_ROOT}/standards/rules/QUICK_REF.md` §1.
