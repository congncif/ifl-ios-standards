# Process — Lean Verification Workflow

**Trigger:** Before implementing any change, and whenever you write or execute an implementation plan.

Re-tiers test discipline by risk and moves verification to checkpoints, so productivity is not lost to per-task TDD and full build/test cycles. The discipline is right; only the granularity changes. This is plain contributor instruction — where a workflow plugin (e.g. superpowers) mandates universal TDD or per-task verification, this doc takes precedence by that plugin's own instruction-priority contract (user instructions outrank skills). It patches, forks, or disables nothing, and degrades to ordinary good practice where no plugin is installed.

## 1. Classify the change (TDD tier)

Classify every change before writing code. When the tier is ambiguous, ask once — do not silently default to Tier 1.

**Tier 1 — Full TDD (test-first, watch it fail, then implement)**
- Core domain logic and use-cases; algorithms and data transformations with non-obvious correctness.
- Public API surface — OpenAPI/gRPC/AsyncAPI contracts and their handlers ([[01-api-contract]]).
- Anything touching money, auth, permissions, transaction boundaries, or data integrity ([[09-tx-boundary]]).
- Bug fixes where regression is plausible — the failing test IS the repro.

**Tier 2 — Test-after, batched**
- Adapters (HTTP/DB/queue/vendor-SDK), mappers, anti-corruption translation.
- CRUD paths with no business rules.
- Wiring in the composition root.

Implement the related group first, then write its tests in one pass. "Related group" = tasks in the same plan phase touching the same module/bounded context.

**Tier 3 — No tests required**
- Configuration and environment wiring.
- Type/struct/interface declarations with no logic.
- Docs, comments, copy.
- Throwaway prototypes/spikes (explicitly labelled).

**Anti-rationalization guard (Tier 1 only).** Within Tier 1 the full strictness applies: if you did not watch the test fail, you do not know it tests the right thing. Tiering never demotes Tier 1 work; when a change spans tiers, the highest applicable tier wins for the parts it covers. Test at the boundaries the layering defines ([[02-layer-boundary]]); see the testing patterns under `standards-pack/standards/backend/patterns/testing/`.

## 2. Verify at checkpoints, not per task

Run verification only at:
- the end of a plan phase;
- after 3–5 related tasks if a phase runs long;
- before any commit;
- before reporting completion (full gate, §3).

Never run a full build + full suite after each individual task.

**Cheapest-sufficient-check ladder:**

| Level | Check | When |
|---|---|---|
| L0 | Compile/vet only (`go vet ./...` / `./gradlew compileKotlin`) | after mechanical/refactor changes |
| L1 | Tests for the changed package/module only (`go test ./internal/<pkg>/...` / `./gradlew test --tests <Class>`) | default at intra-phase checkpoints |
| L2 | Full test suite (`go test ./...` / `./gradlew test`) | end of a phase |
| L3 | Full gate — `make verify` (Go) / `./gradlew verify` (Kotlin) | once, before reporting completion / before push |

Run the cheapest level that can catch the likely failure; escalate only on need.

**This pack's L3 gate:** `make verify` (Go) / `./gradlew verify` (Kotlin) — the authoritative gate; agents do not interpret its output, they make it green.

## 3. Completion gate

"Done" requires exactly one green L3 at the end. A green L3 earlier does not exempt the final one if code changed since.

## 4. Plan structure

When writing implementation plans (with or without a planning skill):
1. Group tasks into phases of 3–7 related tasks.
2. Place verification steps at phase boundaries only — a plan with "run tests" after every individual task is malformed under this doc; restructure it.
3. Each phase declares its checkpoint level (default L1 mid-plan, L2 at phase end, L3 once at plan end).
4. Tier each task (§1) so the executor does not re-litigate TDD per task.

Example phase block:

```markdown
### Phase 2: Order pricing [verify: L2 at end]
- [ ] T2.1 Price calculation domain logic (Tier 1 — TDD)
- [ ] T2.2 Discount policy evaluation (Tier 1 — TDD)
- [ ] T2.3 Wire pricing into the checkout use-case (Tier 2 — test-after, batch with T2.4)
- [ ] T2.4 Map pricing into the HTTP adapter response (Tier 2)
- [ ] T2.5 Update the OpenAPI schema / docs (Tier 3 — no tests)
```

## Verification

This process is being followed when:
- Every task in the plan carries a tier.
- Mid-plan checkpoints used the cheapest sufficient level; no full build + suite ran per task.
- Exactly one green L3 ran after the last code change, before "done" was claimed.

## Non-goals
- Disabling or forking workflow plugins — precedence handles it.
- Lowering coverage targets — this changes *when* tests run, not *whether*.
- Replacing CI — L3 mirrors CI locally; CI stays authoritative.

## See also
- `process/docs-organization.en.md` — where plans and specs live.
- [[01-api-contract]] · [[02-layer-boundary]] · [[09-tx-boundary]]
