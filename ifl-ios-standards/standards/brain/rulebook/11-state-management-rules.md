<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->
<!-- brain-version: 1.0.0 · last-updated: 2026-05-18 -->

# 11. State Management Rules

### 11.1 Unidirectional Flow

Regardless of presentation pattern:

```
Intent ──► Business processing ──► State mutation ──► Rendering
   ▲                                                       │
   └───────────────────────────────────────────────────────┘
                       (user observes, acts again)
```

This loop is **explicit, traceable, and testable** at every arrow.

### 11.2 State Ownership Rules

- **Each piece of state has exactly one writer.**
- Readers receive immutable snapshots or observable streams.
- Shared mutable state across boundaries is a code smell — promote it to an owned, encapsulated component.

### 11.3 Concurrency Discipline

- All UI updates run on the **main actor**.
- Business logic runs off the main thread by default for I/O-bound work.
- Use Swift Concurrency (`async`/`await`, `Task`, actors) as the default; bridge to legacy callbacks at the edges.
- Always capture `self` weakly in long-lived `Task` closures; re-bind via `guard let self else { return }`.

```swift
Task { [weak self] in
    guard let self else { return }
    do {
        let result = try await useCase.execute()
        await MainActor.run { [weak self] in
            guard let self else { return }
            self.output.send(result)
        }
    } catch {
        await MainActor.run { [weak self] in
            guard let self else { return }
            self.output.send(error)
        }
    }
}
```

### 11.4 Side-Effect Isolation

- Side effects are explicit (a method that does I/O is named for it: `submit`, `persist`, `fetch`)
- Side effects happen at the **edges** (Infrastructure adapters), not in the middle
- Pure functions in Domain and most of Business Application

---

