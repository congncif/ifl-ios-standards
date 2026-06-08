<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->
<!-- brain-version: 1.0.0 · last-updated: 2026-05-18 -->

# Appendix C — Generic Verification Commands

Resolve project-specific values (workspace name, scheme, simulator) from the project binding document (`PROJECT_CONFIG.md` or equivalent).

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

Never use `-quiet` or output suppressors that hide failures. Empty filter output indicates failure, not success.

---

*End of rulebook. This document is intended to be portable across projects, copied verbatim into `.ai/brain/` of any modular iOS codebase, and used as the architectural constitution by both human engineers and AI agents working on that codebase.*
