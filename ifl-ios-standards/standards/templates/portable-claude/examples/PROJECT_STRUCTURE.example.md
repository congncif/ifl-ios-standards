<!-- template-version: 2.5.0 -->

# PROJECT_STRUCTURE.example.md — placeholder-only shape reference

> **Do not copy project values from an example.** Populate the real inventory from read-only
> consuming-repository discovery. Do not invent schemes, targets, modules, paths, roles, build-system
> conventions, or commands. If the repository is single-target, state that instead of fabricating
> module rows.

---

# PROJECT_STRUCTURE — Project Topology Contract

> **Purpose**: describe current project-owned schemes/targets, modules, responsibilities, and source
> boundaries. Global values and canonical commands live in `<BindingsRoot>/PROJECT_CONFIG.md`.
>
> **Update rule**: update this file in the same change whenever repository topology changes.

---

## 1. Project-Owned Scheme / Target Inventory

| Scheme or target | Purpose | Structure owner |
|------------------|---------|-----------------|
| `{SchemeOrTarget}` | `{Purpose}` | `{RepositoryRelativePath}` |

Repeat the row only for project-owned entries returned by the repository's native inventory. Omit
third-party dependency schemes/targets and any entry whose ownership cannot be established.

---

## 2. Module Inventory

| Module | Role | Public contract target | Implementation target |
|--------|------|------------------------|-----------------------|
| `{ModuleName}` | `{ModuleRole}` | `{InterfaceTarget}` | `{ImplementationTargetOrNone}` |

For a single-target repository, replace the table with an explicit statement that no independent
module inventory exists. For Boardy+VIP modules, record the real public IO and implementation targets;
do not infer target names merely from scaffolded folder names.

---

## 3. Synchronization Rules

Update this file when any of these repository facts change:

- project-owned scheme or target added, removed, or renamed;
- module added, removed, renamed, split, merged, or moved;
- module responsibility or public contract changes;
- interface/implementation target names or source ownership change;
- app composition topology changes;
- build/package integration changes the structural inventory.

Do not update it for temporary experiments that do not change repository topology.

---

## 4. Repository-Owned Inventory Commands

Record the actual read-only commands used to refresh this inventory:

```bash
{SchemeAndTargetInventoryCommand}
{ModuleInventoryCommand}
{SourceBoundaryInventoryCommand}
```

These are discovery commands owned by the consuming repository, not plugin verifier scripts or CI.
