import IFLContracts

public struct CheckResult: Codable, Hashable, Sendable {
    public let checkID: String
    public let passed: Bool
    public let severity: FindingSeverity?
    public let message: String?

    public init(
        checkID: String,
        passed: Bool,
        severity: FindingSeverity? = nil,
        message: String? = nil
    ) {
        self.checkID = checkID
        self.passed = passed
        self.severity = severity
        self.message = message
    }

    private enum CodingKeys: String, CodingKey {
        case checkID = "check_id"
        case passed
        case severity
        case message
    }
}
