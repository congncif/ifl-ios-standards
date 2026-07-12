---
name: boardy-adopt
description: >-
  Use when bringing Standards 1.0 and Boardy+VIP into an existing iOS app, incrementally migrating
  from 0.18.x, or standing up a greenfield app with UIKit and/or SwiftUI rendering adapters.
---

# Adopt Standards 1.0 with Boardy+VIP

## Read by scenario

- Shared contract → `${CLAUDE_PLUGIN_ROOT}/standards/specs/ADOPTION.md`
- Existing app or 0.18.x transition →
  `${CLAUDE_PLUGIN_ROOT}/standards/specs/BROWNFIELD_MIGRATION.md`
- New app → `${CLAUDE_PLUGIN_ROOT}/standards/specs/GREENFIELD_SETUP.md`
- Architecture and rendering → `${CLAUDE_PLUGIN_ROOT}/standards/specs/ARCHITECTURE.md` and
  `${CLAUDE_PLUGIN_ROOT}/standards/specs/MICROBOARD_UI.md`

## Operating sequence

1. Read the consuming repository's `CLAUDE.md` / `AGENTS.md` for project commands, configuration,
   module roots, dependency pins, CI ownership, and exceptions. Ask only for a missing value that
   materially changes the adoption.
2. Select greenfield or brownfield guidance. For brownfield, inventory the current routes and plan a
   strangler migration in complete semantic slices with explicit cutover and rollback.
3. Preserve the IO/implementation split and typed `Input`/`Output`/`Command`/`Action` intent. Cross-
   module consumers import IO only; compatibility bridges stay in implementation/composition.
4. Preserve one humble-View contract for UIKit and SwiftUI. Presenter/equivalent code prepares
   display-ready semantic state and formatting. Views render and forward typed intent; only transient
   UX-local state and geometry/visual interpolation remain in the View.
5. Use provider-native `/ifl-ios-standards:brain-flow` in the repository's configured mode:
   co-working for user requirement/plan approval, or auto for AI gates with material escalation only.
6. Route module, Board, IO, communication, service, composition, and testing work through the matching
   `boardy-*` skills. Use repository-owned executable signals when code changes.

## Boundary

The consuming repository owns project generation, build/test/format commands, configuration, CI,
rollout, and release. Documentation-only work has no build/test gate.

Do not introduce pack-owned verifier/lint/smoke scripts, receipts/manifests, fingerprints, evidence
ledgers, a custom workflow kernel, or provider-independent runtime state. Track progress in the
approved plan or provider-native task state and use one joined final AI consistency review after the
complete plan.
