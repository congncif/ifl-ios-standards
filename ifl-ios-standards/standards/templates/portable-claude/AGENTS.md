<!-- template-version: 2.1.0 -->

# CLAUDE.md — {ProjectName} Project Constitution (starter)

> **Drop-in starter.** Copy this file to your repo root as `CLAUDE.md` (and a twin `AGENTS.md`),
> then fill in the `{Placeholders}`. It holds only **your project's bindings** — the reusable
> iOS standards, skills, agents, and scaffolders ship in the `ifl-ios-standards` plugin.
> **Twin file**: keep `CLAUDE.md` and `AGENTS.md` identical (`CLAUDE.md` for Claude tooling,
> `AGENTS.md` the universal cross-tool name).

---

## 0. The standards live in the plugin

The `ifl-ios-standards` plugin provides the reusable iOS engineering standard — architecture
rulebooks, specs, naming/protocol tables, review checklists, process standards, scaffolders,
skills, and agents. This template only records how those standards bind to **this repo**.
The standards apply to both Boardy and non-Boardy iOS projects; use the Boardy-specific
skills only when the target project actually uses Boardy/VIP.

- **Start with the router skill when the work is Boardy/VIP-related**:
  `/ifl-ios-standards:boardy-vip`.
- **Task skills**: `/ifl-ios-standards:boardy-new-module`, `:boardy-new-board`, `:boardy-io-interface`,
  `:boardy-communication`, `:boardy-service-layer`, `:boardy-plugin-composition`, `:boardy-testing`,
  `:boardy-review`, `:boardy-refactor`, `:boardy-troubleshoot`, `:boardy-adopt`.
  Call one explicitly when the task matches it; otherwise follow this constitution and the relevant
  process/spec files in the plugin.
- **Agents** (multi-step delivery): `ios-orchestrator` (start here for broad implementation work),
  `ios-planner`, `ios-researcher`, `ios-architect`, `ios-coder`, `ios-tester`, `ios-reviewer`,
  `ios-review-triage`, `ios-doc-scribe` — appear in `/agents`.
- **Scaffolders on PATH** when the plugin is enabled: `ifl-new-module`, `ifl-new-board`.

The plugin's agents/skills read **this file** for everything project-specific below.

---

## 1. Authority order

1. User's explicit current instruction.
2. This constitution (project bindings, §3–§5).
3. Relevant `ifl-ios-standards` plugin skill/spec/process docs.
4. Existing code patterns in the target module.

---

## 2. Non-negotiable boundaries

Full architecture rules live in `${CLAUDE_PLUGIN_ROOT}/standards/brain/rulebook/` and the task-specific specs in `${CLAUDE_PLUGIN_ROOT}/standards/specs/`. The hard floor:

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

New Boardy modules emit the two-target split via `/ifl-ios-standards:boardy-new-module`. Keep the
IO/Plugins split whenever this project's standard uses it.

---

## 5. Build / test / verify

```bash
{BuildCommand}      # e.g. bazel build //Features/{ModuleName}:{ModuleName}Plugins  — or xcodebuild …
{TestCommand}       # e.g. bazel test  //Features/{ModuleName}:{ModuleName}-Tests
```

Verification cadence (TDD tiers + checkpoint levels): see
`${CLAUDE_PLUGIN_ROOT}/standards/process/lean-verification.md`.

---

## 6. Operating discipline

### Core directives

#### 1. Think Before Coding

- State assumptions explicitly before writing any code.
- Surface ambiguity and tradeoffs — don't silently pick one.
- If a simpler path exists, suggest it first and wait for confirmation.
- When the intent is unclear, ask rather than guess.

#### 2. Simplicity First

- Write only the code the task requires — no speculative features, abstractions, or configuration.
- Don't add error handling, fallbacks, or validation for scenarios that can't happen in this codebase.
- Prefer three similar lines over a premature abstraction.
- If removing a line wouldn't break anything and doesn't carry non-obvious intent, remove it.

#### 3. Surgical Changes

- Edit only the lines necessary to satisfy the task.
- Don't refactor, rename, or clean up code adjacent to the change unless it is directly breaking something.
- Preserve existing local style (spacing, naming, comment style) in every file you touch.
- Remove only code you introduced that is now orphaned — leave everything else intact.

#### 4. Goal-Driven Execution

- Before starting multi-step work, write a short plan with one verification step per stage.
- Convert every request into a concrete, testable success criterion before touching files.
- For ambiguous requests, state your interpretation as a success criterion and confirm before proceeding.
- Strong upfront criteria reduce rewrites more than any amount of careful coding.

### Project operations
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

*Keep this file short. The reusable standards are the plugin's job; this file is only your
project's bindings + boundaries. Update §3–§5 when project values change.*
