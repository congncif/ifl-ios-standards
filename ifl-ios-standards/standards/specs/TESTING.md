<!-- Retrofitted to SPEC_CONTRACT 12 sections on 2026-05-23 -->

# SPEC: Testing Standards

> Reference: VIP + Boardy + DDD test surface for any Boardy+VIP project.
> Companion specs: `VIP_COMPONENTS.md` (Interactor/Presenter contracts), `SERVICE_LAYER.md` (UseCase shape), `MICROBOARD_UI.md` (Board lifecycle), `compact/TESTING.compact.md` + `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded).

## When to use

When writing unit tests for any of:

- VIP Interactor (user actions → UseCase → presenter/delegate calls).
- VIP Presenter (Domain → ViewModel mapping, error/loading flows).
- UseCaseInteractor (business logic, repository orchestration, error policy).
- Board (activation, output emission — when testable in isolation).

## When NOT to use

- ViewController rendering — covered by snapshot/UI tests, not this spec.
- End-to-end / integration tests across multiple modules — separate harness.
- Pure Domain struct equality — usually no tests needed unless custom logic.
- Third-party adapter behavior — test the adapter; vendor SDK is out of scope.

## Forces

- Interactor has TWO dependencies to mock — `presenter` (Presentable) AND `delegate` (Board ControlDelegate). Forgetting the delegate mock leaves nav assertions untested.
- Mocks should be plain classes with `*Called: Bool` flags + `last*` capture — not framework mocks; faster, no magic.
- `await Task.yield()` flushes async work scheduled in `didBecomeActive` etc. — without it, asserts run before the SUT has done anything.
- Stubs (`*.stub()`) keep tests readable; without them every test re-builds full domain trees.
- UseCaseInteractor tests catch real business bugs cheaply; Interactor/Presenter tests catch wiring bugs. Both layers are mandatory.

## Files

```
{ModuleNamePlugins}Tests/
├── Microboards/
│   └── {Feature}/
│       ├── {Feature}InteractorTests.swift
│       └── {Feature}PresenterTests.swift
├── Services/
│   └── {Action}UseCaseTests.swift
├── Mocks/
│   ├── Mock{Feature}Presenter.swift
│   ├── Mock{Feature}ControlDelegate.swift
│   ├── Mock{Feature}View.swift
│   ├── Mock{Feature}UseCase.swift
│   └── Mock{Entity}Repository.swift
└── Stubs/
    └── {Feature}Stubs.swift
```

## Naming

- Test class: `{SUT}Tests: XCTestCase`.
- Test method: `test_{trigger}_{behavior}` (e.g. `test_didBecomeActive_callsLoadData_and_fetchesData`).
- Mocks: `Mock{Type}` conforming to the SUT's protocol surface (`{Feature}Presentable`, `{Feature}ControlDelegate`, `{Feature}UseCase`, `{Feature}Viewable`, `{Entity}Repository`).
- Stubs: extension on the type with `static func stub(...) -> Self`.
- Errors: `enum TestError: Error { case network; case parsing }`.

## Communication

### Coverage matrix

| Component | What to test | Priority |
|---|---|---|
| Interactor | user actions → UseCase calls → delegate/presenter calls | High |
| Presenter | Domain → ViewModel mapping (formatting, nil handling) | High |
| UseCaseInteractor | business logic, error handling, repository calls | High |
| Board | activation, output emission (when testable) | Medium |

### Interactor test

```swift
// Tests/Microboards/{Feature}/{Feature}InteractorTests.swift
import XCTest
@testable import {ModuleNamePlugins}

final class {Feature}InteractorTests: XCTestCase {

    var sut: {Feature}Interactor!
    var mockPresenter: Mock{Feature}Presenter!
    var mockDelegate: Mock{Feature}ControlDelegate!
    var mockUseCase: Mock{Feature}UseCase!

    override func setUp() {
        super.setUp()
        mockPresenter = Mock{Feature}Presenter()
        mockDelegate = Mock{Feature}ControlDelegate()
        mockUseCase = Mock{Feature}UseCase()
        sut = {Feature}Interactor(
            presenter: mockPresenter,
            input: {Feature}Input.stub(),
            someUseCase: mockUseCase
        )
        sut.delegate = mockDelegate
    }

    override func tearDown() {
        sut = nil; mockPresenter = nil; mockDelegate = nil; mockUseCase = nil
        super.tearDown()
    }

    func test_didBecomeActive_callsLoadData_and_fetchesData() async throws {
        mockUseCase.fetchResult = .success(.stub())
        sut.didBecomeActive()
        await Task.yield()
        XCTAssertTrue(mockDelegate.loadDataCalled)
        XCTAssertTrue(mockUseCase.fetchCalled)
        XCTAssertTrue(mockPresenter.presentStateCalled)
    }

