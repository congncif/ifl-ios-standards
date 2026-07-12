<!-- template-version: 2.4.0 -->

# Portable CLAUDE/AGENTS bindings starter

Drop-in **bindings starter** for an iOS project adopting the reusable iOS standards from the
`ifl-ios-standards` plugin. The standards (rulebook, specs, agents, skills, and source-only
scaffolders) ship **in the plugin** — this template only seeds your repo's project-specific bindings.

## Contents

```
portable-claude/
├── CLAUDE.md            # starter repo-root constitution (project bindings) — fill in {Placeholders}
├── AGENTS.md            # identical twin of CLAUDE.md (universal cross-tool name)
├── SETUP.md             # optional one-time playbook to generate separate binding files
├── VERSION              # template version
├── CHANGELOG.md
├── examples/
│   ├── README.md
│   ├── PROJECT_CONFIG.example.md      # shape reference (separate-file bindings)
│   ├── PROJECT_STRUCTURE.example.md
│   └── QUICK_REF.example.md
└── README.md            # this file
```

There is **no `.ai/brain/` to copy** — the rulebook + specs live in the plugin at
`${CLAUDE_PLUGIN_ROOT}/standards/` and are read on demand by the plugin's skills/agents.

## Adopt into a project

1. **Install and enable the plugin** using the current provider instructions in the plugin's
   `INSTALL.md`. Plugin installation is a machine/provider concern, not a consuming-project binding.

2. **Seed the bindings** — copy the starter to your repo root and fill in the `{Placeholders}`:
   ```bash
   TARGET=/path/to/your-project
   cp CLAUDE.md "$TARGET/CLAUDE.md"
   cp AGENTS.md "$TARGET/AGENTS.md"     # keep the twin identical
   ```
   Edit §3–§5 (identity / structure / build commands). Done — the plugin's agents/skills read these.

3. **Use it**: describe the iOS task. Use `brain-*` skills for pattern-neutral workflow, call
   `/ifl-ios-standards:boardy-vip` for Boardy/VIP work, or route enterprise concerns through
   `/ifl-ios-standards:enterprise-ios`. End-to-end `brain-flow` uses provider-native capabilities in
   co-working or auto mode, executes one approved full plan, and runs exactly one joined final AI
   consistency review over the complete result.

The plugin's `ifl-new-module` and `ifl-new-board` commands are additive, source-only,
build-system-neutral scaffolders. They resolve the module root from the consuming project's bindings
and intentionally emit no build/package files, dependencies, targets, platform values, commands, or
CI. The consuming repository owns all of those values and all executable verification/CI behavior.

## Two ways to hold bindings

- **Inline (default)** — fill §3–§5 of `CLAUDE.md` directly. Simplest; everything in one file.
- **Separate files** — keep `PROJECT_CONFIG.md` + `PROJECT_STRUCTURE.md` under `.claude/project/`
  and have `CLAUDE.md` point at them. Use `SETUP.md` to generate them from project introspection.
  `examples/` shows placeholder-only shapes; it supplies no project identity or tooling values.

## Authority order (downstream project)

User instruction > root `CLAUDE.md` (= `AGENTS.md`, project bindings) > the relevant `ifl-ios-standards`
skill/spec/process docs > existing code.

## Versioning

`template-version` lives in the header of `CLAUDE.md` / `AGENTS.md` / `SETUP.md` / this README.
The plugin standard versions independently (see the plugin's `plugin.json` / `VERSION`).

## Changelog

| Date | template | Change |
|------|----------|--------|
| 2026-05-18 | 1.0.0 | Initial release (copy-`.ai/brain`-into-repo model). |
| 2026-06-09 | 2.0.0 | Rewritten for the plugin model: bindings starter only; standard ships in the `ifl-ios-standards` plugin; docs/handoffs follow docs-organization; package-manager-neutral. |
| 2026-06-16 | 2.1.0 | Generalized wording beyond Boardy-only projects; clarified routing and plugin paths; removed install commands from seeded CLAUDE/AGENTS template. |
| 2026-07-13 | 2.4.0 | Aligned bindings with Standards 1.0: provider-native auto/co-working Brain Flow, scoped local auto-commit, one full-plan final AI review, enterprise routing, UIKit/SwiftUI humble Views, source-only build-neutral scaffolders, repository-owned commands/CI, and placeholder-only examples. |
