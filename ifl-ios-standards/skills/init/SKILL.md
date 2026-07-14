---
name: init
description: >-
  Use when setting up a new (or not-yet-wired) iOS project to adopt Standards 1.0 Core and record
  its applicable architecture/UI Profiles — generate CLAUDE.md + AGENTS.md bindings and the nine
  project-scoped Codex specialist-agent configurations.
  Triggers: "init the project", "set up CLAUDE.md / AGENTS.md", "wire this repo into the
  ifl-ios-standards plugin", "bootstrap bindings", "onboard this iOS project", or "adopt Boardy"
  when Boardy/VIP is actually selected.
---

# Initialize project bindings and Codex agents

Generate the consuming repo's `CLAUDE.md` + twin `AGENTS.md` and install the nine Codex specialist
templates under `.codex/agents/`. Claude Code discovers the packaged `agents/*.md` directly; Codex
requires project-scoped TOML agent files. The standard itself stays in the plugin.

## 1. Seed via the bundled helper

Run the scaffolder. It copies the binding starter and Codex agent templates, and pre-fills only values
backed by unambiguous repository evidence. Governed or ambiguous bindings remain `{Placeholders}`.
The plugin ships the command in `bin/`; invoke it by name only when the host exports that directory or
an installed shim directory is on shell `PATH`:

```bash
ifl-init --root=.            # add --force to overwrite existing CLAUDE.md/AGENTS.md
# preview first: ifl-init --root=. --dry-run
# existing bindings: ifl-init --root=. --codex-agents-only
```

If `ifl-init` isn't on `PATH`, run it from the known plugin root:
`${CLAUDE_PLUGIN_ROOT}/bin/ifl-init --root=.` With separate installation authority,
`scripts/install-codex.sh` can create dynamic shims in `~/.local/bin`; that directory must also be on
the invoking shell's `PATH`.

It refuses to overwrite matching bindings or agent files without `--force`. Use
`--codex-agents-only` to add the named Codex roles to an already-bound repository without touching
`CLAUDE.md`/`AGENTS.md`.

## 2. Fill the remaining {Placeholders} by introspection

`ifl-init` leaves the values it can't infer as `{Placeholders}`. Detect + fill them, then ask the
user only for what's genuinely ambiguous:

| Placeholder | How to resolve |
|-------------|----------------|
| `{MainScheme}` | `xcodebuild -list` (CocoaPods/SPM) or the `xcodeproj()` rule target name (Bazel). For per-feature Bazel targets, note that rather than a single scheme. |
| `{Simulator}` / `{Destination}` | Resolve from repository governance or an observed native destination inventory. If no supported destination is identified, leave unresolved and ask; do not choose a device default. |
| `{BuildCommand}` / `{TestCommand}` | Copy the canonical commands from repository governance, CI configuration, Makefile, or equivalent owned entry point. If absent or ambiguous, leave unresolved and ask; do not synthesize commands from the package manager. |
| `{BuildSystem}` / `{BuildIntegration}` | `ifl-init` fills these only when Bazel, CocoaPods, or SwiftPM is unambiguous from repository files. Otherwise resolve from repository governance and actual build manifests; do not infer targets or commands from the ecosystem name. |
| `{ModulePrefix}` | Scan existing module/type names for a common prefix (e.g. `DAD`); empty if none. |
| `{CommitPrefix}` | Look at recent `git log` for a ticket-key convention (e.g. `TCW-1234`); ask the user if unclear. |
| `{Workspace}` (if unresolved) | Resolve the repository's actual generated `*.xcodeproj` or `.xcworkspace`; ask when multiple candidates exist. |

Edit `CLAUDE.md` to fill these, then mirror the exact content into `AGENTS.md` (keep the twins
**identical** — copy `CLAUDE.md` over `AGENTS.md` after editing).

Leave the structural example tokens (`{ModuleName}`, `{Name}`) as-is — they're illustrative in the
table prose, not values to resolve.

Before routing the first change, select Profiles from repository and change evidence:

- `core` always applies;
- select `uikit` and/or `swiftui` only for UI surfaces that use them;
- select `boardy-vip` only when the repository/change already uses Boardy or explicitly adopts it;
- route enterprise chapters only when their governed concern applies.

Always persist the selection in both generated bindings. Under `## 3. Identity and project authority`,
add or update one row named `Selected Standards Profiles` whose value contains `core` plus only the
observed `uikit`, `swiftui`, and `boardy-vip` selections. If the repository also owns an adoption or
work-item record, keep its selection consistent with that binding. Do not invent a Boardy selection
from the presence of Boardy examples in the starter, and do not load a Boardy skill for a Core-only
change. Mirror the completed `CLAUDE.md` to `AGENTS.md` after adding the row.

## 3. Confirm

- Both files exist at repo root, identical.
- `.codex/agents/` contains the nine `ios-*.toml` specialist configurations when Codex is used.
- `Selected Standards Profiles` exists in both twins and contains `core` plus only observed optional
  Profiles.
- The `Module root` row parses as a single token (the scaffolders read it — no extra backticks/prose in the value cell).
- No remaining `{MainScheme}`/`{BuildSystem}`/`{BuildIntegration}`/`{BuildCommand}`/`{TestCommand}`
  placeholders (those break real use).
- Confirm that any Boardy text in the generated starter is conditional and does not select the
  Boardy/VIP Profile by default.
- Tell the user the plugin is wired. The general next step is `/ifl-ios-standards:brain-flow`; use
  `/ifl-ios-standards:enterprise-ios` when governed enterprise concerns apply, or
  `/ifl-ios-standards:boardy-adopt` only for a selected Boardy/VIP greenfield or brownfield path.

> Per `${CLAUDE_PLUGIN_ROOT}/standards/process/docs-organization.md`, project docs/plans/handoffs go
> under `docs/` — the bindings already point there. The `.superpowers`-style scratch dir is not used.
