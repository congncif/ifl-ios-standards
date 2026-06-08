<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->
<!-- brain-version: 1.0.0 · last-updated: 2026-05-18 -->

# 20. Non-Negotiable Rules

These are the rules that cannot be relaxed without explicit, documented architectural exception.

1. **Domain is pure Swift.** No UIKit, no networking, no vendor SDKs, no Codable.
2. **Dependencies point inward.** Infrastructure → Business → Domain. Never the reverse.
3. **Consumers depend on contracts, not implementations.** Cross-module imports target interface modules only.
4. **Public is a commitment.** Promote visibility only when a consumer needs it. Audit it.
5. **Vendor types do not appear in public interfaces.** Wrap them at the Infrastructure boundary.
6. **One state, one writer.** Shared mutable state across boundaries is a code smell.
7. **Views are humble.** No business decisions in the view layer.
8. **UI updates run on the main actor.**
9. **Concrete types are instantiated only at composition roots.**
10. **No speculative abstraction.** Build for what exists; refactor when patterns emerge.
11. **No unrelated changes.** Every line touched traces to the task at hand.
12. **No bypass of safety checks.** Hooks, verification, and signing are part of the system.
13. **Verify with real signals.** Empty output is failure. Build success requires explicit success markers.
14. **Report facts, not theater.** Changed files, commands, outcomes, remaining work.
15. **When in doubt, stop and ask.** Ambiguity is the agent's responsibility to surface, not to resolve silently.

---

