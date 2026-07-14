<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->
<!-- brain-version: 1.0.0 · last-updated: 2026-05-18 -->

# Appendix C — Generic Verification Commands

Resolve project-specific values (workspace name, scheme, simulator) from the project binding document (`PROJECT_CONFIG.md` or equivalent).

These are adapter examples for executable iOS changes, not a universal completion gate. Select the
smallest representative set covering the changed behavior, the common supported configuration, and
directly impacted configuration-specific surfaces. Do not enumerate every scheme, destination,
package-manager, or build-system permutation unless the approved DoD or bound project/release policy
requires it. Do not collect equivalent signals across build systems unless changed build logic creates
a distinct risk. Documentation-only changes require neither command, and unchanged code is not rerun
for a duplicate green signal.

```bash
# Build with filtered output
xcodebuild build -workspace {Workspace} -scheme {Scheme} \
  -destination '{Destination}' \
  -derivedDataPath DerivedData 2>&1 \
  | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)"

# Test with filtered output
xcodebuild test -workspace {Workspace} -scheme {Scheme} \
  -destination '{Destination}' \
  -derivedDataPath DerivedData 2>&1 \
  | grep -E "(error:|FAILED|PASSED|TEST SUCCEEDED|TEST FAILED|BUILD SUCCEEDED|BUILD FAILED)"
```

When one of these commands is applicable, do not use `-quiet` or output suppressors that hide
failures. Report only the result actually observed.

Add another configuration only when it closes a distinct risk. A named owner with authority over the
boundary may waive a nonstandard configuration when an accepted representative platform signal is
bound to the same exact implementation or candidate state. The record must state the omitted boundary,
accepted signal, rationale, unproven target coverage, residual risk, and owner. Never report waived
target coverage as observed or hide/downgrade P0/P1 evidence.

---

*End of rulebook. This document is intended to be portable across projects, copied verbatim into `.ai/brain/` of any modular iOS codebase, and used as the architectural constitution by both human engineers and AI agents working on that codebase.*
