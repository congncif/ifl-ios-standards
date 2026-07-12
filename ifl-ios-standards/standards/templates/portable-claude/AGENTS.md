<!-- template-version: 2.4.0 -->

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
- **Brain Flow** (end-to-end delivery): `/ifl-ios-standards:brain-flow` in co-working or auto mode.
  It uses the host provider's native task/thread, subagent, tool, and approval capabilities.
- **Enterprise iOS router**: `/ifl-ios-standards:enterprise-ios`. Route only the applicable chapters
  among its ten concerns: Swift 6 concurrency, SwiftUI production, data lifecycle, mobile security,
  privacy/compliance, accessibility/global readiness, observability/operability, modern testing,
  performance/resilience, and supply-chain/legal.
- **Agents** (multi-step delivery): `ios-orchestrator` (start here for broad implementation work),
  `ios-planner`, `ios-researcher`, `ios-architect`, `ios-coder`, `ios-tester`, `ios-reviewer`,
  `ios-review-triage`, `ios-doc-scribe` — appear in `/agents`.
- **Source scaffolders on PATH** when the plugin is enabled: `ifl-new-module`, `ifl-new-board`.
  They emit additive, build-system-neutral source skeletons only. They resolve the repository-owned
  module root from these bindings and never invent build files, targets, dependencies, platform
  versions, destinations, commands, or CI configuration.

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
4. UIKit and SwiftUI Views are humble. The Presenter prepares immutable, display-ready semantic
   state. A UIKit controller renders it through a display port; a SwiftUI View observes an equivalent
   MainActor presentation store and keeps `@State` UX-only. Views may select a Presenter-encoded
   presentation phase and own small interaction/geometry state, but never format raw/domain values,
   derive product or analytics meaning, choose business/navigation policy, perform business I/O, or
   construct dependencies. Identical domain input yields equivalent semantic display state in both.
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
| Module root | `{ModuleRoot}` |
| Build / package system | `{BuildSystem}` |
| Build / package integration | `{BuildIntegration}` |
| Public contract target / sources | `{InterfaceTargetPattern}` / `{InterfaceSourceGlob}` |
| Implementation target / sources | `{ImplementationTargetPattern}` / `{ImplementationSourceGlob}` |
| Test target / sources | `{TestTargetPattern}` / `{TestSourceGlob}` |

Fill **Module root** with one repository-relative path token and no explanatory prose; the source
scaffolders parse that binding from root `CLAUDE.md`, then `AGENTS.md`, and fail instead of guessing.
An explicit `--module-root` may override it. New Boardy modules preserve the public IO / internal
Plugins source split, but the consuming repository must add those sources to its own build/package
configuration and define all labels, dependencies, platform values, resources, targets, and tests.

---

## 5. Build / test / verify

```bash
{BuildCommand}
{TestCommand}
```

These commands come from this repository's governance; the plugin and its scaffolders do not supply
or replace them. CI and release automation remain owned by the consuming repository/DevOps boundary.
Plan-scale execution and the one final AI review: see
`${CLAUDE_PLUGIN_ROOT}/standards/process/lean-verification.md`.

---

## 6. Operating discipline

### Provider-native Brain-Flow

- Use `/ifl-ios-standards:brain-flow` through the host provider's native task/thread, subagent, tool,
  and approval capabilities.
- Explicit `auto` / `full auto` selects auto mode; explicit `co-working` / `review with me` selects
  co-working. Otherwise use the repository's configured default, falling back to co-working.
- In co-working mode, obtain user approval for requirements/Definition of Done and for the complete
  plan. In auto mode, record AI decisions at those two gates and continue without routine questions;
  escalate only material ambiguity, a real blocker, an external hold, or missing authority.
- Keep one approved full-plan checklist and provider-native task state. Do not add provider profiles,
  verifier/lint/smoke scripts, progress schemas, receipts, manifests, fingerprints, evidence ledgers,
  or a provider-independent workflow engine.
- Complete every workstream and the last planned mutation before exactly one joined final AI
  consistency review over the complete branch diff and final repository state. Parallel specialist
  lanes are part of that one event. Collect findings first, apply accepted in-scope findings in one
  corrective batch, and do not schedule routine per-workstream, per-finding, or confirmation re-review.
- Use repository-owned code tests for executable behavior where risk warrants them. Do not run builds
  or tests for template/documentation-only changes merely to manufacture evidence, and do not
  duplicate repository CI.

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

- Before starting multi-step work, create one complete plan with dependency-ordered workstreams,
  shared-writer ownership, semantic commit tasks, and one final AI review.
- Convert every request into a concrete, testable success criterion before touching files.
- For ambiguous requests, state your interpretation as a success criterion and confirm before proceeding.
- Strong upfront criteria reduce rewrites more than any amount of careful coding.

### Project operations
- Follow project governance for Git authority. An explicit scoped auto-commit instruction authorizes
  local stage+commit for each completed semantic task in its approved plan, repository, worktree, and
  branch without another prompt. It never authorizes branch creation/switch, amend/history rewrite,
  push, PR, merge, tag, publish, install, release, or another external effect. Without that grant,
  obtain per-operation authority. Stage only intended task paths.
- Commit message convention: `{CommitPrefix}` *(resolve from project governance; do not invent one)*.
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
