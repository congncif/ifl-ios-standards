import IFLContracts
import Testing

@Suite("FixtureCanonRepositoryTests", .serialized)
struct FixtureCanonRepositoryTests {
    @Test("all checked-in negative deltas execute through FileCanonRepository")
    func checkedInNegativeFixtureOutcomes() throws {
        for fixturePath in try FixtureCanon.negativeFixturePaths() {
            let execution = try FixtureCanon.execute(fixturePath)
            guard case let .contractError(declaredCode) = execution.expected else {
                Issue.record("\(fixturePath) must declare a contract_error outcome")
                continue
            }
            guard case let .contractError(actualError) = execution.outcome else {
                Issue.record(
                    "\(fixturePath) declared \(declaredCode) but repository returned a snapshot"
                )
                continue
            }
            #expect(
                actualError.code == declaredCode,
                "\(fixturePath) declared \(declaredCode), received \(actualError.code)"
            )
        }
    }
}
