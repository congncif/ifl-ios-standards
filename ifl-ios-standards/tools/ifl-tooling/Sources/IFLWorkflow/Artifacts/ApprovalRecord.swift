import Foundation
import IFLContracts

public struct ReviewedArtifact: Codable, Hashable, Sendable {
    public let artifactID: ArtifactID
    public let artifactHash: HashDigest

    public init(artifactID: ArtifactID, artifactHash: HashDigest) throws {
        self.artifactID = try ArtifactID(validating: artifactID.rawValue)
        do {
            self.artifactHash = try HashDigest(validating: artifactHash.rawValue)
        } catch {
            throw ArtifactError.invalidDigest
        }
    }

    public init(from decoder: any Decoder) throws {
        try artifactRejectUnknownFields(
            from: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            artifactID: container.decode(ArtifactID.self, forKey: .artifactID),
            artifactHash: container.decode(HashDigest.self, forKey: .artifactHash)
        )
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case artifactID = "artifact_id"
        case artifactHash = "artifact_hash"
    }
}

struct VerifiedReviewedArtifactSet: Hashable, Sendable {
    let gate: WorkflowStage
    let graphDigest: HashDigest
    let reviewedArtifacts: [ReviewedArtifact]
    let selectionPolicyDigest: HashDigest
    let bindingDigest: HashDigest

    static func derive(graph: ArtifactGraph, gate: WorkflowStage) throws -> Self {
        guard artifactApprovalGateStages.contains(gate) else {
            throw ArtifactError.invalidApproval
        }
        let graphDigest = try graph.canonicalDigest()
        let reviewed = try graph.artifacts.map {
            try ReviewedArtifact(artifactID: $0.id, artifactHash: $0.contentHash)
        }
        let selectionPolicyDigest = CanonicalTreeDigest.sha256(
            try CanonicalJSON.encode(
                ReviewedSelectionPolicyInput(
                    policy: "all_graph_artifacts",
                    gate: gate
                )
            )
        )
        let bindingDigest = CanonicalTreeDigest.sha256(
            try CanonicalJSON.encode(
                ReviewedSetBindingInput(
                    gate: gate,
                    graphDigest: graphDigest,
                    selectionPolicyDigest: selectionPolicyDigest,
                    reviewedArtifacts: reviewed
                )
            )
        )
        return Self(
            gate: gate,
            graphDigest: graphDigest,
            reviewedArtifacts: reviewed,
            selectionPolicyDigest: selectionPolicyDigest,
            bindingDigest: bindingDigest
        )
    }
}

struct ApprovalAuthoritySnapshot: Codable, Hashable, Sendable {
    let schemaVersion: Int
    let actorID: ActorID
    let principalID: PrincipalID
    let roles: [AuthorityRole]
    let principalKind: VerifiedPrincipalKind
    let independentContextDigest: HashDigest
    let hasAuthorshipEdge: Bool
    let hasSourceWriteCapability: Bool
    let snapshotDigest: HashDigest

    init(authorityFact: VerifiedAuthorityFact) throws {
        let roles = authorityFact.roles.sorted { $0.rawValue < $1.rawValue }
        guard !roles.isEmpty else { throw ArtifactError.invalidApproval }
        let input = ApprovalAuthoritySnapshotInput(
            actorID: authorityFact.actorID,
            principalID: authorityFact.principalID,
            roles: roles,
            principalKind: authorityFact.principalKind.rawValue,
            independentContextDigest: authorityFact.independentContextDigest,
            hasAuthorshipEdge: authorityFact.hasAuthorshipEdge,
            hasSourceWriteCapability: authorityFact.hasSourceWriteCapability
        )
        schemaVersion = 1
        actorID = try ActorID(validating: authorityFact.actorID.rawValue)
        principalID = try PrincipalID(validating: authorityFact.principalID.rawValue)
        self.roles = roles
        principalKind = authorityFact.principalKind
        independentContextDigest = try HashDigest(
            validating: authorityFact.independentContextDigest.rawValue
        )
        hasAuthorshipEdge = authorityFact.hasAuthorshipEdge
        hasSourceWriteCapability = authorityFact.hasSourceWriteCapability
        snapshotDigest = CanonicalTreeDigest.sha256(try CanonicalJSON.encode(input))
    }

