---
name: init
description: >-
  Use when setting up a new (or not-yet-wired) iOS project to adopt the Boardy+VIP standard —
  generate the repo's CLAUDE.md + AGENTS.md bindings. Triggers: "init the project", "set up
  CLAUDE.md / AGENTS.md", "wire this repo into the ifl-ios-standards plugin", "bootstrap bindings",
  "onboard this project to Boardy+VIP".
---

# Init project bindings (CLAUDE.md + AGENTS.md)

Generate the consuming repo's `CLAUDE.md` + twin `AGENTS.md` — the bindings the plugin's
agents/skills read for everything project-specific. The standard itself stays in the plugin; this
only seeds the project's own values.

## 1. Seed via the bundled helper

Run the scaffolder. It copies the starter template to the repo root and pre-fills only values backed by
unambiguous repository evidence. Governed or ambiguous bindings remain `{Placeholders}`. The plugin
ships the command in `bin/`; invoke it by name only when the host exports that directory or an installed
shim directory is on shell `PATH`:

```bash
ifl-init --root=.            # add --force to overwrite existing CLAUDE.md/AGENTS.md
# preview first: ifl-init --root=. --dry-run
```

If `ifl-init` isn't on `PATH`, run it from the known plugin root:
`${CLAUDE_PLUGIN_ROOT}/bin/ifl-init --root=.` With separate installation authority,
`scripts/install-codex.sh` can create dynamic shims in `~/.local/bin`; that directory must also be on
the invoking shell's `PATH`.

It refuses to overwrite an existing `CLAUDE.md`/`AGENTS.md` without `--force` — if the repo already
has bindings, stop and ask the user before clobbering.

## 2. Fill the remaining {Placeholders} by introspection

`ifl-init` leaves the values it can't infer as `{Placeholders}`. Detect + fill them, then ask the
user only for what's genuinely ambiguous:

| Placeholder | How to resolve |
|-------------|----------------|
| `{MainScheme}` | `xcodebuild -list` (CocoaPods/SPM) or the `xcodeproj()` rule target name (Bazel). For per-feature Bazel targets, note that rather than a single scheme. |
| `{Simulator}` / `{Destination}` | Resolve from repository governance or an observed native destination inventory. If no supported destination is identified, leave unresolved and ask; do not choose a device default. |
| `{BuildCommand}` / `{TestCommand}` | Copy the canonical commands from repository governance, CI configuration, Makefile, or equivalent owned entry point. If absent or ambiguous, leave unresolved and ask; do not synthesize commands from the package manager. |
| `{ModulePrefix}` | Scan existing module/type names for a common prefix (e.g. `DAD`); empty if none. |
| `{CommitPrefix}` | Look at recent `git log` for a ticket-key convention (e.g. `TCW-1234`); ask the user if unclear. |
| `{Workspace}` (if unresolved) | Resolve the repository's actual generated `*.xcodeproj` or `.xcworkspace`; ask when multiple candidates exist. |

Edit `CLAUDE.md` to fill these, then mirror the exact content into `AGENTS.md` (keep the twins
**identical** — copy `CLAUDE.md` over `AGENTS.md` after editing).

Leave the structural example tokens (`{ModuleName}`, `{Name}`) as-is — they're illustrative in the
table prose, not values to resolve.

## 3. Confirm

- Both files exist at repo root, identical.
- The `Module root` row parses as a single token (the scaffolders read it — no extra backticks/prose in the value cell).
- No remaining `{MainScheme}`/`{BuildCommand}`/`{TestCommand}` placeholders (those break real use).
- Tell the user the plugin is wired; next step is `/ifl-ios-standards:boardy-new-module` for the first module,
  or `/ifl-ios-standards:boardy-adopt` for a brownfield migration plan.

> Per `${CLAUDE_PLUGIN_ROOT}/standards/process/docs-organization.md`, project docs/plans/handoffs go
> under `docs/` — the bindings already point there. The `.superpowers`-style scratch dir is not used.
