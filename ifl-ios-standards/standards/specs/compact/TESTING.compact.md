# TESTING (compact)

Derived from `TESTING.md`. Default load for `ios-tester`. Full spec only when you need a non-trivial mock pattern (e.g. async sequences, snapshot, integration).

Last sync: 2026-07-13 for Standards 1.0 candidate.

## TDD and evidence boundary

- Apply TDD only to executable code where behavioral or regression risk warrants it.
- Documentation, standards prose, metadata, documentation-only schemas, and templates require no TDD
  or runtime gate; their consistency is evaluated by the approved plan's single final joined AI
  review.
- Use observed commands from the consuming repository or provider's native tooling as executable build
  and test evidence. Do not add plugin-owned verification scripts or duplicate CI, nor process-only
  fixtures, checks, receipts, or evidence ledgers.

## What to test (priority)

| Priority | Target | Cases |
|---------|--------|-------|
| 1 | Interactor | `didBecomeActive()` → UseCase + `delegate.loadData()`; user actions → correct UseCase + presenter; error paths → presenter/delegate error |
| 2 | Presenter | Domain → ViewModel mapping (titles, formatting, nil); loading states; error messages |
| 3 | UseCase | Happy path, error path, edge values (empty, nil, boundary) |

## File layout

```
{Module}Tests/
├── Microboards/{Board}/
│   ├── {Board}InteractorTests.swift
│   └── {Board}PresenterTests.swift
├── Services/{UseCase}Tests.swift
├── Mocks/Mock{Board}{Role}.swift
└── Stubs/{Domain}Stubs.swift
```

## Naming

Test methods are camelCase: `testScenarioExpectation` (e.g. `testLoadCartEmptyPresentsEmpty`). **Never** `test_<scenario>_<expectation>` — that snake_case habit violates Apple's Swift API Design Guidelines and SwiftLint's default `identifier_name`.

## Mocks — `recorded` style

```swift
final class MockCheckoutControlDelegate: CheckoutControlDelegate {
    var loadDataCalled = false
    var performCompletionCalled = false
    var lastIsDone: Bool?

    func loadData() { loadDataCalled = true }
    func performCompletion(_ isDone: Bool) {
        performCompletionCalled = true; lastIsDone = isDone
    }
}

final class MockCheckoutPresenter: CheckoutPresentable {
    var presentStateCalled = false
    var lastModel: CheckoutDomain?
    var presentOverlayLoadingCalled = false
    var dismissOverlayLoadingCalled = false
    var presentErrorCalled = false
    var lastError: Error?

    func presentState(_ m: CheckoutDomain) { presentStateCalled = true; lastModel = m }
    func presentOverlayLoading() { presentOverlayLoadingCalled = true }
    func dismissOverlayLoading() { dismissOverlayLoadingCalled = true }
    func presentError(_ e: any Error) { presentErrorCalled = true; lastError = e }
}

final class MockCheckoutView: CheckoutViewable {
    var lastState: CheckoutState?
    var showHUDCalled = false
    var hideHUDCalled = false
    var showErrorCalled = false
    var lastErrorMessage: String?

    func setState(_ s: CheckoutState) { lastState = s }
    func showHUDLoading() { showHUDCalled = true }
    func hideHUDLoading() { hideHUDCalled = true }
    func showErrorSnackMessage(_ m: String) { showErrorCalled = true; lastErrorMessage = m }
}
```

## Interactor test skeleton

```swift
final class CheckoutInteractorTests: XCTestCase {
    var sut: CheckoutInteractor!
    var mockPresenter: MockCheckoutPresenter!
    var mockDelegate: MockCheckoutControlDelegate!
    var mockUseCase: MockCheckoutUseCase!

    override func setUp() {
        super.setUp()
        mockPresenter = MockCheckoutPresenter()
        mockDelegate = MockCheckoutControlDelegate()
        mockUseCase = MockCheckoutUseCase()
        sut = CheckoutInteractor(
            presenter: mockPresenter,
            input: CheckoutInput.stub(),
            someUseCase: mockUseCase
        )
        sut.delegate = mockDelegate
    }

    override func tearDown() {
        sut = nil; mockPresenter = nil; mockDelegate = nil; mockUseCase = nil
        super.tearDown()
    }

    func testDidBecomeActiveCallsLoadData() async throws {
        mockUseCase.fetchResult = .success(.stub())
        sut.didBecomeActive()
        await Task.yield()
        XCTAssertTrue(mockDelegate.loadDataCalled)
        XCTAssertTrue(mockUseCase.fetchCalled)
    }
}
```

## Stub factory

```swift
extension CheckoutInput {
    static func stub() -> CheckoutInput { CheckoutInput() }   // match actual init
}

extension CheckoutDomain {
    static func stub(id: String = "stub-id") -> CheckoutDomain {
        CheckoutDomain(id: id /* , default values */)
    }
}

enum TestError: Error { case network, parsing }
```

> Always inspect the actual `Input` struct before writing the stub. Don't assume `context` / `completion` exist — read the IO file first.

## Async pattern

When the SUT spawns a `Task`, `await Task.yield()` (or `Task.sleep(nanoseconds:)` for ordered effects) inside the test after the action call. Wrap UI-mutating asserts in `await MainActor.run { ... }` only if the SUT itself hops to MainActor.

## Anti-patterns

- Don't mock `URLSession` — wrap it behind a Repository / UseCase and mock that.
- Don't assert against private state — assert on the role boundary (delegate / presenter / view).
- Don't share mocks across tests via a static — fresh instances per `setUp`.
- Don't use `XCTestExpectation` when `await Task.yield()` is enough.

## Full spec (load on demand)

`.ai/specs/TESTING.md` — async sequences, snapshot tests, integration suites, in-memory persistence harnesses.
