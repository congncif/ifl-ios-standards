import IFLContracts

public enum ArtifactRelation: String, Codable, CaseIterable, Hashable, Sendable {
    case derives
    case implements
    case validates
    case packages
}

public struct ArtifactDependency: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let upstreamArtifactID: ArtifactID
    public let upstreamHash: HashDigest
    public let downstreamArtifactID: ArtifactID
    public let downstreamHash: HashDigest
    public let relation: ArtifactRelation
    public let affectedScope: ArtifactScope
    public let requirementIDs: [RequirementID]
    public let ruleIDs: [RuleID]

    public init(
        upstreamArtifactID: ArtifactID,
        upstreamHash: HashDigest,
        downstreamArtifactID: ArtifactID,
        downstreamHash: HashDigest,
        relation: ArtifactRelation,
        affectedScope: ArtifactScope,
        requirementIDs: [RequirementID],
        ruleIDs: [RuleID]
    ) throws {
        let validatedUpstreamID = try ArtifactID(validating: upstreamArtifactID.rawValue)
        let validatedDownstreamID = try ArtifactID(validating: downstreamArtifactID.rawValue)
        guard validatedUpstreamID != validatedDownstreamID else {
            throw ArtifactError.invalidDependency
        }

        let validatedRequirements = try requirementIDs.map { requirementID in
            try RequirementID(validating: requirementID.rawValue)
        }
        let validatedRules = try ruleIDs.map { ruleID in
            try RuleID(validating: ruleID.rawValue)
        }
        guard !validatedRequirements.isEmpty,
              !validatedRules.isEmpty,
              Set(validatedRequirements).count == validatedRequirements.count,
              Set(validatedRules).count == validatedRules.count
        else { throw ArtifactError.missingTraceability }

        do {
            self.upstreamHash = try HashDigest(validating: upstreamHash.rawValue)
            self.downstreamHash = try HashDigest(validating: downstreamHash.rawValue)
        } catch {
            throw ArtifactError.invalidDigest
        }
        schemaVersion = 1
        self.upstreamArtifactID = validatedUpstreamID
        self.downstreamArtifactID = validatedDownstreamID
        self.relation = relation
        self.affectedScope = try ArtifactScope(
            kind: affectedScope.kind,
            value: affectedScope.value
        )
        self.requirementIDs = validatedRequirements.sorted { $0.rawValue < $1.rawValue }
        self.ruleIDs = validatedRules.sorted { $0.rawValue < $1.rawValue }
    }

    public init(from decoder: any Decoder) throws {
        try artifactRejectUnknownFields(
            from: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .schemaVersion)
        guard version == 1 else { throw ArtifactError.invalidSchemaVersion(version) }
        let decodedRequirements = try container.decode(
            [RequirementID].self,
            forKey: .requirementIDs
        )
        let decodedRules = try container.decode([RuleID].self, forKey: .ruleIDs)
        let validated = try ArtifactDependency(
            upstreamArtifactID: container.decode(ArtifactID.self, forKey: .upstreamArtifactID),
            upstreamHash: container.decode(HashDigest.self, forKey: .upstreamHash),
            downstreamArtifactID: container.decode(ArtifactID.self, forKey: .downstreamArtifactID),
            downstreamHash: container.decode(HashDigest.self, forKey: .downstreamHash),
            relation: container.decode(ArtifactRelation.self, forKey: .relation),
            affectedScope: container.decode(ArtifactScope.self, forKey: .affectedScope),
            requirementIDs: decodedRequirements,
            ruleIDs: decodedRules
        )
        guard decodedRequirements == validated.requirementIDs,
              decodedRules == validated.ruleIDs
        else { throw ArtifactError.invalidDependency }
        self = validated
    }

    var semanticKey: ArtifactDependencySemanticKey {
        ArtifactDependencySemanticKey(
            upstreamArtifactID: upstreamArtifactID,
            downstreamArtifactID: downstreamArtifactID,
            relation: relation,
            affectedScope: affectedScope
        )
    }

    var canonicalSortKey: String {
        [
            upstreamArtifactID.rawValue,
            downstreamArtifactID.rawValue,
            relation.rawValue,
            affectedScope.kind.rawValue,
            affectedScope.value,
            upstreamHash.rawValue,
            downstreamHash.rawValue,
            requirementIDs.map(\.rawValue).joined(separator: ","),
            ruleIDs.map(\.rawValue).joined(separator: ","),
        ].joined(separator: "\u{0}")
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case upstreamArtifactID = "upstream_artifact_id"
        case upstreamHash = "upstream_hash"
        case downstreamArtifactID = "downstream_artifact_id"
        case downstreamHash = "downstream_hash"
        case relation
        case affectedScope = "affected_scope"
        case requirementIDs = "requirement_ids"
        case ruleIDs = "rule_ids"
    }
}

