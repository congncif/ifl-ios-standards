# Enterprise Standard — Modern Testing and Evidence

## Purpose

Define a risk-proportionate testing system for executable iOS code with deterministic asynchronous
behavior, explicit contract and architecture coverage, and factual evidence. Documentation and
standards consistency are evaluated by the plan's single final joined AI review, not by invented tests.

## Applicability

Applies to executable Swift/Objective-C production code, public and wire contracts, concurrency,
presentation mapping, infrastructure adapters, accessibility behavior, critical UI journeys,
performance baselines, and regression fixes. TDD and runtime testing apply only to executable code.
Markdown, standards prose, metadata, schemas used only as documentation, and templates do not require
TDD or build/test gates.

## Non-negotiable rules

- `TEST-BOUNDARY-001`: choose Swift Testing or XCTest by capability and repository compatibility, and
  apply TDD only to executable behavior whose risk warrants test-first development.
- `TEST-ASYNC-001`: asynchronous tests use controlled clocks/schedulers/sequences, bounded awaits,
  cancellation, and deterministic completion; timing sleeps are not behavioral proof.
- `TEST-CONTRACT-001`: public, serialized, network, storage, and cross-module contracts have compatibility tests.
- `TEST-ARCH-001`: architecture tests cover dependency direction, forbidden imports, visibility, and boundary invariants where automation is valuable.
- `TEST-SNAPSHOT-001`: snapshots protect intentional stable visual semantics and require deliberate baseline review.
- `TEST-A11Y-001`: accessibility semantics and alternate-input behavior are tested at the cheapest meaningful layer.
- `TEST-SMOKE-001`: a small owned UI smoke set covers release-critical user journeys.
- `TEST-PERF-001`: performance claims use representative, repeatable baselines and reviewed thresholds.
- `TEST-EVIDENCE-001`: executable-code claims cite observed command-backed results and context; generated or self-reported green text is not evidence.
- `TEST-NAME-001`: test names are behavior-oriented camelCase in the form `testScenarioExpectation`.

## Decision guidance

- Prefer Swift Testing for new pure Swift unit, value, parameterized, and asynchronous behavior when
  the supported toolchain and repository conventions permit it.
- Use XCTest where platform capability requires it, including XCUITest, performance APIs, Objective-C
  interoperability, legacy suites, and XCTest-only lifecycle/integration support.
- Use strict test-first development for high-risk business rules, algorithms, public/wire contracts,
  security/data integrity, and regression defects. Ordinary adapters and wiring may be tested after
  implementation within the semantic task. Trivial declarations, styling, docs, and metadata need no runtime test.
- Test through the public seam and observable outcome. Do not expose implementation details solely for tests.
- Add the cheapest layer that can falsify the behavior; escalate to UI or integration only when a lower layer cannot.

## Implementation patterns

- Inject a clock, scheduler, random source, transport, and persistence boundary where determinism needs control.
- Model asynchronous streams as finite test scenarios: subscribe, drive an explicit sequence, await a
  bounded terminal condition, assert values/order/cancellation, and tear down producers.
- Give every task a visible owner and cancellation path; tests assert cleanup as well as success.
- Maintain consumer-driven or shared contract cases for payload compatibility and version transitions.
- Express architecture constraints as focused dependency/import/access tests only when they protect an
  executable repository boundary; do not recreate plugin-owned verifier infrastructure.
- Keep snapshots small, semantically named, trait-aware, and changed only with explicit visual review.
- Record the executed command, relevant environment/toolchain, result, and performance measurement context.

## Compliant and non-compliant examples

Compliant:

- `testExpiredSessionRequestsReauthentication` describes scenario and expected behavior in camelCase.
- An AsyncSequence test drives three values through a controlled producer and awaits a bounded completion.
- A contract test decodes current and supported historical payloads through the public adapter.
- A snapshot update is isolated, visually inspected, and explained by the product change.
- A performance result records device class, OS/toolchain, scenario, samples, baseline, and threshold.

Non-compliant:

- A test waits an arbitrary number of seconds and assumes success if no callback arrives.
- A test asserts private call order while ignoring the externally observable result.
- A broad UI suite duplicates unit coverage and depends on shared account or execution order.
- A snapshot directory is regenerated wholesale without inspecting the semantic changes.
- A Markdown chapter receives a fake runtime test solely to satisfy a process counter.

## Anti-patterns

- Timing sleeps, unbounded awaits, detached work, or leaked continuations in tests.
- One test framework mandated for capabilities it does not support.
- Coverage percentage used as a substitute for risk and behavioral completeness.
- Mock frameworks that obscure the contract when a small fake would be clearer.
- Tests coupled to private methods, incidental task ordering, locale, wall clock, or network availability.
- Re-running an unchanged green suite merely to create duplicate evidence.
- Treating AI commentary, generated logs, or “should pass” statements as executed test evidence.

## Verification

Executable code is verified by the consuming repository's ordinary build/test commands at the owner
defined by its delivery plan. A failure is diagnostic evidence; an unavailable tool, malformed test
harness, or stale environment is not a valid behavioral red signal. Documentation-only work receives
no TDD cycle. The single final joined AI consistency review checks this chapter, ADR-0011, Rule records,
cross-references, and absence of obsolete snake-style naming or plugin-owned test façades.

## Exceptions

An exception states the untested executable behavior, risk, reason the normal signal is unavailable,
temporary alternative evidence, owner, approver, expiry, and remediation plan. It cannot relabel
documentation as executable behavior, accept an unbounded asynchronous test, waive security/data-
integrity regression coverage without human authority, or convert a self-reported claim into evidence.

## Migration and adoption

1. Inventory suites by behavior, risk, framework, owner, runtime, determinism, and flake history.
2. Rename tests to behavior-oriented camelCase `testScenarioExpectation` when touched; do not create a
   repository-wide rename solely for style unless separately planned.
3. Replace timing sleeps and uncontrolled dependencies with clocks, schedulers, finite sequences, and fakes.
4. Move duplicated UI coverage down to unit/contract layers while preserving release-critical smoke journeys.
5. Establish intentional snapshot, accessibility, contract, architecture, and performance ownership.
6. Delete process-only tests that cannot falsify behavior and route documentation consistency to final AI review.

## Ownership

The Testing Owner owns this chapter and ADR-0011. Domain, feature, platform, accessibility, and
performance owners own tests for their behavior. Repository maintainers own the Swift Testing/XCTest
toolchain boundary and canonical commands. DevOps owns CI execution and retention outside this plugin.

## Metrics

Track escaped regressions by layer, flaky-test rate, retry rate, median/p95 suite duration, deterministic-
async conversion, contract coverage, critical-flow smoke coverage, accessibility coverage, snapshot
churn, performance-baseline freshness, and tests removed for implementation coupling. Metrics guide
investment; no universal coverage percentage is mandated.

## Review cadence

Review strategy when public contracts, concurrency ownership, supported toolchains, critical journeys,
accessibility obligations, or performance budgets change. Owners review flake, runtime, snapshots,
smokes, and stale tests on the organization-defined engineering cadence and after significant incidents.