    init(from decoder: any Decoder) throws {
        try artifactRejectUnknownFields(
            from: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .schemaVersion)
        guard version == 1 else { throw ArtifactError.invalidSchemaVersion(version) }
        let actorID = try container.decode(ActorID.self, forKey: .actorID)
        let principalID = try container.decode(PrincipalID.self, forKey: .principalID)
        let roles = try container.decode([AuthorityRole].self, forKey: .roles)
        let kindText = try container.decode(String.self, forKey: .principalKind)
        guard let principalKind = VerifiedPrincipalKind(rawValue: kindText),
              !roles.isEmpty,
              roles == roles.sorted(by: { $0.rawValue < $1.rawValue }),
              Set(roles).count == roles.count
        else { throw ArtifactError.invalidApproval }
        let independentContextDigest = try container.decode(
            HashDigest.self,
            forKey: .independentContextDigest
        )
        let hasAuthorshipEdge = try container.decode(Bool.self, forKey: .hasAuthorshipEdge)
        let hasSourceWriteCapability = try container.decode(
            Bool.self,
            forKey: .hasSourceWriteCapability
        )
        let snapshotDigest = try container.decode(HashDigest.self, forKey: .snapshotDigest)
        let input = ApprovalAuthoritySnapshotInput(
            actorID: actorID,
            principalID: principalID,
            roles: roles,
            principalKind: kindText,
            independentContextDigest: independentContextDigest,
            hasAuthorshipEdge: hasAuthorshipEdge,
            hasSourceWriteCapability: hasSourceWriteCapability
        )
        guard snapshotDigest == CanonicalTreeDigest.sha256(try CanonicalJSON.encode(input)) else {
            throw ArtifactError.invalidApproval
        }
        schemaVersion = 1
        self.actorID = actorID
        self.principalID = principalID
        self.roles = roles
        self.principalKind = principalKind
        self.independentContextDigest = independentContextDigest
        self.hasAuthorshipEdge = hasAuthorshipEdge
        self.hasSourceWriteCapability = hasSourceWriteCapability
        self.snapshotDigest = snapshotDigest
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(actorID, forKey: .actorID)
        try container.encode(principalID, forKey: .principalID)
        try container.encode(roles, forKey: .roles)
        try container.encode(principalKind.rawValue, forKey: .principalKind)
        try container.encode(independentContextDigest, forKey: .independentContextDigest)
        try container.encode(hasAuthorshipEdge, forKey: .hasAuthorshipEdge)
        try container.encode(hasSourceWriteCapability, forKey: .hasSourceWriteCapability)
        try container.encode(snapshotDigest, forKey: .snapshotDigest)
    }

    var authorityFact: VerifiedAuthorityFact {
        VerifiedAuthorityFact(
            actorID: actorID,
            principalID: principalID,
            roles: Set(roles),
            principalKind: principalKind,
            independentContextDigest: independentContextDigest,
            hasAuthorshipEdge: hasAuthorshipEdge,
            hasSourceWriteCapability: hasSourceWriteCapability
        )
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case actorID = "actor_id"
        case principalID = "principal_id"
        case roles
        case principalKind = "principal_kind"
        case independentContextDigest = "independent_context_digest"
        case hasAuthorshipEdge = "has_authorship_edge"
        case hasSourceWriteCapability = "has_source_write_capability"
        case snapshotDigest = "snapshot_digest"
    }
}

struct VerifiedApprovalPolicyBinding: Hashable, Sendable {
    let gate: WorkflowStage
    let mode: WorkflowMode
    let policyContext: ActivePolicyContext
    let escalationFlags: [AuthorityEscalationFlag]
    let authorityPolicyDigest: HashDigest
    let semanticPolicyDigest: HashDigest
    let requirementDigest: HashDigest
    let authorSnapshotDigest: HashDigest?
    let bindingDigest: HashDigest
    let requirement: GateAuthorityRequirement

