<!-- template-version: 2.4.0 -->

# Examples — placeholder-only binding shapes

These files show section order, table columns, and placeholder placement. They intentionally contain
no fictional project identity, module inventory, paths, build labels, destinations, remotes, commands,
or authority values.

When generating real bindings:

1. Read the matching example only for document shape.
2. Resolve every value from explicit user answers and read-only consuming-repository evidence.
3. Write `TBD` and surface the gap when a required value cannot be resolved; never fill it with an
   illustrative app, module, scheme, simulator, path, URL, or command.
4. Keep project-owned build/test commands and CI/release ownership in the project bindings.
5. Keep the `Module root` binding as one repository-relative token so the source scaffolders can
   resolve it; the scaffolders emit no build/package or CI configuration.
6. Generate the Boardy+VIP `QUICK_REF.md` only when that pattern is actually bound.

## Files

| File | Mirrors | Purpose |
|------|---------|---------|
| `PROJECT_CONFIG.example.md` | `<BindingsRoot>/PROJECT_CONFIG.md` | Identity/path/tooling placeholders, repository-owned commands/CI, Brain-Flow mode, and Git authority shape. |
| `PROJECT_STRUCTURE.example.md` | `<BindingsRoot>/PROJECT_STRUCTURE.md` | Placeholder scheme/target/module inventory and repository-owned discovery commands. |
| `QUICK_REF.example.md` | `<BindingsRoot>/QUICK_REF.md` | Optional Boardy+VIP routing, humble-View contract, and source-only scaffold shape. |

## Placeholder conventions

| Placeholder form | Meaning |
|------------------|---------|
| `<BindingsRoot>` | consuming project's chosen bindings root |
| `{ProjectName}`, `{WorkspaceOrProject}`, `{MainScheme}` | project identity values resolved during setup |
| `{ModuleRoot}`, `{ModuleName}`, `{BoardName}` | repository/task values, never example defaults |
| `{BuildCommand}`, `{TestCommand}`, `{CIOwner}` | consuming-repository governance values |
| `{CommitAuthority}`, `{AutoCommitScope}` | explicit project/user Git authority |

These examples are not snapshots of any working project and are not a second source of truth. Real
project topology and policy belong in that project's bindings and governance.
