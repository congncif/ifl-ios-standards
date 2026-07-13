@testable import IFLContracts
import Testing

@Suite("ExitCodeTests")
struct ExitCodeTests {
    @Test("exit codes are stable from zero through five")
    func stableRawValues() {
        #expect(IFLExitCode.passed.rawValue == 0)
        #expect(IFLExitCode.conformanceFailure.rawValue == 1)
        #expect(IFLExitCode.invalidInput.rawValue == 2)
        #expect(IFLExitCode.blockedEnvironment.rawValue == 3)
        #expect(IFLExitCode.internalError.rawValue == 4)
        #expect(IFLExitCode.integrityViolation.rawValue == 5)
    }

    @Test("finding severities have four stable wire values")
    func stableSeverityValues() {
        #expect(FindingSeverity.allCases.map(\.rawValue) == ["critical", "high", "medium", "low"])
    }
}