    static func derive(
        gatePolicy: GatePolicy,
        gate: WorkflowStage,
        mode: WorkflowMode,
        policyContext: ActivePolicyContext,
        escalationFlags: Set<AuthorityEscalationFlag>,
        author: VerifiedAuthorityFact?
    ) throws -> Self {
        guard artifactApprovalGateStages.contains(gate) else {
            throw ArtifactError.invalidApproval
        }
        let semanticPolicyDigest = try semanticDigest(
            gatePolicy: gatePolicy,
            policyContext: policyContext
        )
        let requirement = try gatePolicy.authorityRequirement(
            stage: gate,
            mode: mode,
            context: policyContext,
            escalationFlags: escalationFlags
        )
        let requirementInput = ApprovalRequirementInput(requirement: requirement)
        let requirementDigest = CanonicalTreeDigest.sha256(
            try CanonicalJSON.encode(requirementInput)
        )
        let authorSnapshotDigest = try author.map {
            try ApprovalAuthoritySnapshot(authorityFact: $0).snapshotDigest
        }
        let sortedFlags = escalationFlags.sorted { $0.rawValue < $1.rawValue }
        let bindingDigest = CanonicalTreeDigest.sha256(
            try CanonicalJSON.encode(
                ApprovalPolicyBindingInput(
                    policyVersion: gatePolicy.policyVersion,
                    authorityPolicyDigest: gatePolicy.policyDigest,
                    semanticPolicyDigest: semanticPolicyDigest,
                    requirementDigest: requirementDigest,
                    gate: gate,
                    mode: mode,
                    profileID: policyContext.profileID,
                    profileDigest: policyContext.profileDigest,
                    riskClass: policyContext.riskClass,
                    escalationFlags: sortedFlags,
                    authorSnapshotDigest: authorSnapshotDigest
                )
            )
        )
        return Self(
            gate: gate,
            mode: mode,
            policyContext: policyContext,
            escalationFlags: sortedFlags,
            authorityPolicyDigest: gatePolicy.policyDigest,
            semanticPolicyDigest: semanticPolicyDigest,
            requirementDigest: requirementDigest,
            authorSnapshotDigest: authorSnapshotDigest,
            bindingDigest: bindingDigest,
            requirement: requirement
        )
    }

    private static func semanticDigest(
        gatePolicy: GatePolicy,
        policyContext: ActivePolicyContext
    ) throws -> HashDigest {
        var rows: [ApprovalSemanticPolicyRow] = []
        for gate in artifactApprovalGateStages {
            for mode in WorkflowMode.allCases {
                for riskClass in RiskClass.allCases {
                    for flags in approvalEscalationFlagCombinations() {
                        let context = try ActivePolicyContext(
                            profileID: policyContext.profileID,
                            profileDigest: policyContext.profileDigest,
                            riskClass: riskClass
                        )
                        let requirement = try gatePolicy.authorityRequirement(
                            stage: gate,
                            mode: mode,
                            context: context,
                            escalationFlags: flags
                        )
                        rows.append(
                            ApprovalSemanticPolicyRow(
                                gate: gate,
                                mode: mode,
                                riskClass: riskClass,
                                escalationFlags: flags.sorted { $0.rawValue < $1.rawValue },
                                requirement: ApprovalRequirementInput(requirement: requirement)
                            )
                        )
                    }
                }
            }
        }
        rows.sort { $0.sortKey < $1.sortKey }
        return CanonicalTreeDigest.sha256(
            try CanonicalJSON.encode(
                ApprovalSemanticPolicyInput(
                    policyVersion: gatePolicy.policyVersion,
                    profileID: policyContext.profileID,
                    profileDigest: policyContext.profileDigest,
                    rows: rows
                )
            )
        )
    }
}

public struct ApprovalRecord: Encodable, Hashable, Sendable {
    public let schemaVersion: Int
    public let gate: WorkflowStage
    public let kind: ApprovalKind
    public let actorID: ActorID
    public let principalID: PrincipalID
    public let role: AuthorityRole
    public let authorityPolicyDigest: HashDigest
    public let policyBindingDigest: HashDigest
    public let reviewedArtifacts: [ReviewedArtifact]
    public let reviewedSetDigest: HashDigest
    let authoritySnapshot: ApprovalAuthoritySnapshot
    public let timestamp: Date
    public let attestationReference: String

