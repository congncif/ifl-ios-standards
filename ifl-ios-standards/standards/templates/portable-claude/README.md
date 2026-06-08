<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->
<!-- template-version: 1.0.0 -->

# Portable CLAUDE/AGENTS Template

Drop-in agentic baseline for a new modular iOS project.

> **Single source of truth**: brain files live at `<repo-root>/.ai/brain/` of THIS repository. The template references them by relative path during install — never duplicate them here.

## Contents

```
portable-claude/
├── AGENTS.md            # per-session constitution (universal cross-tool name)
├── CLAUDE.md            # identical copy of AGENTS.md (Claude tooling discovery)
├── SETUP.md             # one-time setup playbook (installs to .ai/SETUP.md downstream)
├── examples/
│   ├── README.md
│   ├── PROJECT_CONFIG.example.md
│   ├── PROJECT_STRUCTURE.example.md
│   └── QUICK_REF.example.md
└── README.md            # this file
```

Brain files (NOT in this folder — single source):

```
<repo-root>/.ai/brain/
├── QUICK_REF.md            # routing index + hard rules (~130 lines, loaded every task)
├── rulebook/               # 23 chapter files (load one on demand, ~30-90 lines each)
│   ├── 01-philosophy.md
│   ├── 02-architectural-principles.md
│   ├── ... (20 numbered chapters)
│   ├── A-module-skeleton.md
│   ├── B-authoring-conventions.md
│   └── C-verification-commands.md
└── patterns/               # optional pattern guides (load only if adopted)
    └── VIP.md              # recommended default presentation pattern (with or without Boardy)
```

## File responsibilities

| File (downstream path) | Loaded when | Purpose |
|------|-------------|---------|
| `AGENTS.md` + `CLAUDE.md` at repo root | every AI session | Twin per-session constitution: authority order, load order, hard rules, precondition check. Identical content. |
| `.ai/SETUP.md` | once, on first bootstrap | Step-by-step playbook the AI follows to generate `PROJECT_CONFIG.md` / `PROJECT_STRUCTURE.md` / optional `QUICK_REF.md`. Not loaded per session. |
| `.ai/brain/QUICK_REF.md` | every coding task (on demand) | Operating loop, 10 hard rules, routing table into chapter files. |
| `.ai/brain/rulebook/*.md` | one chapter at a time, on demand | Generic engineering rules split per topic (20 numbered chapters + 3 appendices). |
| `.ai/brain/patterns/*.md` | only if the project adopted that pattern | Optional pattern guides. `VIP.md` is the recommended default (with or without Boardy). |
| `<BindingsRoot>/PROJECT_CONFIG.md` + `PROJECT_STRUCTURE.md` | on demand per task | Project-specific values. Default `<BindingsRoot>` is `.ai/rules/`. |

## Install into a new project

From this repository's root:

```bash
TARGET=/path/to/new-project

# 1. Twin constitution at repo root (both names so Claude + Codex + Cursor all discover it)
cp .ai/templates/portable-claude/AGENTS.md "$TARGET/AGENTS.md"
cp .ai/templates/portable-claude/CLAUDE.md "$TARGET/CLAUDE.md"

# 2. One-time setup playbook in .ai/ namespace (NOT repo root)
mkdir -p "$TARGET/.ai"
cp .ai/templates/portable-claude/SETUP.md "$TARGET/.ai/SETUP.md"

# 3. Single-source brain folder
cp -R .ai/brain "$TARGET/.ai/brain"

# 4. (Optional) Reference examples — copy if you want them in the new repo
# cp -R .ai/templates/portable-claude/examples "$TARGET/.ai/examples"
```

Then, in the new project, instruct the AI:

> "Setup project per `.ai/SETUP.md`."

The AI will:
1. Ask for project identity, build env, and architecture choices (one structured batch).
2. Introspect the repo (`xcodebuild -list`, module discovery, git remote).
3. Generate `PROJECT_CONFIG.md` and `PROJECT_STRUCTURE.md` under the chosen bindings root (default `.ai/rules/`).
4. Optionally generate `QUICK_REF.md` if the project needs spec routing.
5. Run the canonical build to verify the bindings against real signal.
6. Report files created + any TBDs + verification result.

After setup, `.ai/SETUP.md` may be deleted (or kept as historical record — it is not re-read in normal sessions).

## Examples

`examples/` contains generated bindings from a real Boardy+VIP project. Use them as shape references for SETUP.md generation. See `examples/README.md` for details.

## Maintenance (this repo)

- **Brain files** — edit `.ai/brain/` only. Bump `brain-version:` header on meaningful changes. Downstream projects re-sync by re-running the copy command in the install section.
- **`AGENTS.md` / `CLAUDE.md` / `SETUP.md`** — edit the copies inside this template folder, not downstream copies. Bump `template-version:` header.
- **Examples** — refresh occasionally from the live source files (see `examples/README.md`).

## Versioning

- `brain-version` lives in the header of each `.ai/brain/*` file.
- `template-version` lives in the header of `AGENTS.md` / `CLAUDE.md` / `SETUP.md` / this README.
- They are independent — brain may bump without the template bumping and vice versa.

## Changelog

| Date | brain | template | Change |
|------|-------|----------|--------|
| 2026-05-18 | 1.0.0 | 1.0.0 | Initial release. |

## Authority order (downstream project)

User instruction > root `AGENTS.md` (= `CLAUDE.md`) > project bindings (`PROJECT_CONFIG.md` / `PROJECT_STRUCTURE.md` / optional `QUICK_REF.md`) > brain `AGENTS.md` > brain rulebook > existing code.

`.ai/SETUP.md` is a procedure, not an authority — it acts once and exits.
