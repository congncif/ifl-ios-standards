import IFLContracts

public enum EffectClass: String, Codable, CaseIterable, Sendable {
    case e0 = "E0"
    case e1 = "E1"
    case e2 = "E2"
    case e3 = "E3"
}

public struct ReleaseEffectTarget: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(validating rawValue: String) throws {
        guard WorkflowIdentifier.isValid(rawValue) else { throw WorkflowError.invalidIdentifier }
        self.rawValue = rawValue
    }

    public init?(rawValue: String) {
        guard WorkflowIdentifier.isValid(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    private init(knownValid rawValue: String) {
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        try self.init(validating: decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static let qualificationPayload = ReleaseEffectTarget(knownValid: "qualification_payload")
    public static let finalQualificationManifest = ReleaseEffectTarget(knownValid: "final_qualification_manifest")
    public static let finalQualificationSignature = ReleaseEffectTarget(knownValid: "final_qualification_signature")
    public static let distributionSHA256Sums = ReleaseEffectTarget(knownValid: "distribution_sha256sums")
    public static let terminalReport = ReleaseEffectTarget(knownValid: "terminal_report")
}

public struct ReleaseEffectRequest: Codable, Hashable, Sendable {
    public let effectClass: EffectClass
    public let target: ReleaseEffectTarget
    public let candidateGenerationID: CandidateGenerationID

    public init(
        effectClass: EffectClass,
        target: ReleaseEffectTarget,
        candidateGenerationID: CandidateGenerationID
    ) {
        self.effectClass = effectClass
        self.target = target
        self.candidateGenerationID = candidateGenerationID
    }
}