    private init(
        gate: WorkflowStage,
        kind: ApprovalKind,
        role: AuthorityRole,
        authorityPolicyDigest: HashDigest,
        policyBindingDigest: HashDigest,
        reviewedArtifacts: [ReviewedArtifact],
        reviewedSetDigest: HashDigest,
        authoritySnapshot: ApprovalAuthoritySnapshot,
        timestamp: Date,
        attestationReference: String
    ) throws {
        let sortedReviewed = reviewedArtifacts.sorted {
            $0.artifactID.rawValue < $1.artifactID.rawValue
        }
        guard artifactApprovalGateStages.contains(gate),
              !reviewedArtifacts.isEmpty,
              reviewedArtifacts == sortedReviewed,
              Set(reviewedArtifacts.map(\.artifactID)).count == reviewedArtifacts.count,
              authoritySnapshot.roles.contains(role),
              artifactIsNonBlank(attestationReference)
        else { throw ArtifactError.invalidApproval }
        schemaVersion = 1
        self.gate = gate
        self.kind = kind
        actorID = authoritySnapshot.actorID
        principalID = authoritySnapshot.principalID
        self.role = role
        self.authorityPolicyDigest = try HashDigest(
            validating: authorityPolicyDigest.rawValue
        )
        self.policyBindingDigest = try HashDigest(validating: policyBindingDigest.rawValue)
        self.reviewedArtifacts = reviewedArtifacts
        self.reviewedSetDigest = try HashDigest(validating: reviewedSetDigest.rawValue)
        self.authoritySnapshot = authoritySnapshot
        self.timestamp = try artifactCanonicalDate(timestamp)
        self.attestationReference = attestationReference
    }

    static func issue(
        gate: WorkflowStage,
        kind: ApprovalKind,
        role: AuthorityRole,
        authorityFact: VerifiedAuthorityFact,
        policyBinding: VerifiedApprovalPolicyBinding,
        reviewedSet: VerifiedReviewedArtifactSet,
        timestamp: Date,
        attestationReference: String
    ) throws -> ApprovalRecord {
        guard gate == policyBinding.gate,
              gate == reviewedSet.gate,
              authorityFact.roles.contains(role)
        else { throw ArtifactError.invalidApproval }
        return try ApprovalRecord(
            gate: gate,
            kind: kind,
            role: role,
            authorityPolicyDigest: policyBinding.authorityPolicyDigest,
            policyBindingDigest: policyBinding.bindingDigest,
            reviewedArtifacts: reviewedSet.reviewedArtifacts,
            reviewedSetDigest: reviewedSet.bindingDigest,
            authoritySnapshot: ApprovalAuthoritySnapshot(authorityFact: authorityFact),
            timestamp: timestamp,
            attestationReference: attestationReference
        )
    }

    public static func decodeCanonical(from bytes: Data) throws -> ApprovalRecord {
        let wire = try CanonicalJSON.decode(ApprovalRecordWire.self, from: bytes)
        let record = try ApprovalRecord(wire: wire)
        guard try CanonicalJSON.encode(record) == bytes else {
            throw ArtifactError.unexpectedFields
        }
        return record
    }

    public func encode(to encoder: any Encoder) throws {
        try ApprovalRecordWire(record: self).encode(to: encoder)
    }

    private init(wire: ApprovalRecordWire) throws {
        guard wire.actorID == wire.authoritySnapshot.actorID,
              wire.principalID == wire.authoritySnapshot.principalID
        else { throw ArtifactError.invalidApproval }
        let reviewed = try wire.reviewedArtifacts.map { key, hash in
            try ReviewedArtifact(
                artifactID: ArtifactID(validating: key),
                artifactHash: hash
            )
        }.sorted { $0.artifactID < $1.artifactID }
        try self.init(
            gate: wire.gate,
            kind: wire.kind,
            role: wire.role,
            authorityPolicyDigest: wire.authorityPolicyDigest,
            policyBindingDigest: wire.policyBindingDigest,
            reviewedArtifacts: reviewed,
            reviewedSetDigest: wire.reviewedSetDigest,
            authoritySnapshot: wire.authoritySnapshot,
            timestamp: wire.timestamp,
            attestationReference: wire.attestationReference
        )
    }
}

private struct ApprovalRecordWire: Codable {
    let schemaVersion: Int
    let gate: WorkflowStage
    let kind: ApprovalKind
    let actorID: ActorID
    let principalID: PrincipalID
    let role: AuthorityRole
    let authorityPolicyDigest: HashDigest
    let policyBindingDigest: HashDigest
    let reviewedArtifacts: [String: HashDigest]
    let reviewedSetDigest: HashDigest
    let authoritySnapshot: ApprovalAuthoritySnapshot
    let timestamp: Date
    let attestationReference: String

