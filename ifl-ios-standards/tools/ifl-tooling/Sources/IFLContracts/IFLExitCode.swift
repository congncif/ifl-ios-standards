public enum IFLExitCode: Int32, Codable, CaseIterable, Sendable {
    case passed = 0
    case conformanceFailure = 1
    case invalidInput = 2
    case blockedEnvironment = 3
    case internalError = 4
    case integrityViolation = 5
}
