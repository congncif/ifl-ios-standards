---
name: boardy-troubleshoot
description: >-
  Use when debugging a Boardy+VIP symptom — a crash, an assertion, a board that won't activate,
  a bus that fires twice, a duplicate handler, a lifecycle leak. Triggers: "why does this crash",
  "board not activating", "duplicate bus firing", "debug this Boardy error", "error → cause → fix".
---

# Troubleshoot

## Read
- `${CLAUDE_PLUGIN_ROOT}/standards/specs/TROUBLESHOOTING.md` — symptom → cause → fix table.

## Impact-first workflow

1. Bound user/runtime severity and reproducibility. Map the affected contract, callers, registrations,
   module/package edges, lifecycle/concurrency owner, data, and UIKit/SwiftUI adapters before editing.
2. Trace backward from the symptom to the first violated invariant. For activation failures, follow caller
   → ServiceMap → ModulePlugin/BoardID → LauncherPlugin → App installation. For UI failures, compare the
   display-ready state and typed intents before inspecting rendering mechanics.
3. Fix the smallest complete semantic slice and choose its rollback boundary first. If impact expands or
   the signal regresses, restore the last coherent contract, registration, caller route, and lifecycle
   ownership instead of stacking speculative changes.

## Signal contract

- Executable fixes use only the consuming repository's native build/test command. Assign one primary
  signal and owner per semantic slice or distinct risk boundary and run it after the slice, not after each
  file edit or hypothesis.
- Documentation-only fixes have no runtime gate and wait, with the rest of the plan, for one final joined
  AI consistency review after the last mutation.
- Never create plugin verifier/lint/smoke scripts, duplicate unchanged green runs, receipts, evidence
  ledgers, manifests, fingerprints, or custom workflow state.

## Common causes (cross-check against the 14 rules)
- `BoardID not registered` after move/rename → canonical public literal is
  `pub.mod.<Module>.<Board>`; inspect caller, IO accessor, registration, LauncherPlugin, install list, and
  planned compatibility alias together.
- Visibility finding → public domain contracts live in `IO/**`; `Sources/**` is internal except the minimum
  App-boot construction surface under `Sources/Plugins/**`. Sibling modules never import Plugins.
- UIKit/SwiftUI semantic mismatch → restore one Presenter/equivalent display-ready state and typed intents;
  Views own rendering mechanics and transient UX-local state only.
- Duplicate handler firing → controller stacked on a bus without release; missing `complete()`/`detachObject(_:)` (rule 12/13).
- Board won't activate / barrier stuck → `activationBarrier` returning non-nil; check `${CLAUDE_PLUGIN_ROOT}/standards/specs/ACTIVATION_BARRIER.md`.
- `complete()` assertion → called twice, or before streams released (rule 12).
- Concurrent BlockTask routing to wrong activation → using `.flow.addTarget` instead of parameter callbacks (rule 14).
- UI update crash off main thread → missing `await MainActor.run { [weak self] … }` (rule 5).