    func test_didBecomeActive_whenFetchFails_callsClose() async throws {
        mockUseCase.fetchResult = .failure(TestError.network)
        sut.didBecomeActive()
        await Task.yield()
        XCTAssertTrue(mockDelegate.closeDueToErrorCalled)
        XCTAssertFalse(mockPresenter.presentStateCalled)
    }

    func test_submit_showsLoading_thenCallsDelegate() async throws {
        mockUseCase.submitResult = .success(())
        sut.userDidTapSubmit(with: "data")
        await Task.yield()
        XCTAssertTrue(mockPresenter.presentOverlayLoadingCalled)
        XCTAssertTrue(mockPresenter.dismissOverlayLoadingCalled)
        XCTAssertTrue(mockDelegate.performCompletionCalled)
    }

    func test_submit_whenFails_showsError() async throws {
        mockUseCase.submitResult = .failure(TestError.network)
        sut.userDidTapSubmit(with: "data")
        await Task.yield()
        XCTAssertTrue(mockPresenter.dismissOverlayLoadingCalled)
        XCTAssertTrue(mockPresenter.presentErrorCalled)
        XCTAssertFalse(mockDelegate.performCompletionCalled)
    }
}
```

### Mock ControlDelegate

```swift
final class Mock{Feature}ControlDelegate: {Feature}ControlDelegate {
    var loadDataCalled = false
    var performCompletionCalled = false
    var lastIsDone: Bool?
    var closeDueToErrorCalled = false

    func loadData() { loadDataCalled = true }
    func performCompletion(_ isDone: Bool) {
        performCompletionCalled = true; lastIsDone = isDone
    }
    func closeDueToError() { closeDueToErrorCalled = true }
}
```

### Mock Presenter

```swift
final class Mock{Feature}Presenter: {Feature}Presentable {
    var presentStateCalled = false
    var lastDomainModel: {DomainModel}?
    var presentOverlayLoadingCalled = false
    var dismissOverlayLoadingCalled = false
    var presentErrorCalled = false
    var lastError: Error?

    func presentState(_ model: {DomainModel}) {
        presentStateCalled = true; lastDomainModel = model
    }
    func presentOverlayLoading() { presentOverlayLoadingCalled = true }
    func dismissOverlayLoading() { dismissOverlayLoadingCalled = true }
    func presentError(_ error: any Error) {
        presentErrorCalled = true; lastError = error
    }
}
```

### Presenter test

```swift
final class {Feature}PresenterTests: XCTestCase {

    var sut: {Feature}Presenter!
    var mockView: Mock{Feature}View!

    override func setUp() {
        super.setUp()
        mockView = Mock{Feature}View()
        sut = {Feature}Presenter()
        sut.view = mockView
    }

    func test_presentState_mapsToCorrectViewModel() {
        let model = {Aggregate}.stub(relatedCount: 3)
        sut.presentState(model)
        XCTAssertNotNil(mockView.lastState)
        if case .loaded(let viewModel) = mockView.lastState {
            XCTAssertEqual(viewModel.items.count, 3)
            XCTAssertNotNil(viewModel.title)
        } else {
            XCTFail("Expected .loaded state")
        }
    }

    func test_presentError_showsSnackMessage() {
        sut.presentError(TestError.network)
        XCTAssertTrue(mockView.showErrorSnackCalled)
        XCTAssertNotNil(mockView.lastErrorMessage)
    }

    func test_presentOverlayLoading_showsHUD() {
        sut.presentOverlayLoading()
        XCTAssertTrue(mockView.showHUDCalled)
    }

    func test_dismissOverlayLoading_hidesHUD() {
        sut.dismissOverlayLoading()
        XCTAssertTrue(mockView.hideHUDCalled)
    }
}

final class Mock{Feature}View: {Feature}Viewable {
    var lastState: {Feature}State?
    var showHUDCalled = false
    var hideHUDCalled = false
    var showErrorSnackCalled = false
    var lastErrorMessage: String?

    func setState(_ state: {Feature}State) { lastState = state }
    func showHUDLoading() { showHUDCalled = true }
    func hideHUDLoading() { hideHUDCalled = true }
    func showErrorSnackMessage(_ message: String) {
        showErrorSnackCalled = true; lastErrorMessage = message
    }
}
```

### UseCase test

```swift
final class {Action}UseCaseTests: XCTestCase {

    var sut: {Action}UseCaseInteractor!
    var mockRepository: Mock{Entity}Repository!
    var mockQueryService: Mock{Entity}QueryService!

    override func setUp() {
        super.setUp()
        mockRepository = Mock{Entity}Repository()
        mockQueryService = Mock{Entity}QueryService()
        sut = {Action}UseCaseInteractor(
            repository: mockRepository,
            queryService: mockQueryService
        )
    }

    func test_execute_whenServiceReturnsData_savesToRepository() async throws {
        let aggregate = {Aggregate}.stub()
        mockQueryService.result = aggregate
        try await sut.execute()
        XCTAssertTrue(mockRepository.saveCalled)
        XCTAssertNotNil(mockRepository.lastSaved)
    }

