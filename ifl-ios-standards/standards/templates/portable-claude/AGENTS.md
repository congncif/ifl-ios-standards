<!-- template-version: 2.0.0 -->

# CLAUDE.md — {ProjectName} Project Constitution (starter)

> **Drop-in starter.** Copy this file to your repo root as `CLAUDE.md` (and a twin `AGENTS.md`),
> then fill in the `{Placeholders}`. It holds only **your project's bindings** — the Boardy+VIP
> standard itself ships in the `ifl-ios-standards` plugin.
> **Twin file**: keep `CLAUDE.md` and `AGENTS.md` identical (`CLAUDE.md` for Claude tooling,
> `AGENTS.md` the universal cross-tool name).

---

## 0. The standard lives in the plugin

The Boardy+VIP architecture standard — rulebook, specs, the 14 rules, naming/protocol tables,
review checklist, process standards, scaffolders — is provided by the **`ifl-ios-standards`**
plugin, not by files in this repo. Use it:

- **Router skill** (read first for any Boardy+VIP task): `/ifl-ios-standards:boardy-vip`
- **Task skills**: `/ifl-ios-standards:boardy-new-module`, `:boardy-new-board`, `:boardy-io-interface`,
  `:boardy-communication`, `:boardy-service-layer`, `:boardy-plugin-composition`, `:boardy-testing`, `:boardy-review`, `:boardy-refactor`,
  `:boardy-troubleshoot`, `:boardy-adopt` — auto-fire by task context, or call explicitly.
- **Agents** (multi-step delivery): `ios-orchestrator` (start here), `ios-planner`,
  `ios-researcher`, `ios-architect`, `ios-coder`, `ios-tester`, `ios-reviewer`,
  `ios-review-triage`, `ios-doc-scribe` — appear in `/agents`.
- **Scaffolders on PATH** when the plugin is enabled: `ifl-new-module`, `ifl-new-board`.

Install once if missing:
```bash
# Claude Code
claude plugin marketplace add congncif/ifl-ios-standards && claude plugin install ifl-ios-standards@ifl-ios-standards
# Codex
codex plugin marketplace add  congncif/ifl-ios-standards && codex plugin add     ifl-ios-standards@ifl-ios-standards
```

The plugin's agents/skills read **this file** for everything project-specific below.

---

## 1. Authority order

1. User's explicit current instruction.
2. This constitution (project bindings, §3–§5).
3. The `ifl-ios-standards` plugin standard (router skill → rulebook/specs).
4. Existing code patterns in the target module.

---

## 2. Non-negotiable boundaries

Full 14 rules: `/ifl-ios-standards:boardy-vip` §2. The hard floor:

1. Domain is pure Swift — no UIKit, Boardy, networking, or vendor SDKs.
2. Dependencies point inward: Infrastructure → Business → Domain. Never reverse.
3. IO targets are `public` contracts; consumers import IO only, never another module's `{Name}Plugins`.
4. Views are humble; UI updates run on the main actor.
5. One state, one writer. Concrete types built only at composition roots.
6. No speculative abstraction, no unrelated changes. Verify with real signals — empty output ≠ success.
7. When in doubt, stop and ask.

---

## 3. Identity

| Key | Value |
|-----|-------|
| Project | `{ProjectName}` |
| Xcode project / workspace | `{Workspace}` |
| Main scheme | `{MainScheme}` |
| Base branch | `{BaseBranch}` |
| Git remote | `{GitRemote}` → `{GitRemoteURL}` |
| Simulator / destination | `{Simulator}` / `{Destination}` |
| Module prefix | `{ModulePrefix}` *(empty if none)* |

---

## 4. Structure & tooling

| Concern | Value |
|---------|-------|
| Dependency manager | `{DependencyManager}` |
| Module root | `{ModuleRoot}` |
| Module dependency file | `{ModuleDependencyFile}` |
| Interface target | `{ModuleName}` — glob `IO/**/*.swift` |
| Implementation target | `{ModuleName}Plugins` — glob `Sources/**/*.swift` |
| Test target | `{ModuleName}-Tests` — glob `Tests/**/*.swift` |

> Dependency manager: CocoaPods / Bazel + rules_xcodeproj / SPM. Module root: `Features` for Bazel,
> `submodules`/`Modules` for CocoaPods, `Packages` for SPM. Module dependency file: `BUILD.bazel` or
> `*.podspec`. Keep the **Module root** value cell a single bare token (no prose/extra backticks) —
> the scaffolders parse it.

New modules emit the two-target split via `/ifl-ios-standards:boardy-new-module`. Keep the IO/Plugins
split — it's the standard's whole point.

---

## 5. Build / test / verify

```bash
{BuildCommand}      # e.g. bazel build //Features/{ModuleName}:{ModuleName}Plugins  — or xcodebuild …
{TestCommand}       # e.g. bazel test  //Features/{ModuleName}:{ModuleName}-Tests
```

Verification cadence (TDD tiers + checkpoint levels): `/ifl-ios-standards:boardy-vip` →
`${CLAUDE_PLUGIN_ROOT}/standards/process/lean-verification.md`.

---

## 6. Operating discipline

- Commit/push only after explicit user approval for the current phase. Stage by explicit reviewed paths.
- Commit message convention: `{CommitPrefix}` *(e.g. a ticket-key prefix, if your team requires one)*.
- Project docs/plans/handoffs live in-repo under `docs/` per
  `${CLAUDE_PLUGIN_ROOT}/standards/process/docs-organization.md` (working docs →
  `docs/02-working-docs/…`). The multi-agent pipeline workspace
  (`docs/02-working-docs/handoffs/`) is optional — only the `ios-orchestrator` flow uses it.
- New source files carry the project's authorship-trace header convention.

> **Optional separate binding files.** Instead of filling §3–§5 inline, you may keep
> `PROJECT_CONFIG.md` + `PROJECT_STRUCTURE.md` under `.claude/project/` and point here at them.
> See `${CLAUDE_PLUGIN_ROOT}/standards/templates/portable-claude/SETUP.md` for that one-time flow.

---

*Keep this file short. The architecture standard is the plugin's job; this file is only your
project's bindings + boundaries. Update §3–§5 when project values change.*
