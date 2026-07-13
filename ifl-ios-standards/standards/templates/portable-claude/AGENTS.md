<!-- template-version: 2.5.0 -->

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
- **Source scaffolders in plugin `bin/`**: `ifl-new-module`, `ifl-new-board`. Invoke them by command
  name only when the runtime exports plugin `bin/` or an installed shim directory is on shell `PATH`.
  They emit additive, build-system-neutral source skeletons only. They resolve the repository-owned
  module root from these bindings and never invent build files, targets, dependencies, platform
  versions, destinations, commands, or CI configuration.

The plugin's agents/skills read **this file** for everything project-specific below.

---

## 1. Authority order

1. User's explicit current instruction.
2. This constitution (project bindings, §3–§5).
3. Active Canon Rules and Profiles plus accepted ADRs shipped by `ifl-ios-standards` (normative
   reusable authority).
4. Relevant `ifl-ios-standards` skill/spec/process docs (derived operating guidance; they may not
   override Canon or an accepted ADR).
5. Existing code patterns in the target module.

This order resolves the current objective and project bindings; it does not rewrite Canon. User and
project instructions may select scope or strengthen constraints. A requested deviation from an
applicable Canon Rule must be recorded through the governed transitional, exception, or non-conforming
path and cannot be hidden inside a project instruction or conformance claim.

---

## 2. Non-negotiable boundaries

The selected Canon Rules are authoritative. Brain/rulebook and task-specific specs provide derived
guidance. These prompts summarize common Rules and do not create a separate hard floor:

1. `CORE-DEP-001`: Domain is pure Swift — no UI, orchestration, networking, persistence, or vendor SDKs.
2. `CORE-DEP-002`/`003`: dependencies point inward from adapters → Application → Domain.
3. `CORE-API-001`/`CORE-COMP-001`: consumers depend only on another module's public contract, normally its IO target or documented public API surface. Allowed public imports include IO/contract targets, documented library APIs, shared value-model/contracts, design-system primitives, platform abstractions, and generated schema contracts; test-support imports are allowed only from test targets. Never import internal composition, plugin registry, feature implementation, concrete adapter, mock, or private targets. If no clear contract exists, introduce an IO/facade boundary before adding new cross-module dependencies.
4. `UI-HUMBLE-001`…`004`: UIKit and SwiftUI Views are humble. The Presenter prepares immutable, display-ready semantic
   state. A UIKit controller renders it through a display port; a SwiftUI View observes an equivalent
   MainActor presentation store and keeps `@State` UX-only. Views may select a Presenter-encoded
   presentation phase and own small interaction/geometry state, but never format raw/domain values,
   derive product or analytics meaning, choose business/navigation policy, perform business I/O, or
   construct dependencies. Identical domain input yields equivalent semantic display state in both.
5. Apply the selected state/ownership Rules and `CORE-COMP-001`: one state has one writer and concrete types are built only at composition roots.
6. No speculative abstraction or unrelated changes. Executable changes use the smallest risk-relevant
   observed signal; documentation-only changes have no build/test gate.
7. Do not guess a material unknown. Stop and ask when a choice would change scope, architecture,
   public contracts, security/compliance posture, organization policy, or required authority.
   Otherwise make the smallest reversible decision and continue in eligible auto mode.

### 2.1 Modern large-scale iOS development rules

Apply these rules when translating product work into iOS architecture:

1. **Prefer the platform SDK first.** Maximize Swift, UIKit, SwiftUI-hosting, Foundation, and Apple SDK capabilities; add third-party libraries only when they provide clear product value, and prefer internal libraries built on stable platform APIs.
2. **Optimize for independent change.** Split the app by business capability. Each feature owns a bounded context, public contract, implementation, tests, and build target.
3. **Use interface modules as public contracts.** Export only the minimal stable API needed by consumers. Modules communicate through IO interfaces, never through another module's concrete implementation.
4. **Keep dependency direction explicit.** App-level composition wires concrete modules at the edge. Feature code imports inward-facing contracts only and does not reach sideways across business units.
5. **Put domain meaning at the center.** Model enterprise business rules with domain services, entities, and value objects. Keep DTOs, SDK objects, persistence records, and transport details in adapters.
6. **Preserve clean layering.** Domain is pure Swift. Framework-neutral Application owns business policy and use cases. Infrastructure and outward presentation adapters contain views, data access, SDK integration, and UI workflow coordination.
7. **Keep business flow unidirectional.** UI forwards intent into the selected outward presentation adapter, which invokes Application-owned use cases or ports; a Presenter or equivalent maps results into render state, and the View only renders state and emits user events. When the optional Boardy/VIP Profile is selected, its Interactor coordinates presentation intent and use-case invocation but contains no domain or business rules.
8. **Build composable business capabilities.** Expose small workflow or service contracts such as `start`, `handle`, `activate`, `interact`, `execute`, or `observe` APIs. Communicate through input/output/command/action events instead of concrete screens.
9. **Centralize orchestration and registration.** App/plugin composition roots register factories, services, and feature entry points; runtime orchestration resolves and invokes capabilities through IO interfaces.
10. **Hide external systems behind adapters.** Networking, persistence, analytics, experiments, URL opening, and vendor SDKs stay in infrastructure and are injected behind protocols so they can be tested or replaced.
11. **Design for build scalability.** Prefer small independently compilable targets. Avoid broad shared modules that become dumping grounds. Introduce shared code only after real duplication or multiple consumers.
12. **Verify at the module boundary.** Use the smallest repository-owned executable signal warranted by changed behavior and risk. Add or update focused domain/use-case tests when that risk warrants them; compile the changed module only when API, build-graph, or wiring risk requires it; use integration/UI checks only for behavior that crosses those boundaries.
13. **Evolve incrementally.** Migrate legacy code by adding seams and contracts first, then moving behavior. Do not rewrite working flows or create platform abstractions without concrete pressure.