    func test_execute_whenServiceReturnsNil_throwsError() async {
        mockQueryService.result = nil
        do {
            try await sut.execute()
            XCTFail("Should have thrown")
        } catch {
            XCTAssertEqual(error as? {Module}Error, .notFound)
        }
    }
}

final class Mock{Entity}QueryService: {Entity}QueryService {
    var result: {Aggregate}?
    func get{Aggregate}() async throws -> {Aggregate}? { result }
}

final class Mock{Entity}Repository: {Entity}Repository {
    var saveCalled = false
    var lastSaved: {Aggregate}?
    func save(_ aggregate: {Aggregate}) async { saveCalled = true; lastSaved = aggregate }
    func getPrimary() async -> {Entity}? { nil }
    func saveSelection(_ selection: {Entity}Selection) async {}
    func getSelections() async -> [{Entity}Submission] { [] }
    func getRelated() async -> [{Entity}] { [] }
    func getMetadata() async -> {Metadata}? { nil }
}
```

### Stub factories

```swift
extension {Feature}Input {
    static func stub() -> {Feature}Input {
        {Feature}Input(context: nil, completion: nil)
    }
}

extension {Aggregate} {
    static func stub(relatedCount: Int = 2) -> {Aggregate} {
        {Aggregate}(
            primary: {Entity}.stub(),
            related: (0..<relatedCount).map { {Entity}.stub(index: $0) },
            metadata: nil
        )
    }
}

extension {Entity} {
    static func stub(index: Int = 0) -> {Entity} {
        {Entity}(id: "stub-\(index)", name: "Item \(index)", imageURL: nil, tags: [])
    }
}

enum TestError: Error { case network; case parsing }
```

## Concurrency

- `async` SUT methods → use `async throws` test methods; `await sut.method()`.
- Fire-and-forget Tasks inside `didBecomeActive` → `await Task.yield()` between act and assert to flush.
- MainActor-isolated SUT → annotate test method `@MainActor` or wrap with `await MainActor.run { ... }`.
- Don't use `XCTestExpectation` for short async unless waiting for delegate callback fired from a non-Task path; `await Task.yield()` is simpler.
- Mocks need not be thread-safe — tests are single-actor.

## Composition

- Interactor tests compose with mocks that conform to the SAME protocols the production code consumes (`Presentable`, `ControlDelegate`, `UseCase`). Production swap = test swap.
- Stubs live in `Tests/Stubs/` and are reused across Interactor + Presenter + UseCase tests.
- Each test target imports `@testable import {ModuleNamePlugins}` only — never another module's Plugins target.

## Lifecycle

- `setUp()` builds mocks + SUT fresh per test.
- `tearDown()` nils SUT + mocks to surface retain cycles (XCTest warns on leaks if assertions added).
- Stubs are static factories — no lifecycle.
- Tests don't exercise `complete()` / `attachObject` directly; Board lifecycle covered in Board-level integration tests.

## Testing

This spec IS the testing standard — meta-testing checklist:

- [ ] Every UI Board has paired `*InteractorTests.swift` + `*PresenterTests.swift`
- [ ] Every UseCase has `*UseCaseTests.swift`
- [ ] Mocks live in `Tests/Mocks/`, stubs in `Tests/Stubs/`
- [ ] Each test method names trigger + behavior (`test_X_doesY`)
- [ ] Async tests `await Task.yield()` (or proper await) before asserting
- [ ] No vendor-SDK imports in test targets except for adapter tests
- [ ] Mocks conform to protocol surface (not concrete class)
- [ ] `tearDown` nils references

## Pitfalls

- ❌ Mocking the concrete Presenter class instead of `Presentable` → can't swap test/prod
- ❌ Forgetting `await Task.yield()` after `didBecomeActive` → assertions run before async work
- ❌ Testing Interactor with only a Presenter mock → nav assertions slip through; mock the ControlDelegate too
- ❌ Inline domain literals in every test instead of stubs → brittle, noisy diffs
- ❌ Using `XCTestExpectation` for short async work → prefer `await`
- ❌ Asserting on Presenter call from inside ViewController tests → wrong layer; presenter mapping is Presenter's test
- ❌ Sharing one mock instance across tests → state leaks; build in `setUp`
- ❌ `@testable import` against IO module → IO is public; not needed (and not allowed for cross-module tests)
- ❌ Coupling tests to private impl detail (e.g. private property values) → test via observable behavior

## References

- `VIP_COMPONENTS.md` (Interactor/Presenter protocol contracts under test)
- `SERVICE_LAYER.md` (UseCaseInteractor shape under test)
- `MICROBOARD_UI.md` / `MICROBOARD_NONUI.md` (Board lifecycle for integration tests)
- `COMMUNICATION.md` (`complete()` / output semantics)
- `compact/TESTING.compact.md` (always-loaded quick recap)
- `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded)
- `QUICK_REF.md` §4 rules covering tests
