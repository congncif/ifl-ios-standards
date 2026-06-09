<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->

# Examples — Shape References for Generated Bindings

> ⚠️ **These are shape references, not templates to copy verbatim.** Values are illustrative (fictional `ExampleApp` + generic modules: `Auth`, `Profile`, `Catalog`, `Cart`, `Payment`, `Settings`, `DesignSystem`). They do NOT come from any real project.
>
> When SETUP.md generates the project's real bindings, the AI must:
> 1. Read the matching example to learn the **shape** (section order, table columns, command formats, placeholder syntax).
> 2. Fill values from the user's actual answers + project introspection (`xcodebuild -list`, etc.).
> 3. Never copy identity values (project name, workspace, URLs, simulator) from the example.
> 4. Never copy module names from the example — list the project's real modules instead.
> 5. Drop sections that don't apply to the chosen pattern/tooling.

## Files

| File | Mirrors | Purpose |
|------|---------|---------|
| `PROJECT_CONFIG.example.md` | `<BindingsRoot>/PROJECT_CONFIG.md` | Identity, paths, tooling, build/test commands, dependency triggers, AI workspace layout, placeholder resolution. |
| `PROJECT_STRUCTURE.example.md` | `<BindingsRoot>/PROJECT_STRUCTURE.md` | Scheme inventory, module inventory, synchronization rules, verification commands. |
| `QUICK_REF.example.md` | `<BindingsRoot>/QUICK_REF.md` | **Pattern-specific.** Shape reference assumes Boardy+VIP. If the project chose a different pattern (MVVM, TCA, etc.), regenerate accordingly. Generate only if the project has ≥3 task-specific specs. |

## Placeholder conventions used in these examples

| Placeholder | Meaning |
|-------------|---------|
| `<BindingsRoot>` | Project's chosen bindings root (default `.claude/project/`) |
| `<SpecsRoot>` | Project's chosen specs folder (declared in `PROJECT_CONFIG.md`) |
| `{ProjectName}`, `{Workspace}`, `{Scheme}`, etc. | Identity placeholders — see PROJECT_CONFIG §9 for resolution map |
| `{ModuleName}`, `{BoardName}`, `{Name}` | Per-task placeholders bound at the time of the task |
| `Auth`, `Profile`, `Catalog`, ... | Illustrative module names — replace with the project's actual modules |
| `ExampleApp`, `example-org` | Illustrative identity — replace with the project's actual identity |

## Single source warning

These examples drift from real projects over time. They are NOT a snapshot of any specific live project. If the team wants to keep a working-project snapshot for reference, store it under the project's `docs/01-living-docs/` tree, not in this template folder.
