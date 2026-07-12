# ADR-0011 — Testing and evidence boundary

- Status: In review
- Decision date: 2026-07-13
- Owner: Testing Owner

## Context

iOS repositories need deterministic confidence across pure business behavior, public contracts,
architecture boundaries, asynchronous work, accessibility, critical UI journeys, snapshots, and
performance. No single framework or test tier serves every capability. Process drift also creates two
opposite failures: risky executable behavior without causal tests, and documentation burdened with
fabricated TDD/build gates that cannot prove runtime behavior.

## Decision

Choose Swift Testing or XCTest by required capability and repository compatibility. Prefer Swift
Testing for new pure Swift unit, value, parameterized, and asynchronous behavior when supported; use
XCTest for XCUITest, performance APIs, Objective-C interoperability, legacy suites, and capabilities
that remain XCTest-specific.

Apply TDD only to executable code and proportionally to behavioral risk. High-risk business rules,
algorithms, public/wire contracts, security/data integrity, and regression defects use test-first
causal proof. Ordinary adapters and wiring may be tested after implementation within their semantic
task. Documentation, standards prose, metadata, documentation-only schemas, and templates require no
TDD or runtime gate; the approved plan's single final joined AI review evaluates their consistency.

Asynchronous tests use deterministic clocks, schedulers, finite AsyncSequences, cancellation, and
bounded awaits instead of timing sleeps. Evidence for executable builds, tests, and performance comes
from observed commands with relevant context. Test names describe behavior in camelCase using
`testScenarioExpectation`.

## Consequences

- Teams use the framework that supplies the required capability instead of forcing one universal tool.
- TDD investment follows executable behavior and regression risk, not file type or process counters.
- Deterministic asynchronous tests reduce flake and expose cancellation/continuation defects.
- Unit, contract, architecture, snapshot, accessibility, UI smoke, and performance signals form a
  risk-based hierarchy rather than duplicated gates.
- Documentation avoids fake runtime evidence while executable-code claims remain command-backed.

## Alternatives considered

- Mandating Swift Testing for every test was rejected because UI automation, performance, Objective-C,
  and repository/toolchain constraints still require XCTest capabilities.
- Mandating XCTest for all new code was rejected because it would ignore Swift Testing's native value,
  parameterization, and concurrency model where supported.
- Requiring TDD for Markdown, metadata, templates, and documentation-only schemas was rejected because
  those artifacts have no executable behavior for a runtime test to falsify.
- Accepting AI assertions or generated green output as test evidence was rejected because claims must
  remain distinguishable from observed execution.

## Migration

Inventory tests by behavior, risk, framework, determinism, ownership, runtime, and flake history.
Adopt the framework boundary for new work; migrate existing tests only when touched or when capability,
maintenance, or reliability justifies it. Replace timing sleeps and uncontrolled dependencies with
controlled clocks, schedulers, finite sequences, bounded awaits, and fakes. Rename touched project-
owned tests to `testScenarioExpectation`. Remove process-only tests that cannot falsify behavior and
route documentation consistency to the final joined AI review.

## Canon mapping

- Rules: `TEST-BOUNDARY-001`, `TEST-ASYNC-001`, `TEST-CONTRACT-001`, `TEST-ARCH-001`,
  `TEST-SNAPSHOT-001`, `TEST-A11Y-001`, `TEST-SMOKE-001`, `TEST-PERF-001`,
  `TEST-EVIDENCE-001`, `TEST-NAME-001`
- Profile: `core`
- Reference: `standards/enterprise/modern-testing.md`
- Migration: `MIG-ADR-0011`
