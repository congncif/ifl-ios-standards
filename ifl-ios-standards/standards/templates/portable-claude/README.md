<!-- template-version: 2.4.0 -->

# Portable CLAUDE/AGENTS bindings starter

Drop-in **bindings starter** for an iOS project adopting the reusable iOS standards from the
`ifl-ios-standards` plugin. The standards (rulebook, specs, agents, skills, scaffolders) ship
**in the plugin** — this template only seeds your repo's project-specific bindings.

## Contents

```
portable-claude/
├── CLAUDE.md            # starter repo-root constitution (project bindings) — fill in {Placeholders}
├── AGENTS.md            # identical twin of CLAUDE.md (universal cross-tool name)
├── SETUP.md             # optional one-time playbook to generate separate binding files
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

1. **Install the plugin** (once per machine):
   ```bash
   # Claude Code
   claude plugin marketplace add congncif/ifl-ios-standards
   claude plugin install          ifl-ios-standards@ifl-ios-standards
   # Codex
   codex plugin marketplace add   congncif/ifl-ios-standards
   codex plugin add               ifl-ios-standards@ifl-ios-standards
   ```

2. **Seed the bindings** — copy the starter to your repo root and fill in the `{Placeholders}`:
   ```bash
   TARGET=/path/to/your-project
   cp CLAUDE.md "$TARGET/CLAUDE.md"
   cp AGENTS.md "$TARGET/AGENTS.md"     # keep the twin identical
   ```
   Edit §3–§5 (identity / structure / build commands). Done — the plugin's agents/skills read these.

3. **Use it**: describe the iOS task. Use `brain-*` skills for pattern-neutral workflow, or call `/ifl-ios-standards:boardy-vip` for Boardy/VIP work. End-to-end `brain-flow` uses the host provider's native task/thread and subagent capabilities, executes one approved plan, and runs one final AI consistency review.

## Two ways to hold bindings

- **Inline (default)** — fill §3–§5 of `CLAUDE.md` directly. Simplest; everything in one file.
- **Separate files** — keep `PROJECT_CONFIG.md` + `PROJECT_STRUCTURE.md` under `.claude/project/`
  and have `CLAUDE.md` point at them. Use `SETUP.md` to generate them from project introspection.
  `examples/` shows the shape of those separate files.

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
| 2026-07-13 | 2.4.0 | Added provider-native plan-scale delivery with one final AI consistency review. |
