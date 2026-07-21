---
name: boardy-service-layer
description: >-
  Use when building the non-UI layers of a Boardy module — domain services, use cases,
  repositories, infrastructure — or deciding layering / cross-module dependency injection.
  Triggers: "service layer", "use case", "repository", "domain logic", "cross-module DI", "layering".
---

# Service / UseCase / Repository / Infra

## Read
- `${CLAUDE_PLUGIN_ROOT}/standards/specs/SERVICE_LAYER.md` — service/use-case/repo/infra structure.
- `${CLAUDE_PLUGIN_ROOT}/standards/specs/LAYERING.md` — the 3-layer dependency rule + boundaries.
- `${CLAUDE_PLUGIN_ROOT}/standards/specs/CROSS_MODULE_DI.md` — sharing services across modules.
- `${CLAUDE_PLUGIN_ROOT}/standards/specs/EXAMPLES_SERVICE.md` — worked example.

## Invariants
- Domain layer is **pure Swift** — no UIKit, no Boardy, no networking (rule 9).
- `sharedRepository` is a stored property on the ModulePlugin — never created inside closures (rule 10).
- Provider configurations live in `Sources/Plugins/` (boot-time wiring), never IO (rule 3).
- Cross-module sharing flows through IO targets only — never import another module's `{Name}Plugins` (rule 4).

## Subagent dispatch

Keep a bounded service-layer change inline. When separate ownership helps, route layering and cross-module
DI decisions to `ifl-ios-standards:ios-architect`, approved domain/service/repository changes to
`ifl-ios-standards:ios-coder`, executable domain and use-case behavior to
`ifl-ios-standards:ios-tester`, and dependency-direction audits to read-only
`ifl-ios-standards:ios-reviewer`. Use `ifl-ios-standards:ios-researcher` only for a bounded lookup.
Codex maps the same responsibilities to provider-native generic subagents; continue inline when
delegation is unavailable.
