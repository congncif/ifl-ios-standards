import IFLContracts

public struct CanonFinding: Hashable, Sendable {
    public let checkID: String
    public let severity: FindingSeverity
    public let message: String
    public let evidenceReferences: [String]

    init(
        checkID: String,
        severity: FindingSeverity,
        message: String,
        evidenceReferences: [String]
    ) {
        self.checkID = checkID
        self.severity = severity
        self.message = message
        self.evidenceReferences = Array(Set(evidenceReferences)).sorted(by: Self.utf8Less)
    }

    static func canonicalLess(_ lhs: Self, _ rhs: Self) -> Bool {
        if lhs.checkID != rhs.checkID {
            return utf8Less(lhs.checkID, rhs.checkID)
        }
        if lhs.message != rhs.message {
            return utf8Less(lhs.message, rhs.message)
        }
        return referencesLess(lhs.evidenceReferences, rhs.evidenceReferences)
    }

    private static func referencesLess(_ lhs: [String], _ rhs: [String]) -> Bool {
        for (left, right) in zip(lhs, rhs) where left != right {
            return utf8Less(left, right)
        }
        return lhs.count < rhs.count
    }

    private static func utf8Less(_ lhs: String, _ rhs: String) -> Bool {
        lhs.utf8.lexicographicallyPrecedes(rhs.utf8)
    }
}
