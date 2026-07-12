import Foundation
import IFLContracts

public struct ReviewAssignmentID: RawRepresentable, Codable, Comparable, Hashable, Sendable {
    public let rawValue: String

    public init(validating rawValue: String) throws {
        guard WorkflowIdentifier.isValid(rawValue) else { throw WorkflowError.invalidIdentifier }
        self.rawValue = rawValue
    }

    public init?(rawValue: String) {
        guard let value = try? Self(validating: rawValue) else { return nil }
        self = value
    }

    public init(from decoder: any Decoder) throws {
        try self.init(validating: decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

public enum ReviewAssuranceClass: String, Codable, CaseIterable, Hashable, Sendable {
    case heightened
    case critical
}

public enum ReviewerIndependenceConstraint: String, Codable, CaseIterable, Hashable, Sendable {
    case distinctPrincipal = "distinct_principal"
    case noAuthorshipEdge = "no_authorship_edge"
    case noSourceWriteCapability = "no_source_write_capability"
}

public struct ReviewerAssignment: Codable, Hashable, Sendable {
    public let id: ReviewAssignmentID
    public let requiredRole: String
    public let assuranceClass: ReviewAssuranceClass
    public let independenceConstraints: [ReviewerIndependenceConstraint]
    public let checklistDigest: HashDigest
    public let redactionPolicy: RedactionPolicyBinding
    public let expectedActorID: ActorID
    public let expectedPrincipalID: PrincipalID
    public let evidenceKind: ReviewEvidenceKind

    public init(
        id: ReviewAssignmentID,
        requiredRole: String,
        assuranceClass: ReviewAssuranceClass,
        independenceConstraints: [ReviewerIndependenceConstraint],
        checklistDigest: HashDigest,
        redactionPolicy: RedactionPolicyBinding,
        expectedActorID: ActorID,
        expectedPrincipalID: PrincipalID,
        evidenceKind: ReviewEvidenceKind
    ) throws {
        let constraints = independenceConstraints.sorted { $0.rawValue < $1.rawValue }
        guard WorkflowIdentifier.isValid(requiredRole),
              AuthorityRole(rawValue: requiredRole) != nil,
              !constraints.isEmpty,
              Set(constraints).count == constraints.count,
              Set(constraints) == Set(ReviewerIndependenceConstraint.allCases)
        else { throw WorkflowPolicyError.invalidPolicy }
        self.id = id
        self.requiredRole = requiredRole
        self.assuranceClass = assuranceClass
        self.independenceConstraints = constraints
        self.checklistDigest = checklistDigest
        self.redactionPolicy = redactionPolicy
        self.expectedActorID = expectedActorID
        self.expectedPrincipalID = expectedPrincipalID
        self.evidenceKind = evidenceKind
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let decodedConstraints = try values.decode(
            [ReviewerIndependenceConstraint].self,
            forKey: .independenceConstraints
        )
        try self.init(
            id: values.decode(ReviewAssignmentID.self, forKey: .id),
            requiredRole: values.decode(String.self, forKey: .requiredRole),
            assuranceClass: values.decode(ReviewAssuranceClass.self, forKey: .assuranceClass),
            independenceConstraints: decodedConstraints,
            checklistDigest: values.decode(HashDigest.self, forKey: .checklistDigest),
            redactionPolicy: values.decode(RedactionPolicyBinding.self, forKey: .redactionPolicy),
            expectedActorID: values.decode(ActorID.self, forKey: .expectedActorID),
            expectedPrincipalID: values.decode(PrincipalID.self, forKey: .expectedPrincipalID),
            evidenceKind: values.decode(ReviewEvidenceKind.self, forKey: .evidenceKind)
        )
        guard decodedConstraints == independenceConstraints else {
            throw WorkflowPolicyError.invalidPolicy
        }
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case id = "assignment_id"
        case requiredRole = "required_role"
        case assuranceClass = "assurance_class"
        case independenceConstraints = "independence_constraints"
        case checklistDigest = "checklist_digest"
        case redactionPolicy = "redaction_policy"
        case expectedActorID = "expected_actor_id"
        case expectedPrincipalID = "expected_principal_id"
        case evidenceKind = "evidence_kind"
    }
}

public struct FrozenReviewerRoster: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let assignments: [ReviewerAssignment]
    public let redactionPolicy: RedactionPolicyBinding
    public let digest: HashDigest

    private init(
        assignments: [ReviewerAssignment],
        redactionPolicy: RedactionPolicyBinding,
        digest: HashDigest
    ) {
        schemaVersion = 1
        self.assignments = assignments
        self.redactionPolicy = redactionPolicy
        self.digest = digest
    }

    public static func freeze<S: Sequence>(
        assignments: S,
        redactionPolicy: RedactionPolicyBinding
    ) throws -> FrozenReviewerRoster where S.Element == ReviewerAssignment {
        let sorted = assignments.sorted { $0.id < $1.id }
        guard !sorted.isEmpty,
              Set(sorted.map(\.id)).count == sorted.count,
              Set(sorted.map(\.expectedActorID)).count == sorted.count,
              Set(sorted.map(\.expectedPrincipalID)).count == sorted.count,
              sorted.allSatisfy({
                  $0.redactionPolicy == redactionPolicy &&
                      $0.evidenceKind == .findingProducingReview
              })
        else { throw WorkflowPolicyError.invalidPolicy }
        let payload = FrozenReviewerRosterPayload(
            schemaVersion: 1,
            assignments: sorted,
            redactionPolicy: redactionPolicy
        )
        return FrozenReviewerRoster(
            assignments: sorted,
            redactionPolicy: redactionPolicy,
            digest: CanonicalTreeDigest.sha256(try CanonicalJSON.encode(payload))
        )
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard try values.decode(Int.self, forKey: .schemaVersion) == 1 else {
            throw WorkflowPolicyError.invalidPolicy
        }
        let decodedAssignments = try values.decode([ReviewerAssignment].self, forKey: .assignments)
        let decodedPolicy = try values.decode(RedactionPolicyBinding.self, forKey: .redactionPolicy)
        let decodedDigest = try values.decode(HashDigest.self, forKey: .digest)
        let frozen = try Self.freeze(assignments: decodedAssignments, redactionPolicy: decodedPolicy)
        guard frozen.assignments == decodedAssignments, frozen.digest == decodedDigest else {
            throw WorkflowPolicyError.invalidPolicy
        }
        self = frozen
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case assignments
        case redactionPolicy = "redaction_policy"
        case digest = "roster_digest"
    }
}

private struct FrozenReviewerRosterPayload: Codable {
    let schemaVersion: Int
    let assignments: [ReviewerAssignment]
    let redactionPolicy: RedactionPolicyBinding

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case assignments
        case redactionPolicy = "redaction_policy"
    }
}
