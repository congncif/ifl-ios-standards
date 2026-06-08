<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->
<!-- brain-version: 1.0.0 · last-updated: 2026-05-18 -->

# 18. Decision Heuristics

### 18.1 "Should I add a new module?"

```
Is the capability genuinely independent? ──► No ──► Add to existing module
                │
                Yes
                ▼
Does it have ≥ 2 consumers (or will it soon)? ──► No ──► Add to existing module
                │
                Yes
                ▼
Does it have an independent ownership model? ──► No ──► Reconsider
                │
                Yes
                ▼
                Create a module — with both interface and implementation
```

### 18.2 "Should I add a third-party dependency?"

```
Can the SDK do this reasonably? ──► Yes ──► Use the SDK
        │
        No
        ▼
Is the local cost > 1 week of engineering? ──► No ──► Build it locally
        │
        Yes
        ▼
Will it be confined behind an adapter? ──► No ──► Refuse or redesign
        │
        Yes
        ▼
Is the library well-maintained, widely-used, license-clean? ──► No ──► Refuse
        │
        Yes
        ▼
        Add it — at Infrastructure layer only, behind an adapter
```

### 18.3 "Should I add an abstraction?"

```
How many concrete usages exist today? ──► 1 ──► Do NOT abstract
        │
        2 or more
        ▼
Do the usages share the same shape, or just look similar? ──► Just similar ──► Do NOT abstract
        │
        Same shape
        ▼
Can the abstraction be named in business terms? ──► No ──► Reconsider
        │
        Yes
        ▼
        Introduce the abstraction
```

### 18.4 "Should I promote a symbol to `public`?"

```
Is there a concrete consumer today? ──► No ──► Keep internal
        │
        Yes
        ▼
Can the consumer access it via a protocol? ──► No ──► Make the protocol public, keep the type internal
        │
        Yes — promote the protocol, not the type
```

### 18.5 "Where does this code go?"

```
Does it model business reality? ──► Yes ──► Domain
Does it orchestrate business intent? ──► Yes ──► Business Application
Does it adapt an external system? ──► Yes ──► Infrastructure
Does it render or capture user input? ──► Yes ──► UI
Is it composition wiring? ──► Yes ──► Composition root
```

---

