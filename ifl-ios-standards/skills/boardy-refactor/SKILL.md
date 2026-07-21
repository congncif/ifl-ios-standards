---
name: boardy-refactor
description: >-
  Use when performing a structural refactor on a Boardy+VIP codebase — splitting or merging a
  module, extracting or moving a board across modules, or renaming a public symbol. Triggers:
  "split this module", "merge modules", "extract a board", "move board to another module", "rename a public symbol".
---

# Structural refactor

## Read
- `${CLAUDE_PLUGIN_ROOT}/standards/specs/REFACTOR_PLAYBOOK.md` — procedural runbook for the five structural refactors.

Each section gives: trigger → mechanical sequence → verification → rollback. Move-Board covers
Option A (coordinated cutover) vs Option B (bridge alias for public boards).

## Impact-first sequence

1. Before editing, map the definition, all callers, registrations, ServiceMap accessors, imports,
   package/build edges, tests, App composition, runtime literals, and affected UIKit/SwiftUI adapters.
   Public symbol renames ripple through every IO consumer.
2. Freeze the invariants:
   - public BoardID is exactly `pub.mod.<Module>.<Board>`;
   - `IO/**` is the public domain-contract surface;
   - `Sources/**` is internal except the minimum public App-boot construction surface under
     `Sources/Plugins/**`; sibling modules never import another module's Plugins target;
   - UIKit and SwiftUI remain humble rendering adapters over equivalent display-ready state and typed
     intents.
3. Execute dependency-ordered semantic slices. Introduce the destination/bridge and registration before
   caller cutover; migrate all known callers; remove the old route only when its impact set is empty.
4. Choose a rollback boundary before each slice. If impact expands or its owned signal regresses, restore
   the last coherent contract, registration, caller route, and lifecycle ownership before re-planning.

## Verification economy

- For executable changes, use only the consuming repository's native build/test command from its project
  instructions. Assign one primary signal and owner per semantic slice or distinct risk boundary and run it
  after the complete slice — never after each rename, move, or file edit.
- Do not rerun unchanged green signals or create plugin verifier/lint/smoke scripts, receipts, evidence
  ledgers, manifests, fingerprints, or custom workflow state.
- Documentation-only work has no runtime gate. After the plan's last mutation, it waits for the one final
  joined AI consistency review. Executable changes retain their native test result and join the same final
  review; the review does not replace code tests.
- A contract-changing refactor normally needs spec-sync in the same plan; see
  `${CLAUDE_PLUGIN_ROOT}/standards/rules/SPEC_SYNC.md`.

## Subagent dispatch

Keep a bounded refactor inline. For a broad structural change, use
`ifl-ios-standards:ios-orchestrator` and `ifl-ios-standards:ios-planner`; then route impact mapping to
`ifl-ios-standards:ios-researcher`, contract decisions to `ifl-ios-standards:ios-architect`, approved
slices to `ifl-ios-standards:ios-coder`, executable signals to `ifl-ios-standards:ios-tester`, durable
docs to `ifl-ios-standards:ios-doc-scribe`, and the frozen final candidate to read-only
`ifl-ios-standards:ios-reviewer` plus `ifl-ios-standards:ios-review-triage` lanes. Codex maps the same
responsibilities to provider-native generic subagents; continue inline when delegation is unavailable.