    init(record: ApprovalRecord) throws {
        let pairs = record.reviewedArtifacts.map {
            ($0.artifactID.rawValue, $0.artifactHash)
        }
        guard Dictionary(uniqueKeysWithValues: pairs).count == pairs.count else {
            throw ArtifactError.invalidApproval
        }
        schemaVersion = record.schemaVersion
        gate = record.gate
        kind = record.kind
        actorID = record.actorID
        principalID = record.principalID
        role = record.role
        authorityPolicyDigest = record.authorityPolicyDigest
        policyBindingDigest = record.policyBindingDigest
        reviewedArtifacts = Dictionary(uniqueKeysWithValues: pairs)
        reviewedSetDigest = record.reviewedSetDigest
        authoritySnapshot = record.authoritySnapshot
        timestamp = record.timestamp
        attestationReference = record.attestationReference
    }

    init(from decoder: any Decoder) throws {
        try artifactRejectUnknownFields(
            from: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == 1 else {
            throw ArtifactError.invalidSchemaVersion(schemaVersion)
        }
        gate = try container.decode(WorkflowStage.self, forKey: .gate)
        kind = try container.decode(ApprovalKind.self, forKey: .kind)
        actorID = try container.decode(ActorID.self, forKey: .actorID)
        principalID = try container.decode(PrincipalID.self, forKey: .principalID)
        role = try container.decode(AuthorityRole.self, forKey: .role)
        authorityPolicyDigest = try container.decode(
            HashDigest.self,
            forKey: .authorityPolicyDigest
        )
        policyBindingDigest = try container.decode(HashDigest.self, forKey: .policyBindingDigest)
        reviewedArtifacts = try container.decode(
            [String: HashDigest].self,
            forKey: .reviewedArtifacts
        )
        guard !reviewedArtifacts.isEmpty else { throw ArtifactError.invalidApproval }
        for key in reviewedArtifacts.keys { _ = try ArtifactID(validating: key) }
        reviewedSetDigest = try container.decode(HashDigest.self, forKey: .reviewedSetDigest)
        authoritySnapshot = try container.decode(
            ApprovalAuthoritySnapshot.self,
            forKey: .authoritySnapshot
        )
        let timestampText = try container.decode(String.self, forKey: .timestamp)
        timestamp = try artifactDecodeCanonicalDate(timestampText)
        attestationReference = try container.decode(String.self, forKey: .attestationReference)
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case gate
        case kind
        case actorID = "actor_id"
        case principalID = "principal_id"
        case role
        case authorityPolicyDigest = "authority_policy_digest"
        case policyBindingDigest = "policy_binding_digest"
        case reviewedArtifacts = "reviewed_artifacts"
        case reviewedSetDigest = "reviewed_set_digest"
        case authoritySnapshot = "authority_snapshot"
        case timestamp
        case attestationReference = "attestation_reference"
    }
}

enum ApprovalWireSemanticValidator {
    static func validate(_ bytes: Data) throws -> ApprovalRecord {
        try ApprovalRecord.decodeCanonical(from: bytes)
    }
}

let artifactApprovalGateStages: [WorkflowStage] = [
    .requirementGate,
    .designGate,
    .architectureGate,
    .planGate,
    .checkpoint,
    .review,
    .finalGate,
    .productReleaseGate,
]

private struct ReviewedSelectionPolicyInput: Codable {
    let schemaVersion = 1
    let policy: String
    let gate: WorkflowStage

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case policy
        case gate
    }
}

private struct ReviewedSetBindingInput: Codable {
    let schemaVersion = 1
    let gate: WorkflowStage
    let graphDigest: HashDigest
    let selectionPolicyDigest: HashDigest
    let reviewedArtifacts: [ReviewedArtifact]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case gate
        case graphDigest = "graph_digest"
        case selectionPolicyDigest = "selection_policy_digest"
        case reviewedArtifacts = "reviewed_artifacts"
    }
}

private struct ApprovalAuthoritySnapshotInput: Codable {
    let schemaVersion = 1
    let actorID: ActorID
    let principalID: PrincipalID
    let roles: [AuthorityRole]
    let principalKind: String
    let independentContextDigest: HashDigest
    let hasAuthorshipEdge: Bool
    let hasSourceWriteCapability: Bool

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case actorID = "actor_id"
        case principalID = "principal_id"
        case roles
        case principalKind = "principal_kind"
        case independentContextDigest = "independent_context_digest"
        case hasAuthorshipEdge = "has_authorship_edge"
        case hasSourceWriteCapability = "has_source_write_capability"
    }
}

