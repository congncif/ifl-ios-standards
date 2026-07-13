<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->
<!-- brain-version: 1.0.0 · last-updated: 2026-05-18 -->

# Appendix C — Generic Verification Commands

Resolve project-specific values (workspace name, scheme, simulator) from the project binding document (`PROJECT_CONFIG.md` or equivalent).

These are adapter examples for executable iOS changes, not a universal completion gate. Select only
the smallest command relevant to the changed behavior and consuming repository. Documentation-only
changes require neither command, and unchanged code is not rerun for a duplicate green signal.

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

---

*End of rulebook. This document is intended to be portable across projects, copied verbatim into `.ai/brain/` of any modular iOS codebase, and used as the architectural constitution by both human engineers and AI agents working on that codebase.*
