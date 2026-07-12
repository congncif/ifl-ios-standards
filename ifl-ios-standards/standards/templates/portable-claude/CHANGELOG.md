<!-- template-version: 2.4.0 -->

# Changelog — `portable-claude` template

The portable-claude template is a **bindings starter** for a project adopting the reusable iOS
standards from the `ifl-ios-standards` plugin. It seeds the repo's `CLAUDE.md`/`AGENTS.md` bindings;
the standards themselves (rulebook, specs, agents, skills) ship in the plugin.

This template follows [SemVer](https://semver.org/), versioned independently of the plugin standard.

- **Patch (x.y.Z)** — typo, link fix, README clarification with no semantic change.
- **Minor (x.Y.0)** — new agent, new rule file, new setup step. Adopters confirm at next semi-annual review.
- **Major (X.0.0)** — removed/renamed agent, breaking change to setup contract, brain major bump. Adopters re-audit + re-run setup.

## [2.4.0] — 2026-07-13

Aligned portable Claude/Codex project bindings with the Standards 1.0 candidate.

- Uses host-native task/thread and subagent capabilities in auto or co-working mode without a custom
  Kernel or provider-independent workflow state.
- Executes one approved full plan continuously and runs exactly one joined final AI consistency review.
- Defines scoped local auto-commit authority without extending it to other Git/external operations.
- Routes enterprise work through the ten `enterprise-ios` chapters.
- Carries the shared UIKit/SwiftUI humble-View contract.
- Describes module/board scaffolders as source-only, additive, and build-system-neutral; module roots,
  build/package integration, commands, tests, CI, and release automation remain repository-owned.
- Removes stale Bazel-scaffolder claims and process machinery based on verifier scripts, receipts,
  manifests, fingerprints, evidence ledgers, or custom state.
- Replaces fictional example project values with generic placeholders.
- Normalizes template headers and `VERSION` at `2.4.0`.

## [2.3.0] — 2026-07-11

Added semantic-checkpoint and object-scoped Git-authority bindings for the optimized agent workflow.

- Replaced obsolete checkpoint-level wording with checkpoint economics, evidence ownership, and reuse.
- Pointed optional orchestrator artifacts at `docs/02-working-docs/work-items/`.
- Separated Plan/auto approval from commit, branch, push, PR, tag, release, and rewrite authority.
- Added object-scoped Git-authority fields to setup and project-configuration examples.

## [2.2.0] — 2026-06-17

Added generic large-scale iOS architecture rules to the portable constitution.

- Added `2.1 Modern large-scale iOS development rules` to `CLAUDE.md`/`AGENTS.md`.
- Generalized Boardy-specific concepts into pattern-neutral composition, workflow, service-contract, and runtime-orchestration wording.
- Kept Boardy/VIP routing language scoped to Boardy/VIP projects only.

## [2.1.0] — 2026-06-16

Generalized template wording beyond Boardy-only projects.

- `CLAUDE.md`/`AGENTS.md` now describe the plugin as reusable iOS standards for both Boardy and non-Boardy projects.
- Boardy/VIP router and task skills are scoped to Boardy/VIP work instead of implied as universal routing.
- Removed install commands from the seeded project constitution; installing the plugin happens before template init.
- Replaced vague rulebook/spec references with concrete `${CLAUDE_PLUGIN_ROOT}/standards/brain/rulebook/` and `${CLAUDE_PLUGIN_ROOT}/standards/specs/` paths.
- Added operating-discipline flow rules: clarify, present alternatives, avoid overengineering, keep changes surgical, define success criteria, and verify by phase.

## [2.0.0] — 2026-06-09

Rewritten for the **plugin model**.

- `CLAUDE.md`/`AGENTS.md` are now a thin **bindings starter** that points at the `ifl-ios-standards`
  plugin for the standard and holds only project bindings (no more `.ai/brain/` copy-into-repo).
- `README.md` + `SETUP.md` describe plugin install (Claude Code + Codex) instead of the
  `.standards/` submodule + `bootstrap.sh` flow.
- Docs/plans/handoffs follow `process/docs-organization.md` (`docs/02-working-docs/…`) — replaces
  the `.superpowers/` workspace.
- Package-manager-neutral (CocoaPods / Bazel / SPM) — was CocoaPods-only.

## [0.1.0] — 2026-05-23

Initial versioned baseline. Captures the template as it shipped with QuizCombatApp.

### Contents

- `README.md` — install instructions + when-to-use rules.
- `SETUP.md` — one-time setup playbook (preconditions, info gathering, project discovery, generate PROJECT_CONFIG/STRUCTURE/QUICK_REF, verify, completion report).
- `AGENTS.md` — portable constitution (precondition check, authority order, mandatory load order, non-negotiable boundaries).
- `CLAUDE.md` — top-level pointer consumed by Claude Code.
- `QUICK_REF.md` — project-agnostic routing cheatsheet shape reference (originally Boardy+VIP-flavored, no QuizCombat-specific paths).

### Versioning policy

- The standard's version is the installed plugin version (`ifl-ios-standards` `plugin.json`); adopters pin it via `claude/codex plugin marketplace add …#vX.Y.Z` if they need a fixed version.
- Adopter projects may record the template version they seeded from in their `CLAUDE.md`. When a new major template ships, adopters can audit their bindings against the new contract.