struct ArtifactDependencySemanticKey: Hashable, Sendable {
    let upstreamArtifactID: ArtifactID
    let downstreamArtifactID: ArtifactID
    let relation: ArtifactRelation
    let affectedScope: ArtifactScope
}

public struct ArtifactDependencyObligation: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let upstreamArtifactID: ArtifactID
    public let upstreamHash: HashDigest
    public let downstreamArtifactID: ArtifactID
    public let downstreamHash: HashDigest
    public let relation: ArtifactRelation
    public let affectedScope: ArtifactScope
    public let requirementIDs: [RequirementID]
    public let ruleIDs: [RuleID]

    public init(
        upstreamArtifactID: ArtifactID,
        upstreamHash: HashDigest,
        downstreamArtifactID: ArtifactID,
        downstreamHash: HashDigest,
        relation: ArtifactRelation,
        affectedScope: ArtifactScope,
        requirementIDs: [RequirementID],
        ruleIDs: [RuleID]
    ) throws {
        let dependency = try ArtifactDependency(
            upstreamArtifactID: upstreamArtifactID,
            upstreamHash: upstreamHash,
            downstreamArtifactID: downstreamArtifactID,
            downstreamHash: downstreamHash,
            relation: relation,
            affectedScope: affectedScope,
            requirementIDs: requirementIDs,
            ruleIDs: ruleIDs
        )
        self.init(dependency: dependency)
    }

    public init(dependency: ArtifactDependency) {
        schemaVersion = 1
        upstreamArtifactID = dependency.upstreamArtifactID
        upstreamHash = dependency.upstreamHash
        downstreamArtifactID = dependency.downstreamArtifactID
        downstreamHash = dependency.downstreamHash
        relation = dependency.relation
        affectedScope = dependency.affectedScope
        requirementIDs = dependency.requirementIDs
        ruleIDs = dependency.ruleIDs
    }

    public init(from decoder: any Decoder) throws {
        try artifactRejectUnknownFields(
            from: decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .schemaVersion)
        guard version == 1 else { throw ArtifactError.invalidSchemaVersion(version) }
        let requirements = try container.decode([RequirementID].self, forKey: .requirementIDs)
        let rules = try container.decode([RuleID].self, forKey: .ruleIDs)
        let validated = try ArtifactDependencyObligation(
            upstreamArtifactID: container.decode(ArtifactID.self, forKey: .upstreamArtifactID),
            upstreamHash: container.decode(HashDigest.self, forKey: .upstreamHash),
            downstreamArtifactID: container.decode(ArtifactID.self, forKey: .downstreamArtifactID),
            downstreamHash: container.decode(HashDigest.self, forKey: .downstreamHash),
            relation: container.decode(ArtifactRelation.self, forKey: .relation),
            affectedScope: container.decode(ArtifactScope.self, forKey: .affectedScope),
            requirementIDs: requirements,
            ruleIDs: rules
        )
        guard requirements == validated.requirementIDs,
              rules == validated.ruleIDs
        else { throw ArtifactError.invalidObligation }
        self = validated
    }

    var dependency: ArtifactDependency {
        try! ArtifactDependency(
            upstreamArtifactID: upstreamArtifactID,
            upstreamHash: upstreamHash,
            downstreamArtifactID: downstreamArtifactID,
            downstreamHash: downstreamHash,
            relation: relation,
            affectedScope: affectedScope,
            requirementIDs: requirementIDs,
            ruleIDs: ruleIDs
        )
    }

    var canonicalSortKey: String { dependency.canonicalSortKey }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case upstreamArtifactID = "upstream_artifact_id"
        case upstreamHash = "upstream_hash"
        case downstreamArtifactID = "downstream_artifact_id"
        case downstreamHash = "downstream_hash"
        case relation
        case affectedScope = "affected_scope"
        case requirementIDs = "requirement_ids"
        case ruleIDs = "rule_ids"
    }
}
