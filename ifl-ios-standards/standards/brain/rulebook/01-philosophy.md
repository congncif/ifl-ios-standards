<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->
<!-- brain-version: 1.0.0 · last-updated: 2026-05-18 -->

# 1. Philosophy

### 1.1 First Principles

1. **The platform is the foundation.** Apple's SDKs are not a fallback — they are the substrate. Build on them; do not abstract them away preemptively.
2. **Architecture is a boundary of reasoning, not ceremony.** Every line of structural code must reduce future cognitive load, not add to it.
3. **Modularity is ownership, not file folders.** A module is a unit of responsibility with a stable contract, a clear blast radius, and an independent build identity.
4. **Domain is sacred.** Business rules outlive frameworks, vendors, and OS versions. Protect them from contamination.
5. **Composition over inheritance, contracts over coupling, explicitness over magic.**
6. **The smallest correct change is the best change.** Surgical edits preserve system coherence; sweeping refactors fragment it.
7. **Verification is part of the work.** A change is not complete until its behavior is observed against a real signal.
8. **Optimize for the next reader.** That reader may be a junior engineer, a senior engineer six months from now, or an AI agent with no conversation history.

### 1.2 The Engineering Loop

For every task — human or agent:

1. **Understand** the boundary, the data flow, the state owner, and the verification path.
2. **Locate** the smallest set of files the change requires.
3. **Preserve** the existing shape: naming, layering, dependency direction, access modifiers.
4. **Implement** the minimum correct change.
5. **Verify** with a real signal (build, test, runtime observation).
6. **Report** what changed, what passed, what failed, what remains.

No step is optional. Skipping understanding produces noise. Skipping verification produces lies.

### 1.3 Tradeoff Posture

When forced to choose:

| Prefer | Over |
|--------|------|
| Stability | Cleverness |
| Explicitness | Magic |
| Locality | Spooky action at a distance |
| Platform-native | Third-party |
| Composition | Inheritance |
| Smaller surface | More surface |
| Pure functions | Stateful objects |
| Deletion | Addition |
| Reading | Writing |
| Asking | Guessing |

---