---

## 3. Identity and project authority

| Key | Value |
|-----|-------|
| Project | `{ProjectName}` |
| Xcode project / workspace | `{Workspace}` |
| Main scheme | `{MainScheme}` |
| Base branch | `{BaseBranch}` |
| Git remote | `{GitRemote}` → `{GitRemoteURL}` |
| Simulator / destination | `{Simulator}` / `{Destination}` |
| Module prefix | `{ModulePrefix}` *(empty if none)* |

| Operating binding | Value |
|-------------------|-------|
| Default Brain-Flow mode | `{BrainFlowMode}` (`co-working` or `auto`) |
| Local stage+commit authority | `{CommitAuthority}` |
| Scoped auto-commit scope | `{AutoCommitScope}` |
| Branch / amend / rewrite authority | `{LocalGitAuthority}` |
| Push / PR / merge authority | `{RemoteGitAuthority}` |
| Tag / publish / install / release authority | `{ReleaseEffectAuthority}` |
| Deployment/platform policy owner | `{DeploymentPolicyOwner}` |
| Privacy/security policy owner | `{PrivacySecurityOwner}` |
| Accessibility policy owner | `{AccessibilityOwner}` |
| Observability/operability policy owner | `{ObservabilityOwner}` |
| Data-retention policy owner | `{DataRetentionOwner}` |
| Release sign-off owner | `{ReleaseSignoffOwner}` |
| Resume / handoff location | `{ResumeHandoffLocation}` |
| Final finding disposition authority | `{FinalDispositionAuthority}` |

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
Full-auto eligibility, authority, recovery/resume, candidate identity, disposition, and terminal
boundary: `${CLAUDE_PLUGIN_ROOT}/standards/process/full-auto-operating-model.md`.

---

## 6. Operating discipline

### Provider-native Brain-Flow

- Use `/ifl-ios-standards:brain-flow` through the host provider's native task/thread, subagent, tool,
  and approval capabilities.
- Explicit `auto` / `full auto` selects auto mode; explicit `co-working` / `review with me` selects
  co-working. Otherwise use the repository's configured default, falling back to co-working.
- In co-working mode, the human participates in requirements, product/architecture/policy decisions,
  the complete plan, and final finding dispositions. In auto mode, independent AI owners decide the
  Requirement and Plan gates; once eligibility and authority preflight pass, continue without routine
  wait/confirm/ask pauses.
- Interrupt eligible auto mode only for a material blocker: a decision that changes approved scope,
  architecture, public contract, security/compliance posture, or organization policy; an external
  hold; or missing authority/tool access that bounded recovery cannot resolve. Record provider-native
  resume state at `{ResumeHandoffLocation}` before handing off.
- Keep one approved full-plan checklist and provider-native task state. Do not add provider profiles,
  verifier/lint/smoke scripts, progress schemas, receipts, manifests, fingerprints, evidence ledgers,
  or a provider-independent workflow engine.
- Complete every workstream and its authorized semantic commit, freeze exact baseline/HEAD SHAs and
  included/excluded paths, then run exactly one joined final AI consistency review over that candidate. Parallel specialist
  lanes are part of that one event. Collect findings first, apply accepted in-scope findings in one
  corrective batch under `{FinalDispositionAuthority}`, and do not schedule routine per-workstream,
  per-finding, or confirmation re-review.
- Use repository-owned code tests for executable behavior where risk warrants them. Do not run builds
  or tests for template/documentation-only changes merely to manufacture evidence, and do not
  duplicate repository CI.
- Full-auto Brain Flow ends at engineering completion and release readiness. It never implies branch
  integration, push, PR, merge, tag, publish, install, release, or production rollout; each remains a
  separately bound operation even when local stage+commit is authorized.

### Core directives

#### 1. Think Before Coding

- State assumptions explicitly before writing any code.
- Surface ambiguity and tradeoffs — don't silently pick one.
- Prefer the simplest conforming path. In co-working mode, involve the human in material choices; in
  eligible auto mode, record bounded choices and continue without a routine confirmation pause.
- Ask only when unclear intent is a material blocker under the Brain-Flow rule above; do not guess
  missing authority or organization policy.

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
- For non-material ambiguity, state the bounded interpretation as a success criterion and continue in
  eligible auto mode. Material ambiguity requires the bound human/organization decision owner.
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
