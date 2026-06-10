---
name: boardy-testing
description: >-
  Use when writing or reviewing tests for Boardy+VIP iOS code — interactor tests, mocks,
  stubs, async sequences, snapshot, integration. Triggers: "write tests", "unit test a board",
  "mock the interactor", "test coverage for this module".
---

# Testing Boardy+VIP

## Read
- `${CLAUDE_PLUGIN_ROOT}/standards/specs/compact/TESTING.compact.md` — file layout, naming, mock + interactor-test + stub skeletons, anti-patterns (default).
- `${CLAUDE_PLUGIN_ROOT}/standards/specs/TESTING.md` — full reference for non-trivial patterns (async sequences, snapshot, integration).

## Conventions
- Tests live in the module's `Tests/**` (Bazel `swift_library` + `ios_unit_test` target glob it).
- Test the Interactor in isolation with a mock Presenter + stubbed UseCase/Repository.
- Keep the domain layer pure → it's directly unit-testable without UIKit/Boardy.
