import IFLContracts

public struct VerificationReport: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let exitCode: IFLExitCode
    public let checks: [CheckResult]

    public init(exitCode: IFLExitCode, checks: [CheckResult]) {
        schemaVersion = Self.currentSchemaVersion
        self.exitCode = exitCode
        self.checks = checks
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case exitCode = "exit_code"
        case checks
    }
}