private struct ApprovalRequirementInput: Codable, Hashable {
    let requiredRoles: [AuthorityRole]
    let enforcer: AuthorityEnforcer
    let requiresHuman: Bool
    let distinctPrincipalPolicy: DistinctPrincipalPolicy

    init(requirement: GateAuthorityRequirement) {
        requiredRoles = requirement.requiredRoles.sorted { $0.rawValue < $1.rawValue }
        enforcer = requirement.enforcer
        requiresHuman = requirement.requiresHuman
        distinctPrincipalPolicy = requirement.distinctPrincipalPolicy
    }

    enum CodingKeys: String, CodingKey {
        case requiredRoles = "required_roles"
        case enforcer
        case requiresHuman = "requires_human"
        case distinctPrincipalPolicy = "distinct_principal_policy"
    }
}

private struct ApprovalPolicyBindingInput: Codable {
    let schemaVersion = 1
    let policyVersion: Int
    let authorityPolicyDigest: HashDigest
    let semanticPolicyDigest: HashDigest
    let requirementDigest: HashDigest
    let gate: WorkflowStage
    let mode: WorkflowMode
    let profileID: ProfileID
    let profileDigest: HashDigest
    let riskClass: RiskClass
    let escalationFlags: [AuthorityEscalationFlag]
    let authorSnapshotDigest: HashDigest?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case policyVersion = "policy_version"
        case authorityPolicyDigest = "authority_policy_digest"
        case semanticPolicyDigest = "semantic_policy_digest"
        case requirementDigest = "requirement_digest"
        case gate
        case mode
        case profileID = "profile_id"
        case profileDigest = "profile_digest"
        case riskClass = "risk_class"
        case escalationFlags = "escalation_flags"
        case authorSnapshotDigest = "author_snapshot_digest"
    }
}

private struct ApprovalSemanticPolicyInput: Codable {
    let schemaVersion = 1
    let policyVersion: Int
    let profileID: ProfileID
    let profileDigest: HashDigest
    let rows: [ApprovalSemanticPolicyRow]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case policyVersion = "policy_version"
        case profileID = "profile_id"
        case profileDigest = "profile_digest"
        case rows
    }
}

private struct ApprovalSemanticPolicyRow: Codable {
    let gate: WorkflowStage
    let mode: WorkflowMode
    let riskClass: RiskClass
    let escalationFlags: [AuthorityEscalationFlag]
    let requirement: ApprovalRequirementInput

    var sortKey: String {
        [
            gate.rawValue,
            mode.rawValue,
            riskClass.rawValue,
            escalationFlags.map(\.rawValue).joined(separator: ","),
        ].joined(separator: "\u{0}")
    }

    enum CodingKeys: String, CodingKey {
        case gate
        case mode
        case riskClass = "risk_class"
        case escalationFlags = "escalation_flags"
        case requirement
    }
}

private func approvalEscalationFlagCombinations() -> [Set<AuthorityEscalationFlag>] {
    let flags = AuthorityEscalationFlag.allCases
    return (0 ..< (1 << flags.count)).map { mask in
        Set(flags.enumerated().compactMap { index, flag in
            mask & (1 << index) == 0 ? nil : flag
        })
    }
}

private func artifactCanonicalDate(_ value: Date) throws -> Date {
    guard value.timeIntervalSinceReferenceDate.isFinite else {
        throw ArtifactError.invalidApproval
    }
    do {
        let bytes = try CanonicalJSON.encode(value)
        let decoded = try CanonicalJSON.decode(Date.self, from: bytes)
        guard decoded == value else { throw ArtifactError.invalidApproval }
        return value
    } catch let error as ArtifactError {
        throw error
    } catch {
        throw ArtifactError.invalidApproval
    }
}

private func artifactDecodeCanonicalDate(_ value: String) throws -> Date {
    do {
        let encodedText = try CanonicalJSON.encode(value)
        let date = try CanonicalJSON.decode(Date.self, from: encodedText)
        let canonicalText = try CanonicalJSON.decode(
            String.self,
            from: CanonicalJSON.encode(date)
        )
        guard canonicalText == value else { throw ArtifactError.invalidApproval }
        return try artifactCanonicalDate(date)
    } catch let error as ArtifactError {
        throw error
    } catch {
        throw ArtifactError.invalidApproval
    }
}
