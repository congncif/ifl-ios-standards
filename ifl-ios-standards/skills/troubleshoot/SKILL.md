---
name: troubleshoot
description: >-
  Use when debugging a Boardy+VIP symptom — a crash, an assertion, a board that won't activate,
  a bus that fires twice, a duplicate handler, a lifecycle leak. Triggers: "why does this crash",
  "board not activating", "duplicate bus firing", "debug this Boardy error", "error → cause → fix".
---

# Troubleshoot

## Read
- `${CLAUDE_PLUGIN_ROOT}/standards/specs/TROUBLESHOOTING.md` — symptom → cause → fix table.

## Common causes (cross-check against the 14 rules)
- Duplicate handler firing → controller stacked on a bus without release; missing `complete()`/`detachObject(_:)` (rule 12/13).
- Board won't activate / barrier stuck → `activationBarrier` returning non-nil; check `${CLAUDE_PLUGIN_ROOT}/standards/specs/ACTIVATION_BARRIER.md`.
- `complete()` assertion → called twice, or before streams released (rule 12).
- Concurrent BlockTask routing to wrong activation → using `.flow.addTarget` instead of parameter callbacks (rule 14).
- UI update crash off main thread → missing `await MainActor.run { [weak self] … }` (rule 5).
