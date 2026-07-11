<!-- template-version: 2.2.0 -->

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

1. Domain is pure Swift — no UIKit, networking, persistence, or vendor SDKs.
2. Dependencies point inward: Infrastructure → Business → Domain. Never reverse.
3. Public contract boundary: Consumers depend only on another module's public contract, normally its IO target or documented public API surface. Allowed public imports include IO/contract targets, documented library APIs, shared value-model/contracts, design-system primitives, platform abstractions, and generated schema contracts; test-support imports are allowed only from test targets. Never import internal composition, plugin registry, feature implementation, concrete adapter, mock, or private targets. If no clear contract exists, introduce an IO/facade boundary before adding new cross-module dependencies.
4. Views are humble; UI updates run on the main actor.
5. One state, one writer. Concrete types built only at composition roots.
6. No speculative abstraction, no unrelated changes. Verify with real signals — empty output ≠ success.
7. When in doubt, stop and ask.

### 2.1 Modern large-scale iOS development rules

Apply these rules when translating product work into iOS architecture:

1. **Prefer the platform SDK first.** Maximize Swift, UIKit, SwiftUI-hosting, Foundation, and Apple SDK capabilities; add third-party libraries only when they provide clear product value, and prefer internal libraries built on stable platform APIs.
2. **Optimize for independent change.** Split the app by business capability. Each feature owns a bounded context, public contract, implementation, tests, and build target.
3. **Use interface modules as public contracts.** Export only the minimal stable API needed by consumers. Modules communicate through IO interfaces, never through another module's concrete implementation.
4. **Keep dependency direction explicit.** App-level composition wires concrete modules at the edge. Feature code imports inward-facing contracts only and does not reach sideways across business units.
5. **Put domain meaning at the center.** Model enterprise business rules with domain services, entities, and value objects. Keep DTOs, SDK objects, persistence records, and transport details in adapters.
6. **Preserve clean layering.** Domain is pure Swift. Business Application coordinates use cases and presentation workflow. Infrastructure/UI contains views, data access, SDK integration, and other humble adapters.
7. **Keep business flow unidirectional.** UI forwards intent into an interactor/use case, presentation maps output into view models or render state, and the view only renders state and emits user events.
8. **Build composable business capabilities.** Expose small workflow or service contracts such as `start`, `handle`, `activate`, `interact`, `execute`, or `observe` APIs. Communicate through input/output/command/action events instead of concrete screens.
9. **Centralize orchestration and registration.** App/plugin composition roots register factories, services, and feature entry points; runtime orchestration resolves and invokes capabilities through IO interfaces.
10. **Hide external systems behind adapters.** Networking, persistence, analytics, experiments, URL opening, and vendor SDKs stay in infrastructure and are injected behind protocols so they can be tested or replaced.
11. **Design for build scalability.** Prefer small independently compilable targets. Avoid broad shared modules that become dumping grounds. Introduce shared code only after real duplication or multiple consumers.
12. **Verify at the module boundary.** Add or update focused unit tests for domain/use-case behavior, compile the changed module, and run integration/UI checks only when composition wiring or user flow changes.
13. **Evolve incrementally.** Migrate legacy code by adding seams and contracts first, then moving behavior. Do not rewrite working flows or create platform abstractions without concrete pressure.

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

Checkpoint economics (TDD tiers, review/gate ownership, evidence reuse): see
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

- Before starting multi-step work, map independently valid semantic checkpoints, internal causal work
  slices, reviewer coverage, and one owner for each verification obligation.
- Convert every request into a concrete, testable success criterion before touching files.
- For ambiguous requests, state your interpretation as a success criterion and confirm before proceeding.
- Strong upfront criteria reduce rewrites more than any amount of careful coding.

### Project operations
- Plan/phase approval and auto mode grant no Git authority. Record object-scoped commit authority for the
  exact repository, semantic checkpoint, candidate closure/fingerprint, and parent chain. Branch, push,
  PR, tag, release, and history rewrite require separate authority. Stage by explicit reviewed paths.
- Commit message convention: `{CommitPrefix}` *(e.g. a ticket-key prefix, if your team requires one)*.
- Project docs/plans/handoffs live in-repo under `docs/` per
  `${CLAUDE_PLUGIN_ROOT}/standards/process/docs-organization.md` (working docs →
  `docs/02-working-docs/…`). The multi-agent pipeline workspace
  (`docs/02-working-docs/work-items/`) is optional — only the `ios-orchestrator` flow uses it.
- New source files carry the project's authorship-trace header convention.

> **Optional separate binding files.** Instead of filling §3–§5 inline, you may keep
> `PROJECT_CONFIG.md` + `PROJECT_STRUCTURE.md` under `.claude/project/` and point here at them.
> See `${CLAUDE_PLUGIN_ROOT}/standards/templates/portable-claude/SETUP.md` for that one-time flow.

---

*Keep this file short. The reusable standards are the plugin's job; this file is only your
project's bindings + boundaries. Update §3–§5 when project values change.*
