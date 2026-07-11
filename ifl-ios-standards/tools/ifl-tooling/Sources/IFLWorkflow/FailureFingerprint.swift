import IFLContracts

public struct FailureSemanticInput: Hashable, Sendable {
    public let schemaVersion: Int
    public let failingStage: WorkflowStage
    public let checkID: String
    public let invariantDigest: HashDigest
    public let expectedDigest: HashDigest
    public let actualDigest: HashDigest
    public let policyDigest: HashDigest
    public let relatedRuleIDs: [String]

    public init(
        schemaVersion: Int,
        failingStage: WorkflowStage,
        checkID: String,
        invariantDigest: HashDigest,
        expectedDigest: HashDigest,
        actualDigest: HashDigest,
        policyDigest: HashDigest,
        relatedRuleIDs: [String]
    ) throws {
        guard schemaVersion == 1,
              WorkflowIdentifier.isValid(checkID),
              !relatedRuleIDs.isEmpty,
              relatedRuleIDs.allSatisfy(WorkflowIdentifier.isValid)
        else { throw WorkflowPolicyError.invalidFingerprintInput }
        self.schemaVersion = schemaVersion
        self.failingStage = failingStage
        self.checkID = checkID
        self.invariantDigest = invariantDigest
        self.expectedDigest = expectedDigest
        self.actualDigest = actualDigest
        self.policyDigest = policyDigest
        self.relatedRuleIDs = Array(Set(relatedRuleIDs)).sorted()
    }
}

public struct FailureFingerprint: Hashable, Sendable {
    public let rawValue: String

    private init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(validatingWire rawValue: String) throws {
        self.rawValue = try HashDigest(validating: rawValue).rawValue
    }

    public static func derive(
        from input: FailureSemanticInput
    ) throws -> FailureFingerprint {
        let preimage = FailureFingerprintPreimage(
            schemaVersion: input.schemaVersion,
            failingStage: input.failingStage,
            checkID: input.checkID,
            invariantDigest: input.invariantDigest,
            expectedDigest: input.expectedDigest,
            actualDigest: input.actualDigest,
            policyDigest: input.policyDigest,
            relatedRuleIDs: input.relatedRuleIDs
        )
        return FailureFingerprint(
            rawValue: CanonicalTreeDigest.sha256(try CanonicalJSON.encode(preimage)).rawValue
        )
    }
}

public struct ReviewerInventoryFingerprint: Hashable, Sendable {
    public let rawValue: String

    private init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static func derive(
        roundID: ReviewRoundID,
        reviewerPrincipalID: PrincipalID,
        baselineDigest: HashDigest,
        assignmentDigest: HashDigest,
        findings: [FailureFingerprint]
    ) throws -> ReviewerInventoryFingerprint {
        let preimage = ReviewerInventoryFingerprintPreimage(
            schemaVersion: 1,
            roundID: roundID,
            reviewerPrincipalID: reviewerPrincipalID,
            baselineDigest: baselineDigest,
            assignmentDigest: assignmentDigest,
            findingFingerprints: Array(Set(findings.map(\.rawValue))).sorted()
        )
        return ReviewerInventoryFingerprint(
            rawValue: CanonicalTreeDigest.sha256(try CanonicalJSON.encode(preimage)).rawValue
        )
    }
}

public struct ReviewerDeliveryIdentity: Hashable, Sendable {
    public let rawValue: String

    private init(rawValue: String) {
        self.rawValue = rawValue
    }

    static func derive(
        roundID: ReviewRoundID,
        baselineDigest: HashDigest,
        assignmentDigest: HashDigest,
        inventoryFingerprint: ReviewerInventoryFingerprint
    ) throws -> ReviewerDeliveryIdentity {
        let preimage = ReviewerDeliveryIdentityPreimage(
            schemaVersion: 1,
            roundID: roundID,
            baselineDigest: baselineDigest,
            assignmentDigest: assignmentDigest,
            inventoryFingerprint: inventoryFingerprint.rawValue
        )
        return ReviewerDeliveryIdentity(
            rawValue: CanonicalTreeDigest.sha256(try CanonicalJSON.encode(preimage)).rawValue
        )
    }
}

public struct ReviewerDeliveryAttempt: Hashable, Sendable {
    public let identity: ReviewerDeliveryIdentity
    public let roundID: ReviewRoundID
    public let baselineDigest: HashDigest
    public let assignmentDigest: HashDigest
    public let inventoryFingerprint: ReviewerInventoryFingerprint

    init(
        identity: ReviewerDeliveryIdentity,
        roundID: ReviewRoundID,
        baselineDigest: HashDigest,
        assignmentDigest: HashDigest,
        inventoryFingerprint: ReviewerInventoryFingerprint
    ) {
        self.identity = identity
        self.roundID = roundID
        self.baselineDigest = baselineDigest
        self.assignmentDigest = assignmentDigest
        self.inventoryFingerprint = inventoryFingerprint
    }

    public static func derive(
        roundID: ReviewRoundID,
        baselineDigest: HashDigest,
        assignmentDigest: HashDigest,
        inventoryFingerprint: ReviewerInventoryFingerprint
    ) throws -> ReviewerDeliveryAttempt {
        ReviewerDeliveryAttempt(
            identity: try ReviewerDeliveryIdentity.derive(
                roundID: roundID,
                baselineDigest: baselineDigest,
                assignmentDigest: assignmentDigest,
                inventoryFingerprint: inventoryFingerprint
            ),
            roundID: roundID,
            baselineDigest: baselineDigest,
            assignmentDigest: assignmentDigest,
            inventoryFingerprint: inventoryFingerprint
        )
    }

    var hasCanonicalIdentity: Bool {
        guard let expected = try? ReviewerDeliveryIdentity.derive(
            roundID: roundID,
            baselineDigest: baselineDigest,
            assignmentDigest: assignmentDigest,
            inventoryFingerprint: inventoryFingerprint
        ) else { return false }
        return identity == expected
    }
}

private struct FailureFingerprintPreimage: Codable {
    let schemaVersion: Int
    let failingStage: WorkflowStage
    let checkID: String
    let invariantDigest: HashDigest
    let expectedDigest: HashDigest
    let actualDigest: HashDigest
    let policyDigest: HashDigest
    let relatedRuleIDs: [String]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case failingStage = "failing_stage"
        case checkID = "check_id"
        case invariantDigest = "invariant_digest"
        case expectedDigest = "expected_digest"
        case actualDigest = "actual_digest"
        case policyDigest = "policy_digest"
        case relatedRuleIDs = "related_rule_ids"
    }
}

private struct ReviewerInventoryFingerprintPreimage: Codable {
    let schemaVersion: Int
    let roundID: ReviewRoundID
    let reviewerPrincipalID: PrincipalID
    let baselineDigest: HashDigest
    let assignmentDigest: HashDigest
    let findingFingerprints: [String]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case roundID = "round_id"
        case reviewerPrincipalID = "reviewer_principal_id"
        case baselineDigest = "baseline_digest"
        case assignmentDigest = "assignment_digest"
        case findingFingerprints = "finding_fingerprints"
    }
}

private struct ReviewerDeliveryIdentityPreimage: Codable {
    let schemaVersion: Int
    let roundID: ReviewRoundID
    let baselineDigest: HashDigest
    let assignmentDigest: HashDigest
    let inventoryFingerprint: String

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case roundID = "round_id"
        case baselineDigest = "baseline_digest"
        case assignmentDigest = "assignment_digest"
        case inventoryFingerprint = "inventory_fingerprint"
    }
}
