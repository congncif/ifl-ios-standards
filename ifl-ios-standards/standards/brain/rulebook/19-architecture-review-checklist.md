<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->
<!-- brain-version: 1.0.0 · last-updated: 2026-05-18 -->

# 19. Architecture Review Checklist

This is derived review guidance, not a second Rule registry. Apply only the selected Canon Profiles;
where wording differs, Canon governs. Use this checklist for code review, agent self-review, and
architecture audits.

### 19.1 Dependency & Layering

- [ ] Domain imports only Foundation
- [ ] Business Application imports Domain (and only architecture primitives beyond it)
- [ ] Infrastructure imports Domain (and vendor SDKs); never Business Application
- [ ] UI imports presentation contracts; never repositories or use cases directly
- [ ] No consumer imports another module's implementation package
- [ ] No vendor type appears in any contract module

### 19.2 Module Boundaries

- [ ] Each module has a clear, single capability
- [ ] Interface module is minimal and stable
- [ ] Implementation module is the only place vendor SDKs are imported
- [ ] No "Common"/"Utilities" trunk module imported by every feature

### 19.3 Domain Quality

- [ ] Models are value types unless identity demands otherwise
- [ ] No `Codable` on domain models
- [ ] Errors are enums conforming to `Error`
- [ ] Repository protocols return domain models, not DTOs
- [ ] Names mirror business vocabulary

### 19.4 Business Layer Quality

- [ ] Each use case has one protocol and one implementation
- [ ] Use cases depend on repository/service protocols, not concrete infrastructure
- [ ] State ownership is explicit and singular
- [ ] Presentation mapping has exactly one owner per screen

### 19.5 UI Quality

- [ ] View renders state and forwards events; contains no business decisions
- [ ] No domain types in view code; only view models
- [ ] All UI updates execute on the main actor
- [ ] No side effects in view layer beyond intent emission

### 19.6 Composition Quality

- [ ] Concrete types are instantiated only at composition roots
- [ ] Inner layers depend on protocols
- [ ] Shared dependencies are owned by an explicit composition root, not ambient singletons

### 19.7 Code Quality

- [ ] No speculative abstractions
- [ ] No commented-out code
- [ ] No `Manager` / `Helper` / `Util` non-names
- [ ] No bypass of safety checks (hook skips, force operations) without explicit approval
- [ ] Concurrency uses Swift Concurrency by default; weak self in long-lived tasks

### 19.8 Agentic Quality

- [ ] File layout matches canonical structure
- [ ] Names match canonical patterns
- [ ] Trace headers / authorship metadata present on new files (per project convention)
- [ ] Diff contains only changes required by the task
- [ ] Executable changes have the smallest risk-relevant signal; documentation-only changes have no
      artificial build/test gate
- [ ] Report states facts: changed files, commands run, results

For a plan-scale change, this checklist participates in the one final joined AI consistency review
after all semantic tasks; it does not create a review checkpoint per task.

---
