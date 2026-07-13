import Foundation

private enum CandidateOverlayWireSupport {
    static func slug(_ value: String, kind: String, field: String) throws -> String {
        try IFLCanonContractSupport.canonicalSlug(value, kind: kind, field: field)
    }

    static func nonBlank(_ value: String, kind: String, field: String) throws -> String {
        try IFLCanonContractSupport.nonBlank(value, kind: kind, field: field)
    }

    static func canonPath(
        _ value: String,
        kind: String,
        field: String,
        prefix: String,
        suffix: String
    ) throws -> String {
        let path = try CanonTargetPath(validating: value).rawValue
        let matchesFamily = switch (prefix, suffix) {
        case ("rules/", ".rules.json"):
            CandidateCanonPathGrammar.isRulePath(path)
        case ("chapters/", ".chapter.json"):
            CandidateCanonPathGrammar.isChapterPath(path)
        default:
            false
        }
        guard matchesFamily else {
            throw ContractError.invalidContract(kind: kind, reason: "\(field) has the wrong Canon family grammar")
        }
        return path
    }

    static func bundleID(_ value: String, kind: String, field: String) throws -> String {
        try slug(value, kind: kind, field: field)
    }

    static func canonicalArray<T: Equatable>(
        _ raw: [T],
        _ canonical: [T],
        kind: String,
        field: String
    ) throws {
        guard raw == canonical else {
            throw ContractError.invalidContract(kind: kind, reason: "\(field) must use canonical order")
        }
    }
}

public struct RuleOverlayBinding: Codable, Hashable, Sendable {
    public let id: RuleID
    public let reviewedComponentID: String
    public let bundleArtifactID: String
    public let bundlePublicationID: String
    public let targetRelativePath: String
    public let semanticDigest: HashDigest
    public let beforeFullDigest: HashDigest?
    public let candidateFullDigest: HashDigest

    public init(
        id: RuleID,
        reviewedComponentID: String,
        bundleArtifactID: String,
        bundlePublicationID: String,
        targetRelativePath: String,
        semanticDigest: HashDigest,
        beforeFullDigest: HashDigest?,
        candidateFullDigest: HashDigest
    ) throws {
        let kind = "rule_overlay_binding"
        self.id = try IFLCanonContractSupport.ruleID(id)
        self.reviewedComponentID = try CandidateOverlayWireSupport.slug(reviewedComponentID, kind: kind, field: "reviewed_component_id")
        self.bundleArtifactID = try CandidateOverlayWireSupport.bundleID(bundleArtifactID, kind: kind, field: "bundle_artifact_id")
        self.bundlePublicationID = try CandidateOverlayWireSupport.bundleID(bundlePublicationID, kind: kind, field: "bundle_publication_id")
        self.targetRelativePath = try CandidateOverlayWireSupport.canonPath(targetRelativePath, kind: kind, field: "target_relative_path", prefix: "rules/", suffix: ".rules.json")
        self.semanticDigest = try IFLCanonContractSupport.digest(semanticDigest)
        self.beforeFullDigest = try beforeFullDigest.map(IFLCanonContractSupport.digest)
        self.candidateFullDigest = try IFLCanonContractSupport.digest(candidateFullDigest)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case reviewedComponentID = "reviewed_component_id"
        case bundleArtifactID = "bundle_artifact_id"
        case bundlePublicationID = "bundle_publication_id"
        case targetRelativePath = "target_relative_path"
        case semanticDigest = "semantic_digest"
        case beforeFullDigest = "before_full_digest"
        case candidateFullDigest = "candidate_full_digest"
    }

    public init(from decoder: any Decoder) throws {
        let kind = "rule_overlay_binding"
        try IFLCanonContractSupport.rejectUnknownKeys(from: decoder, allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)), kind: kind)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: c.decode(RuleID.self, forKey: .id),
            reviewedComponentID: c.decode(String.self, forKey: .reviewedComponentID),
            bundleArtifactID: c.decode(String.self, forKey: .bundleArtifactID),
            bundlePublicationID: c.decode(String.self, forKey: .bundlePublicationID),
            targetRelativePath: c.decode(String.self, forKey: .targetRelativePath),
            semanticDigest: c.decode(HashDigest.self, forKey: .semanticDigest),
            beforeFullDigest: IFLCanonContractSupport.decodeOptionalRejectingNull(HashDigest.self, from: c, forKey: .beforeFullDigest, kind: kind, field: "before_full_digest"),
            candidateFullDigest: c.decode(HashDigest.self, forKey: .candidateFullDigest)
        )
    }
}

public struct ProfileOverlayBinding: Codable, Hashable, Sendable {
    public let id: ProfileID
    public let reviewedComponentID: String
    public let bundleArtifactID: String
    public let bundlePublicationID: String
    public let targetRelativePath: String
    public let candidateFullDigest: HashDigest
    public let orderedRuleIDs: [RuleID]

    public init(
        id: ProfileID,
        reviewedComponentID: String,
        bundleArtifactID: String,
        bundlePublicationID: String,
        targetRelativePath: String,
        candidateFullDigest: HashDigest,
        orderedRuleIDs: [RuleID]
    ) throws {
        let kind = "profile_overlay_binding"
        self.id = try IFLCanonContractSupport.profileID(id)
        self.reviewedComponentID = try CandidateOverlayWireSupport.slug(reviewedComponentID, kind: kind, field: "reviewed_component_id")
        self.bundleArtifactID = try CandidateOverlayWireSupport.bundleID(bundleArtifactID, kind: kind, field: "bundle_artifact_id")
        self.bundlePublicationID = try CandidateOverlayWireSupport.bundleID(bundlePublicationID, kind: kind, field: "bundle_publication_id")
        let path = try CanonTargetPath(validating: targetRelativePath).rawValue
        guard CandidateCanonPathGrammar.isProfilePath(path) else {
            throw ContractError.invalidContract(kind: kind, reason: "target_relative_path has the wrong profile grammar")
        }
        self.targetRelativePath = path
        self.candidateFullDigest = try IFLCanonContractSupport.digest(candidateFullDigest)
        try IFLCanonContractSupport.requireNonEmpty(orderedRuleIDs, kind: kind, field: "ordered_rule_ids")
        let rules = try orderedRuleIDs.map(IFLCanonContractSupport.ruleID)
        try IFLCanonContractSupport.requireUnique(rules, kind: "profile_rule", id: { $0.rawValue })
        self.orderedRuleIDs = rules
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case reviewedComponentID = "reviewed_component_id"
        case bundleArtifactID = "bundle_artifact_id"
        case bundlePublicationID = "bundle_publication_id"
        case targetRelativePath = "target_relative_path"
        case candidateFullDigest = "candidate_full_digest"
        case orderedRuleIDs = "ordered_rule_ids"
    }

    public init(from decoder: any Decoder) throws {
        let kind = "profile_overlay_binding"
        try IFLCanonContractSupport.rejectUnknownKeys(from: decoder, allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)), kind: kind)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: c.decode(ProfileID.self, forKey: .id),
            reviewedComponentID: c.decode(String.self, forKey: .reviewedComponentID),
            bundleArtifactID: c.decode(String.self, forKey: .bundleArtifactID),
            bundlePublicationID: c.decode(String.self, forKey: .bundlePublicationID),
            targetRelativePath: c.decode(String.self, forKey: .targetRelativePath),
            candidateFullDigest: c.decode(HashDigest.self, forKey: .candidateFullDigest),
            orderedRuleIDs: c.decode([RuleID].self, forKey: .orderedRuleIDs)
        )
    }
}

public struct ADROverlayBinding: Codable, Hashable, Sendable {
    public let id: ADRIdentifier
    public let reviewedComponentID: String
    public let metadataBundleArtifactID: String
    public let metadataBundlePublicationID: String
    public let metadataTargetRelativePath: String
    public let markdownBundleArtifactID: String
    public let markdownBundlePublicationID: String
    public let markdownTargetRelativePath: String
    public let semanticDigest: HashDigest
    public let beforeMetadataFullDigest: HashDigest?
    public let candidateMetadataFullDigest: HashDigest
    public let candidateMarkdownFullDigest: HashDigest

    public init(
        id: ADRIdentifier,
        reviewedComponentID: String,
        metadataBundleArtifactID: String,
        metadataBundlePublicationID: String,
        metadataTargetRelativePath: String,
        markdownBundleArtifactID: String,
        markdownBundlePublicationID: String,
        markdownTargetRelativePath: String,
        semanticDigest: HashDigest,
        beforeMetadataFullDigest: HashDigest?,
        candidateMetadataFullDigest: HashDigest,
        candidateMarkdownFullDigest: HashDigest
    ) throws {
        let kind = "adr_overlay_binding"
        self.id = try IFLCanonContractSupport.adrID(id)
        self.reviewedComponentID = try CandidateOverlayWireSupport.slug(reviewedComponentID, kind: kind, field: "reviewed_component_id")
        self.metadataBundleArtifactID = try CandidateOverlayWireSupport.bundleID(metadataBundleArtifactID, kind: kind, field: "metadata_bundle_artifact_id")
        self.metadataBundlePublicationID = try CandidateOverlayWireSupport.bundleID(metadataBundlePublicationID, kind: kind, field: "metadata_bundle_publication_id")
        self.markdownBundleArtifactID = try CandidateOverlayWireSupport.bundleID(markdownBundleArtifactID, kind: kind, field: "markdown_bundle_artifact_id")
        self.markdownBundlePublicationID = try CandidateOverlayWireSupport.bundleID(markdownBundlePublicationID, kind: kind, field: "markdown_bundle_publication_id")
        let metadataPath = try CanonTargetPath(validating: metadataTargetRelativePath).rawValue
        let markdownPath = try CanonTargetPath(validating: markdownTargetRelativePath).rawValue
        guard CandidateCanonPathGrammar.isADRPath(
            metadataPath,
            suffix: ".json",
            expectedID: self.id.rawValue
        ),
            CandidateCanonPathGrammar.isADRPath(
                markdownPath,
                suffix: ".md",
                expectedID: self.id.rawValue
            ),
            metadataPath.dropLast(5) == markdownPath.dropLast(3)
        else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "ADR target paths must form one ASCII ID-plus-slug metadata/Markdown basename pair"
            )
        }
        self.metadataTargetRelativePath = metadataPath
        self.markdownTargetRelativePath = markdownPath
        self.semanticDigest = try IFLCanonContractSupport.digest(semanticDigest)
        self.beforeMetadataFullDigest = try beforeMetadataFullDigest.map(IFLCanonContractSupport.digest)
        self.candidateMetadataFullDigest = try IFLCanonContractSupport.digest(candidateMetadataFullDigest)
        self.candidateMarkdownFullDigest = try IFLCanonContractSupport.digest(candidateMarkdownFullDigest)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case reviewedComponentID = "reviewed_component_id"
        case metadataBundleArtifactID = "metadata_bundle_artifact_id"
        case metadataBundlePublicationID = "metadata_bundle_publication_id"
        case metadataTargetRelativePath = "metadata_target_relative_path"
        case markdownBundleArtifactID = "markdown_bundle_artifact_id"
        case markdownBundlePublicationID = "markdown_bundle_publication_id"
        case markdownTargetRelativePath = "markdown_target_relative_path"
        case semanticDigest = "semantic_digest"
        case beforeMetadataFullDigest = "before_metadata_full_digest"
        case candidateMetadataFullDigest = "candidate_metadata_full_digest"
        case candidateMarkdownFullDigest = "candidate_markdown_full_digest"
    }

    public init(from decoder: any Decoder) throws {
        let kind = "adr_overlay_binding"
        try IFLCanonContractSupport.rejectUnknownKeys(from: decoder, allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)), kind: kind)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: c.decode(ADRIdentifier.self, forKey: .id),
            reviewedComponentID: c.decode(String.self, forKey: .reviewedComponentID),
            metadataBundleArtifactID: c.decode(String.self, forKey: .metadataBundleArtifactID),
            metadataBundlePublicationID: c.decode(String.self, forKey: .metadataBundlePublicationID),
            metadataTargetRelativePath: c.decode(String.self, forKey: .metadataTargetRelativePath),
            markdownBundleArtifactID: c.decode(String.self, forKey: .markdownBundleArtifactID),
            markdownBundlePublicationID: c.decode(String.self, forKey: .markdownBundlePublicationID),
            markdownTargetRelativePath: c.decode(String.self, forKey: .markdownTargetRelativePath),
            semanticDigest: c.decode(HashDigest.self, forKey: .semanticDigest),
            beforeMetadataFullDigest: IFLCanonContractSupport.decodeOptionalRejectingNull(HashDigest.self, from: c, forKey: .beforeMetadataFullDigest, kind: kind, field: "before_metadata_full_digest"),
            candidateMetadataFullDigest: c.decode(HashDigest.self, forKey: .candidateMetadataFullDigest),
            candidateMarkdownFullDigest: c.decode(HashDigest.self, forKey: .candidateMarkdownFullDigest)
        )
    }
}

public struct ChapterOverlayBinding: Codable, Hashable, Sendable {
    public let id: String
    public let reviewedComponentID: String
    public let bundleArtifactID: String
    public let bundlePublicationID: String
    public let targetRelativePath: String
    public let candidateFileDigest: HashDigest

    public init(id: String, reviewedComponentID: String, bundleArtifactID: String, bundlePublicationID: String, targetRelativePath: String, candidateFileDigest: HashDigest) throws {
        let kind = "chapter_overlay_binding"
        self.id = try CandidateOverlayWireSupport.slug(id, kind: kind, field: "id")
        self.reviewedComponentID = try CandidateOverlayWireSupport.slug(reviewedComponentID, kind: kind, field: "reviewed_component_id")
        self.bundleArtifactID = try CandidateOverlayWireSupport.bundleID(bundleArtifactID, kind: kind, field: "bundle_artifact_id")
        self.bundlePublicationID = try CandidateOverlayWireSupport.bundleID(bundlePublicationID, kind: kind, field: "bundle_publication_id")
        self.targetRelativePath = try CandidateOverlayWireSupport.canonPath(targetRelativePath, kind: kind, field: "target_relative_path", prefix: "chapters/", suffix: ".chapter.json")
        self.candidateFileDigest = try IFLCanonContractSupport.digest(candidateFileDigest)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case reviewedComponentID = "reviewed_component_id"
        case bundleArtifactID = "bundle_artifact_id"
        case bundlePublicationID = "bundle_publication_id"
        case targetRelativePath = "target_relative_path"
        case candidateFileDigest = "candidate_file_digest"
    }

    public init(from decoder: any Decoder) throws {
        let kind = "chapter_overlay_binding"
        try IFLCanonContractSupport.rejectUnknownKeys(from: decoder, allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)), kind: kind)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(id: c.decode(String.self, forKey: .id), reviewedComponentID: c.decode(String.self, forKey: .reviewedComponentID), bundleArtifactID: c.decode(String.self, forKey: .bundleArtifactID), bundlePublicationID: c.decode(String.self, forKey: .bundlePublicationID), targetRelativePath: c.decode(String.self, forKey: .targetRelativePath), candidateFileDigest: c.decode(HashDigest.self, forKey: .candidateFileDigest))
    }
}

public struct OptionalPublicationArtifactBinding: Codable, Hashable, Sendable {
    public let id: String
    public let reviewedComponentID: String
    public let bundleArtifactID: String
    public let candidateFileDigest: HashDigest
    public let bundlePublicationID: String?
    public let targetRelativePath: String?

    public init(
        id: String,
        reviewedComponentID: String,
        bundleArtifactID: String,
        candidateFileDigest: HashDigest,
        bundlePublicationID: String?,
        targetRelativePath: String?
    ) throws {
        let kind = "optional_publication_artifact_binding"
        self.id = try CandidateOverlayWireSupport.nonBlank(id, kind: kind, field: "id")
        self.reviewedComponentID = try CandidateOverlayWireSupport.slug(reviewedComponentID, kind: kind, field: "reviewed_component_id")
        self.bundleArtifactID = try CandidateOverlayWireSupport.bundleID(bundleArtifactID, kind: kind, field: "bundle_artifact_id")
        self.candidateFileDigest = try IFLCanonContractSupport.digest(candidateFileDigest)
        guard (bundlePublicationID == nil) == (targetRelativePath == nil) else {
            throw ContractError.invalidContract(kind: kind, reason: "bundle_publication_id and target_relative_path must be jointly present or absent")
        }
        self.bundlePublicationID = try bundlePublicationID.map { try CandidateOverlayWireSupport.bundleID($0, kind: kind, field: "bundle_publication_id") }
        self.targetRelativePath = try targetRelativePath.map { try PluginDerivedTargetPath(validating: $0).rawValue }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case reviewedComponentID = "reviewed_component_id"
        case bundleArtifactID = "bundle_artifact_id"
        case candidateFileDigest = "candidate_file_digest"
        case bundlePublicationID = "bundle_publication_id"
        case targetRelativePath = "target_relative_path"
    }

    public init(from decoder: any Decoder) throws {
        let kind = "optional_publication_artifact_binding"
        try IFLCanonContractSupport.rejectUnknownKeys(from: decoder, allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)), kind: kind)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: c.decode(String.self, forKey: .id),
            reviewedComponentID: c.decode(String.self, forKey: .reviewedComponentID),
            bundleArtifactID: c.decode(String.self, forKey: .bundleArtifactID),
            candidateFileDigest: c.decode(HashDigest.self, forKey: .candidateFileDigest),
            bundlePublicationID: IFLCanonContractSupport.decodeOptionalRejectingNull(String.self, from: c, forKey: .bundlePublicationID, kind: kind, field: "bundle_publication_id"),
            targetRelativePath: IFLCanonContractSupport.decodeOptionalRejectingNull(String.self, from: c, forKey: .targetRelativePath, kind: kind, field: "target_relative_path")
        )
    }
}

public struct RequirementRecordOverlayBinding: Codable, Hashable, Sendable {
    public let id: RequirementID
    public let beforeRequirementRecordDigest: HashDigest?
    public let beforeTraceabilityRecordDigest: HashDigest?
    public let candidateRequirementRecordDigest: HashDigest
    public let candidateTraceabilityRecordDigest: HashDigest

    public init(id: RequirementID, beforeRequirementRecordDigest: HashDigest?, beforeTraceabilityRecordDigest: HashDigest?, candidateRequirementRecordDigest: HashDigest, candidateTraceabilityRecordDigest: HashDigest) throws {
        self.id = try IFLCanonContractSupport.requirementID(id)
        self.beforeRequirementRecordDigest = try beforeRequirementRecordDigest.map(IFLCanonContractSupport.digest)
        self.beforeTraceabilityRecordDigest = try beforeTraceabilityRecordDigest.map(IFLCanonContractSupport.digest)
        self.candidateRequirementRecordDigest = try IFLCanonContractSupport.digest(candidateRequirementRecordDigest)
        self.candidateTraceabilityRecordDigest = try IFLCanonContractSupport.digest(candidateTraceabilityRecordDigest)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case beforeRequirementRecordDigest = "before_requirement_record_digest"
        case beforeTraceabilityRecordDigest = "before_traceability_record_digest"
        case candidateRequirementRecordDigest = "candidate_requirement_record_digest"
        case candidateTraceabilityRecordDigest = "candidate_traceability_record_digest"
    }

    public init(from decoder: any Decoder) throws {
        let kind = "requirement_record_overlay_binding"
        try IFLCanonContractSupport.rejectUnknownKeys(from: decoder, allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)), kind: kind)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: c.decode(RequirementID.self, forKey: .id),
            beforeRequirementRecordDigest: IFLCanonContractSupport.decodeOptionalRejectingNull(HashDigest.self, from: c, forKey: .beforeRequirementRecordDigest, kind: kind, field: "before_requirement_record_digest"),
            beforeTraceabilityRecordDigest: IFLCanonContractSupport.decodeOptionalRejectingNull(HashDigest.self, from: c, forKey: .beforeTraceabilityRecordDigest, kind: kind, field: "before_traceability_record_digest"),
            candidateRequirementRecordDigest: c.decode(HashDigest.self, forKey: .candidateRequirementRecordDigest),
            candidateTraceabilityRecordDigest: c.decode(HashDigest.self, forKey: .candidateTraceabilityRecordDigest)
        )
    }
}

public struct RequirementRegistryOverlayBinding: Codable, Hashable, Sendable {
    public let reviewedComponentID: String
    public let bundleArtifactID: String
    public let bundlePublicationID: String
    public let targetRelativePath: String
    public let beforeFullDigest: HashDigest?
    public let candidateFullDigest: HashDigest
    public let records: [RequirementRecordOverlayBinding]

    public init(reviewedComponentID: String, bundleArtifactID: String, bundlePublicationID: String, targetRelativePath: String, beforeFullDigest: HashDigest?, candidateFullDigest: HashDigest, records: [RequirementRecordOverlayBinding]) throws {
        let kind = "requirement_registry_overlay_binding"
        self.reviewedComponentID = try CandidateOverlayWireSupport.slug(reviewedComponentID, kind: kind, field: "reviewed_component_id")
        self.bundleArtifactID = try CandidateOverlayWireSupport.bundleID(bundleArtifactID, kind: kind, field: "bundle_artifact_id")
        self.bundlePublicationID = try CandidateOverlayWireSupport.bundleID(bundlePublicationID, kind: kind, field: "bundle_publication_id")
        guard targetRelativePath == "registry/requirements.v1.json" else {
            throw ContractError.invalidContract(kind: kind, reason: "target_relative_path must be registry/requirements.v1.json")
        }
        self.targetRelativePath = targetRelativePath
        self.beforeFullDigest = try beforeFullDigest.map(IFLCanonContractSupport.digest)
        self.candidateFullDigest = try IFLCanonContractSupport.digest(candidateFullDigest)
        try IFLCanonContractSupport.requireNonEmpty(records, kind: kind, field: "records")
        try IFLCanonContractSupport.requireUnique(records, kind: "requirement_record", id: { $0.id.rawValue })
        self.records = records.sorted { IFLCanonContractSupport.canonicalLess($0.id.rawValue, $1.id.rawValue) }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case reviewedComponentID = "reviewed_component_id"
        case bundleArtifactID = "bundle_artifact_id"
        case bundlePublicationID = "bundle_publication_id"
        case targetRelativePath = "target_relative_path"
        case beforeFullDigest = "before_full_digest"
        case candidateFullDigest = "candidate_full_digest"
        case records
    }

    public init(from decoder: any Decoder) throws {
        let kind = "requirement_registry_overlay_binding"
        try IFLCanonContractSupport.rejectUnknownKeys(from: decoder, allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)), kind: kind)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try c.decode([RequirementRecordOverlayBinding].self, forKey: .records)
        try self.init(
            reviewedComponentID: c.decode(String.self, forKey: .reviewedComponentID),
            bundleArtifactID: c.decode(String.self, forKey: .bundleArtifactID),
            bundlePublicationID: c.decode(String.self, forKey: .bundlePublicationID),
            targetRelativePath: c.decode(String.self, forKey: .targetRelativePath),
            beforeFullDigest: IFLCanonContractSupport.decodeOptionalRejectingNull(HashDigest.self, from: c, forKey: .beforeFullDigest, kind: kind, field: "before_full_digest"),
            candidateFullDigest: c.decode(HashDigest.self, forKey: .candidateFullDigest),
            records: raw
        )
        try CandidateOverlayWireSupport.canonicalArray(raw, records, kind: kind, field: "records")
    }
}

public struct IndexEntryOverlayBinding: Codable, Hashable, Sendable {
    public let id: String
    public let candidateRecordDigest: HashDigest

    public init(id: String, candidateRecordDigest: HashDigest) throws {
        self.id = try CandidateOverlayWireSupport.nonBlank(id, kind: "index_entry_overlay_binding", field: "id")
        self.candidateRecordDigest = try IFLCanonContractSupport.digest(candidateRecordDigest)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable { case id; case candidateRecordDigest = "candidate_record_digest" }
    public init(from decoder: any Decoder) throws {
        let kind = "index_entry_overlay_binding"
        try IFLCanonContractSupport.rejectUnknownKeys(from: decoder, allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)), kind: kind)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(id: c.decode(String.self, forKey: .id), candidateRecordDigest: c.decode(HashDigest.self, forKey: .candidateRecordDigest))
    }
}

public struct IndexOverlayBinding: Codable, Hashable, Sendable {
    public let id: String
    public let reviewedComponentID: String
    public let bundleArtifactID: String
    public let bundlePublicationID: String
    public let targetRelativePath: String
    public let beforeFullDigest: HashDigest?
    public let candidateFullDigest: HashDigest
    public let entries: [IndexEntryOverlayBinding]

    public init(id: String, reviewedComponentID: String, bundleArtifactID: String, bundlePublicationID: String, targetRelativePath: String, beforeFullDigest: HashDigest?, candidateFullDigest: HashDigest, entries: [IndexEntryOverlayBinding]) throws {
        let kind = "index_overlay_binding"
        self.id = try CandidateOverlayWireSupport.slug(id, kind: kind, field: "id")
        self.reviewedComponentID = try CandidateOverlayWireSupport.slug(reviewedComponentID, kind: kind, field: "reviewed_component_id")
        self.bundleArtifactID = try CandidateOverlayWireSupport.bundleID(bundleArtifactID, kind: kind, field: "bundle_artifact_id")
        self.bundlePublicationID = try CandidateOverlayWireSupport.bundleID(bundlePublicationID, kind: kind, field: "bundle_publication_id")
        let allowed = ["registry/rules.index.json", "registry/profiles.index.json", "registry/adrs.index.json", "registry/chapters.index.json", "registry/derived-artifacts.index.json"]
        guard allowed.contains(targetRelativePath) else {
            throw ContractError.invalidContract(kind: kind, reason: "target_relative_path is not a governed Canon index")
        }
        self.targetRelativePath = targetRelativePath
        self.beforeFullDigest = try beforeFullDigest.map(IFLCanonContractSupport.digest)
        self.candidateFullDigest = try IFLCanonContractSupport.digest(candidateFullDigest)
        try IFLCanonContractSupport.requireNonEmpty(entries, kind: kind, field: "entries")
        try IFLCanonContractSupport.requireUnique(entries, kind: "index_entry", id: \.id)
        self.entries = entries.sorted { IFLCanonContractSupport.canonicalLess($0.id, $1.id) }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case reviewedComponentID = "reviewed_component_id"
        case bundleArtifactID = "bundle_artifact_id"
        case bundlePublicationID = "bundle_publication_id"
        case targetRelativePath = "target_relative_path"
        case beforeFullDigest = "before_full_digest"
        case candidateFullDigest = "candidate_full_digest"
        case entries
    }

    public init(from decoder: any Decoder) throws {
        let kind = "index_overlay_binding"
        try IFLCanonContractSupport.rejectUnknownKeys(from: decoder, allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)), kind: kind)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try c.decode([IndexEntryOverlayBinding].self, forKey: .entries)
        try self.init(id: c.decode(String.self, forKey: .id), reviewedComponentID: c.decode(String.self, forKey: .reviewedComponentID), bundleArtifactID: c.decode(String.self, forKey: .bundleArtifactID), bundlePublicationID: c.decode(String.self, forKey: .bundlePublicationID), targetRelativePath: c.decode(String.self, forKey: .targetRelativePath), beforeFullDigest: IFLCanonContractSupport.decodeOptionalRejectingNull(HashDigest.self, from: c, forKey: .beforeFullDigest, kind: kind, field: "before_full_digest"), candidateFullDigest: c.decode(HashDigest.self, forKey: .candidateFullDigest), entries: raw)
        try CandidateOverlayWireSupport.canonicalArray(raw, entries, kind: kind, field: "entries")
    }
}

public struct DerivedTargetBinding: Codable, Hashable, Sendable {
    public let indexKey: String
    public let bundleArtifactID: String
    public let bundlePublicationID: String
    public let targetRelativePath: String
    public let candidateFileDigest: HashDigest

    public init(indexKey: String, bundleArtifactID: String, bundlePublicationID: String, targetRelativePath: String, candidateFileDigest: HashDigest) throws {
        let kind = "derived_target_binding"
        self.indexKey = try CandidateOverlayWireSupport.nonBlank(indexKey, kind: kind, field: "index_key")
        self.bundleArtifactID = try CandidateOverlayWireSupport.bundleID(bundleArtifactID, kind: kind, field: "bundle_artifact_id")
        self.bundlePublicationID = try CandidateOverlayWireSupport.bundleID(bundlePublicationID, kind: kind, field: "bundle_publication_id")
        self.targetRelativePath = try PluginDerivedTargetPath(validating: targetRelativePath).rawValue
        self.candidateFileDigest = try IFLCanonContractSupport.digest(candidateFileDigest)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case indexKey = "index_key"
        case bundleArtifactID = "bundle_artifact_id"
        case bundlePublicationID = "bundle_publication_id"
        case targetRelativePath = "target_relative_path"
        case candidateFileDigest = "candidate_file_digest"
    }

    public init(from decoder: any Decoder) throws {
        let kind = "derived_target_binding"
        try IFLCanonContractSupport.rejectUnknownKeys(from: decoder, allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)), kind: kind)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(indexKey: c.decode(String.self, forKey: .indexKey), bundleArtifactID: c.decode(String.self, forKey: .bundleArtifactID), bundlePublicationID: c.decode(String.self, forKey: .bundlePublicationID), targetRelativePath: c.decode(String.self, forKey: .targetRelativePath), candidateFileDigest: c.decode(HashDigest.self, forKey: .candidateFileDigest))
    }
}

public struct DerivedRegistrationOverlayBinding: Codable, Hashable, Sendable {
    public let deltaID: String
    public let reviewedComponentID: String
    public let bundleArtifactID: String
    public let candidateDeltaDigest: HashDigest
    public let targets: [DerivedTargetBinding]

    public init(deltaID: String, reviewedComponentID: String, bundleArtifactID: String, candidateDeltaDigest: HashDigest, targets: [DerivedTargetBinding]) throws {
        let kind = "derived_registration_overlay_binding"
        self.deltaID = try CandidateOverlayWireSupport.slug(deltaID, kind: kind, field: "delta_id")
        self.reviewedComponentID = try CandidateOverlayWireSupport.slug(reviewedComponentID, kind: kind, field: "reviewed_component_id")
        self.bundleArtifactID = try CandidateOverlayWireSupport.bundleID(bundleArtifactID, kind: kind, field: "bundle_artifact_id")
        self.candidateDeltaDigest = try IFLCanonContractSupport.digest(candidateDeltaDigest)
        try IFLCanonContractSupport.requireNonEmpty(targets, kind: kind, field: "targets")
        try IFLCanonContractSupport.requireUnique(targets, kind: "derived_target_index", id: \.indexKey)
        try IFLCanonContractSupport.requireUnique(targets, kind: "derived_target_path", id: \.targetRelativePath)
        self.targets = targets.sorted { IFLCanonContractSupport.canonicalLess($0.indexKey, $1.indexKey) }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case deltaID = "delta_id"
        case reviewedComponentID = "reviewed_component_id"
        case bundleArtifactID = "bundle_artifact_id"
        case candidateDeltaDigest = "candidate_delta_digest"
        case targets
    }

    public init(from decoder: any Decoder) throws {
        let kind = "derived_registration_overlay_binding"
        try IFLCanonContractSupport.rejectUnknownKeys(from: decoder, allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)), kind: kind)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try c.decode([DerivedTargetBinding].self, forKey: .targets)
        try self.init(deltaID: c.decode(String.self, forKey: .deltaID), reviewedComponentID: c.decode(String.self, forKey: .reviewedComponentID), bundleArtifactID: c.decode(String.self, forKey: .bundleArtifactID), candidateDeltaDigest: c.decode(HashDigest.self, forKey: .candidateDeltaDigest), targets: raw)
        try CandidateOverlayWireSupport.canonicalArray(raw, targets, kind: kind, field: "targets")
    }
}

public struct CandidateOverlayManifest: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let overlayID: String
    public let targetCanonVersion: Int
    public let targetProductVersion: String
    public let baseSnapshotContentDigest: HashDigest
    public let activationTransformIdentity: String
    public let activationTransformDigest: HashDigest
    public let reviewedComponents: [ReviewedComponentApproval]
    public let rules: [RuleOverlayBinding]
    public let profiles: [ProfileOverlayBinding]
    public let adrs: [ADROverlayBinding]
    public let chapters: [ChapterOverlayBinding]
    public let requirementRegistry: RequirementRegistryOverlayBinding
    public let checks: [OptionalPublicationArtifactBinding]
    public let fixtures: [OptionalPublicationArtifactBinding]
    public let migrations: [OptionalPublicationArtifactBinding]
    public let indexes: [IndexOverlayBinding]
    public let derivedRegistrationDeltas: [DerivedRegistrationOverlayBinding]
    public let activationTransformSet: ActivationTransformSet

    public init(
        schemaVersion: Int,
        overlayID: String,
        targetCanonVersion: Int,
        targetProductVersion: String,
        baseSnapshotContentDigest: HashDigest,
        activationTransformIdentity: String,
        activationTransformDigest: HashDigest,
        reviewedComponents: [ReviewedComponentApproval],
        rules: [RuleOverlayBinding],
        profiles: [ProfileOverlayBinding],
        adrs: [ADROverlayBinding],
        chapters: [ChapterOverlayBinding],
        requirementRegistry: RequirementRegistryOverlayBinding,
        checks: [OptionalPublicationArtifactBinding],
        fixtures: [OptionalPublicationArtifactBinding],
        migrations: [OptionalPublicationArtifactBinding],
        indexes: [IndexOverlayBinding],
        derivedRegistrationDeltas: [DerivedRegistrationOverlayBinding],
        activationTransformSet: ActivationTransformSet
    ) throws {
        let kind = "candidate_overlay_manifest"
        try IFLCanonContractSupport.validateSchemaVersion(schemaVersion, kind: kind)
        guard targetCanonVersion == 1 else { throw ContractError.unsupportedSchemaVersion(kind: "target_canon", value: targetCanonVersion) }
        let descriptor = CandidateOverlayTransformDescriptor.v1
        guard activationTransformIdentity == descriptor.identity else {
            throw ContractError.invalidContract(kind: kind, reason: "activation_transform_identity does not select the compiled v1 descriptor")
        }
        let transformDigest = try IFLCanonContractSupport.digest(activationTransformDigest)
        guard transformDigest == descriptor.digest else {
            throw ContractError.digestMismatch(kind: "candidate_overlay_transform", expected: descriptor.digest.rawValue, actual: transformDigest.rawValue)
        }
        for (field, values) in [
            ("reviewed_components", reviewedComponents as [Any]),
            ("rules", rules as [Any]),
            ("profiles", profiles as [Any]),
            ("adrs", adrs as [Any]),
            ("chapters", chapters as [Any]),
            ("checks", checks as [Any]),
            ("fixtures", fixtures as [Any]),
            ("migrations", migrations as [Any]),
            ("indexes", indexes as [Any]),
            ("derived_registration_deltas", derivedRegistrationDeltas as [Any]),
        ] {
            try IFLCanonContractSupport.requireNonEmpty(values, kind: kind, field: field)
        }
        try IFLCanonContractSupport.requireUnique(reviewedComponents, kind: "reviewed_component", id: \.componentID)
        try Self.validateGlobalReviewIdentifiers(reviewedComponents)
        try IFLCanonContractSupport.requireUnique(rules, kind: "rule_overlay", id: { $0.id.rawValue })
        try IFLCanonContractSupport.requireUnique(profiles, kind: "profile_overlay", id: { $0.id.rawValue })
        try IFLCanonContractSupport.requireUnique(adrs, kind: "adr_overlay", id: { $0.id.rawValue })
        try IFLCanonContractSupport.requireUnique(chapters, kind: "chapter_overlay", id: \.id)
        try IFLCanonContractSupport.requireUnique(indexes, kind: "index_overlay", id: \.id)
        try IFLCanonContractSupport.requireUnique(derivedRegistrationDeltas, kind: "derived_registration", id: \.deltaID)
        try IFLCanonContractSupport.requireUnique(checks, kind: "check_overlay", id: \.id)
        try IFLCanonContractSupport.requireUnique(fixtures, kind: "fixture_overlay", id: \.id)
        try IFLCanonContractSupport.requireUnique(migrations, kind: "migration_overlay", id: \.id)
        for check in checks {
            _ = try IFLCanonContractSupport.canonicalUppercaseIdentifier(check.id, prefix: "CHK-", kind: kind, field: "check_id")
        }
        for fixture in fixtures {
            _ = try IFLCanonContractSupport.canonicalUppercaseIdentifier(fixture.id, prefix: "FIX-", kind: kind, field: "fixture_id")
        }
        for migration in migrations {
            _ = try IFLCanonContractSupport.canonicalUppercaseIdentifier(migration.id, prefix: "MIG-", kind: kind, field: "migration_id")
        }

        let componentIDs = Set(reviewedComponents.map(\.componentID))
        let refs = rules.map(\.reviewedComponentID) + profiles.map(\.reviewedComponentID) + adrs.map(\.reviewedComponentID) + chapters.map(\.reviewedComponentID) + checks.map(\.reviewedComponentID) + fixtures.map(\.reviewedComponentID) + migrations.map(\.reviewedComponentID) + indexes.map(\.reviewedComponentID) + derivedRegistrationDeltas.map(\.reviewedComponentID) + [requirementRegistry.reviewedComponentID]
        for ref in refs where !componentIDs.contains(ref) {
            throw ContractError.unresolvedReference(kind: "reviewed_component", id: ref)
        }
        for componentID in componentIDs where !refs.contains(componentID) {
            throw ContractError.unresolvedReference(kind: "component_binding", id: componentID)
        }

        let ruleIDs = Set(rules.map(\.id))
        for profile in profiles {
            for id in profile.orderedRuleIDs where !ruleIDs.contains(id) {
                throw ContractError.unresolvedReference(kind: "profile_rule", id: id.rawValue)
            }
        }
        guard Set(activationTransformSet.rules.map(\.id)) == ruleIDs else { throw ContractError.invalidContract(kind: kind, reason: "Rule transforms must bijectively cover Rule bindings") }
        guard Set(activationTransformSet.adrs.map(\.id)) == Set(adrs.map(\.id)) else { throw ContractError.invalidContract(kind: kind, reason: "ADR transforms must bijectively cover ADR bindings") }
        guard Set(activationTransformSet.requirements.map(\.id)) == Set(requirementRegistry.records.map(\.id)) else { throw ContractError.invalidContract(kind: kind, reason: "Requirement transforms must bijectively cover registry records") }
        let indexKeys = Set(indexes.flatMap { index in index.entries.map { index.id + "\0" + $0.id } })
        guard Set(activationTransformSet.indexEntries.map { $0.indexID + "\0" + $0.entryID }) == indexKeys else { throw ContractError.invalidContract(kind: kind, reason: "index transforms must bijectively cover index entries") }
        let derivedKeys = Set(derivedRegistrationDeltas.flatMap { delta in delta.targets.map { delta.deltaID + "\0" + $0.indexKey } })
        guard Set(activationTransformSet.derivedPublications.map { $0.deltaID + "\0" + $0.indexKey }) == derivedKeys else { throw ContractError.invalidContract(kind: kind, reason: "derived transforms must bijectively cover derived targets") }

        try Self.validateIndexSources(activationTransformSet.indexEntries, rules: rules, profiles: profiles, adrs: adrs, chapters: chapters, derived: derivedRegistrationDeltas)
        try Self.validateDerivedTransforms(
            activationTransformSet.derivedPublications,
            indexTransforms: activationTransformSet.indexEntries,
            indexes: indexes,
            derived: derivedRegistrationDeltas
        )
        try Self.validatePhysicalClaims(rules: rules, profiles: profiles, adrs: adrs, chapters: chapters, requirementRegistry: requirementRegistry, checks: checks, fixtures: fixtures, migrations: migrations, indexes: indexes, derived: derivedRegistrationDeltas)

        self.schemaVersion = schemaVersion
        self.overlayID = try CandidateOverlayWireSupport.slug(overlayID, kind: kind, field: "overlay_id")
        self.targetCanonVersion = targetCanonVersion
        self.targetProductVersion = try IFLCanonContractSupport.semanticVersion(targetProductVersion, kind: kind, field: "target_product_version")
        self.baseSnapshotContentDigest = try IFLCanonContractSupport.digest(baseSnapshotContentDigest)
        self.activationTransformIdentity = activationTransformIdentity
        self.activationTransformDigest = transformDigest
        self.reviewedComponents = reviewedComponents.sorted { IFLCanonContractSupport.canonicalLess($0.componentID, $1.componentID) }
        self.rules = rules.sorted { IFLCanonContractSupport.canonicalLess($0.id.rawValue, $1.id.rawValue) }
        self.profiles = profiles.sorted { IFLCanonContractSupport.canonicalLess($0.id.rawValue, $1.id.rawValue) }
        self.adrs = adrs.sorted { IFLCanonContractSupport.canonicalLess($0.id.rawValue, $1.id.rawValue) }
        self.chapters = chapters.sorted { IFLCanonContractSupport.canonicalLess($0.id, $1.id) }
        self.requirementRegistry = requirementRegistry
        self.checks = checks.sorted { IFLCanonContractSupport.canonicalLess($0.id, $1.id) }
        self.fixtures = fixtures.sorted { IFLCanonContractSupport.canonicalLess($0.id, $1.id) }
        self.migrations = migrations.sorted { IFLCanonContractSupport.canonicalLess($0.id, $1.id) }
        self.indexes = indexes.sorted { IFLCanonContractSupport.canonicalLess($0.id, $1.id) }
        self.derivedRegistrationDeltas = derivedRegistrationDeltas.sorted { IFLCanonContractSupport.canonicalLess($0.deltaID, $1.deltaID) }
        self.activationTransformSet = activationTransformSet
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case overlayID = "overlay_id"
        case targetCanonVersion = "target_canon_version"
        case targetProductVersion = "target_product_version"
        case baseSnapshotContentDigest = "base_snapshot_content_digest"
        case activationTransformIdentity = "activation_transform_identity"
        case activationTransformDigest = "activation_transform_digest"
        case reviewedComponents = "reviewed_components"
        case rules, profiles, adrs, chapters
        case requirementRegistry = "requirement_registry"
        case checks, fixtures, migrations, indexes
        case derivedRegistrationDeltas = "derived_registration_deltas"
        case activationTransformSet = "activation_transform_set"
    }

    public init(from decoder: any Decoder) throws {
        let kind = "candidate_overlay_manifest"
        try IFLCanonContractSupport.rejectUnknownKeys(from: decoder, allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)), kind: kind)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let reviewed = try c.decode([ReviewedComponentApproval].self, forKey: .reviewedComponents)
        let rules = try c.decode([RuleOverlayBinding].self, forKey: .rules)
        let profiles = try c.decode([ProfileOverlayBinding].self, forKey: .profiles)
        let adrs = try c.decode([ADROverlayBinding].self, forKey: .adrs)
        let chapters = try c.decode([ChapterOverlayBinding].self, forKey: .chapters)
        let checks = try c.decode([OptionalPublicationArtifactBinding].self, forKey: .checks)
        let fixtures = try c.decode([OptionalPublicationArtifactBinding].self, forKey: .fixtures)
        let migrations = try c.decode([OptionalPublicationArtifactBinding].self, forKey: .migrations)
        let indexes = try c.decode([IndexOverlayBinding].self, forKey: .indexes)
        let derived = try c.decode([DerivedRegistrationOverlayBinding].self, forKey: .derivedRegistrationDeltas)
        try self.init(
            schemaVersion: c.decode(Int.self, forKey: .schemaVersion),
            overlayID: c.decode(String.self, forKey: .overlayID),
            targetCanonVersion: c.decode(Int.self, forKey: .targetCanonVersion),
            targetProductVersion: c.decode(String.self, forKey: .targetProductVersion),
            baseSnapshotContentDigest: c.decode(HashDigest.self, forKey: .baseSnapshotContentDigest),
            activationTransformIdentity: c.decode(String.self, forKey: .activationTransformIdentity),
            activationTransformDigest: c.decode(HashDigest.self, forKey: .activationTransformDigest),
            reviewedComponents: reviewed,
            rules: rules,
            profiles: profiles,
            adrs: adrs,
            chapters: chapters,
            requirementRegistry: c.decode(RequirementRegistryOverlayBinding.self, forKey: .requirementRegistry),
            checks: checks,
            fixtures: fixtures,
            migrations: migrations,
            indexes: indexes,
            derivedRegistrationDeltas: derived,
            activationTransformSet: c.decode(ActivationTransformSet.self, forKey: .activationTransformSet)
        )
        try CandidateOverlayWireSupport.canonicalArray(reviewed, reviewedComponents, kind: kind, field: "reviewed_components")
        try CandidateOverlayWireSupport.canonicalArray(rules, self.rules, kind: kind, field: "rules")
        try CandidateOverlayWireSupport.canonicalArray(profiles, self.profiles, kind: kind, field: "profiles")
        try CandidateOverlayWireSupport.canonicalArray(adrs, self.adrs, kind: kind, field: "adrs")
        try CandidateOverlayWireSupport.canonicalArray(chapters, self.chapters, kind: kind, field: "chapters")
        try CandidateOverlayWireSupport.canonicalArray(checks, self.checks, kind: kind, field: "checks")
        try CandidateOverlayWireSupport.canonicalArray(fixtures, self.fixtures, kind: kind, field: "fixtures")
        try CandidateOverlayWireSupport.canonicalArray(migrations, self.migrations, kind: kind, field: "migrations")
        try CandidateOverlayWireSupport.canonicalArray(indexes, self.indexes, kind: kind, field: "indexes")
        try CandidateOverlayWireSupport.canonicalArray(derived, derivedRegistrationDeltas, kind: kind, field: "derived_registration_deltas")
    }

    public static func overlayDigest(forCanonicalFileData data: Data) throws -> HashDigest {
        let manifest = try CanonicalJSON.decode(CandidateOverlayManifest.self, from: data)
        var canonical = try CanonicalJSON.encode(manifest)
        canonical.append(0x0A)
        guard canonical == data else {
            throw ContractError.invalidContract(kind: "candidate_overlay_manifest", reason: "manifest file must be canonical JSON followed by exactly one LF")
        }
        var payload = Data("ifl.candidate-overlay.manifest/v1\0".utf8)
        payload.append(data)
        return CanonicalTreeDigest.sha256(payload)
    }

    private static func validateIndexSources(_ transforms: [IndexEntryActivationTransform], rules: [RuleOverlayBinding], profiles: [ProfileOverlayBinding], adrs: [ADROverlayBinding], chapters: [ChapterOverlayBinding], derived: [DerivedRegistrationOverlayBinding]) throws {
        for transform in transforms {
            let matches: Bool = switch transform.sourceKind {
            case .ruleRecord:
                rules.contains { $0.id.rawValue == transform.sourceID && $0.targetRelativePath == transform.sourceRelativePath }
            case .profileRecord:
                profiles.contains { $0.id.rawValue == transform.sourceID && $0.targetRelativePath == transform.sourceRelativePath }
            case .adrMetadata:
                adrs.contains { $0.id.rawValue == transform.sourceID && $0.metadataTargetRelativePath == transform.sourceRelativePath }
            case .chapterMetadata:
                chapters.contains { $0.id == transform.sourceID && $0.targetRelativePath == transform.sourceRelativePath }
            case .derivedRegistrationEntry:
                derived.flatMap(\.targets).contains { $0.indexKey == transform.sourceID && $0.targetRelativePath == transform.sourceRelativePath }
            }
            guard matches else { throw ContractError.unresolvedReference(kind: "index_transform_source", id: transform.sourceID) }
        }
    }

    private static func validateDerivedTransforms(
        _ transforms: [DerivedPublicationTransform],
        indexTransforms: [IndexEntryActivationTransform],
        indexes: [IndexOverlayBinding],
        derived: [DerivedRegistrationOverlayBinding]
    ) throws {
        let derivedIndexes = indexes.filter {
            $0.targetRelativePath == "registry/derived-artifacts.index.json"
        }
        guard derivedIndexes.count == 1, let derivedIndex = derivedIndexes.first else {
            throw ContractError.unresolvedReference(
                kind: "derived_artifact_index",
                id: "registry/derived-artifacts.index.json"
            )
        }
        let derivedIndexEntryIDs = Set(derivedIndex.entries.map(\.id))
        let targets = derived.flatMap { delta in
            delta.targets.map { (delta.deltaID, $0) }
        }

        for transform in transforms {
            let matches = targets.filter {
                $0.0 == transform.deltaID && $0.1.indexKey == transform.indexKey
            }
            guard matches.count == 1, let target = matches.first?.1,
                  target.bundleArtifactID == transform.bundleArtifactID,
                  target.bundlePublicationID == transform.bundlePublicationID
            else { throw ContractError.unresolvedReference(kind: "derived_publication_transform", id: transform.deltaID + ":" + transform.indexKey) }

            let matchingIndexTransforms = indexTransforms.filter {
                $0.sourceKind == .derivedRegistrationEntry
                    && $0.indexID == derivedIndex.id
                    && $0.entryID == target.indexKey
                    && $0.sourceID == target.indexKey
                    && $0.sourceRelativePath == target.targetRelativePath
            }
            guard derivedIndexEntryIDs.contains(target.indexKey), matchingIndexTransforms.count == 1 else {
                throw ContractError.unresolvedReference(
                    kind: "derived_index_transform",
                    id: transform.deltaID + ":" + transform.indexKey
                )
            }
        }

        for indexTransform in indexTransforms where indexTransform.sourceKind == .derivedRegistrationEntry {
            let matchingTargets = targets.filter {
                $0.1.indexKey == indexTransform.sourceID
                    && $0.1.targetRelativePath == indexTransform.sourceRelativePath
            }
            guard indexTransform.indexID == derivedIndex.id,
                  indexTransform.entryID == indexTransform.sourceID,
                  matchingTargets.count == 1,
                  transforms.contains(where: {
                      $0.deltaID == matchingTargets[0].0
                          && $0.indexKey == matchingTargets[0].1.indexKey
                  })
            else {
                throw ContractError.unresolvedReference(
                    kind: "derived_publication_transform",
                    id: indexTransform.sourceID
                )
            }
        }
    }

    private static func validatePhysicalClaims(rules: [RuleOverlayBinding], profiles: [ProfileOverlayBinding], adrs: [ADROverlayBinding], chapters: [ChapterOverlayBinding], requirementRegistry: RequirementRegistryOverlayBinding, checks: [OptionalPublicationArtifactBinding], fixtures: [OptionalPublicationArtifactBinding], migrations: [OptionalPublicationArtifactBinding], indexes: [IndexOverlayBinding], derived: [DerivedRegistrationOverlayBinding]) throws {
        var artifacts: [String] = []
        var publications: [String] = []
        var publicationTargets: [String] = []
        func add(
            _ component: String,
            _ artifact: String,
            _ publication: String?,
            namespace: CandidateTargetNamespace? = nil,
            path: String? = nil
        ) {
            artifacts.append(component + "\0" + artifact)
            if let publication { publications.append(component + "\0" + publication) }
            if let namespace, let path {
                publicationTargets.append(namespace.rawValue + "\0" + path)
            }
        }
        for value in rules {
            add(value.reviewedComponentID, value.bundleArtifactID, value.bundlePublicationID, namespace: .canon, path: value.targetRelativePath)
        }
        for value in profiles {
            add(value.reviewedComponentID, value.bundleArtifactID, value.bundlePublicationID, namespace: .canon, path: value.targetRelativePath)
        }
        for value in adrs {
            add(value.reviewedComponentID, value.metadataBundleArtifactID, value.metadataBundlePublicationID, namespace: .canon, path: value.metadataTargetRelativePath)
            add(value.reviewedComponentID, value.markdownBundleArtifactID, value.markdownBundlePublicationID, namespace: .canon, path: value.markdownTargetRelativePath)
        }
        for value in chapters {
            add(value.reviewedComponentID, value.bundleArtifactID, value.bundlePublicationID, namespace: .canon, path: value.targetRelativePath)
        }
        add(requirementRegistry.reviewedComponentID, requirementRegistry.bundleArtifactID, requirementRegistry.bundlePublicationID, namespace: .canon, path: requirementRegistry.targetRelativePath)
        for value in checks + fixtures + migrations {
            add(value.reviewedComponentID, value.bundleArtifactID, value.bundlePublicationID, namespace: value.bundlePublicationID == nil ? nil : .pluginDerived, path: value.targetRelativePath)
        }
        for value in indexes {
            add(value.reviewedComponentID, value.bundleArtifactID, value.bundlePublicationID, namespace: .canon, path: value.targetRelativePath)
        }
        for delta in derived {
            add(delta.reviewedComponentID, delta.bundleArtifactID, nil)
            for target in delta.targets {
                add(delta.reviewedComponentID, target.bundleArtifactID, target.bundlePublicationID, namespace: .pluginDerived, path: target.targetRelativePath)
            }
        }
        try IFLCanonContractSupport.requireUnique(artifacts, kind: "manifest_bundle_artifact", id: { $0 })
        try IFLCanonContractSupport.requireUnique(publications, kind: "manifest_bundle_publication", id: { $0 })
        try IFLCanonContractSupport.requireUnique(
            publicationTargets,
            kind: "manifest_publication_target",
            id: { $0 }
        )
    }

    private static func validateGlobalReviewIdentifiers(
        _ reviewedComponents: [ReviewedComponentApproval]
    ) throws {
        var approvalIDs = Set<String>()
        var attestationIDs = Set<String>()
        for component in reviewedComponents {
            for approval in [
                component.accountableOwnerApproval,
                component.independentReviewerApproval,
            ] {
                guard approvalIDs.insert(approval.approvalID).inserted else {
                    throw ContractError.reusedIdentifier(kind: "approval", id: approval.approvalID)
                }
                guard attestationIDs.insert(approval.attestationID).inserted else {
                    throw ContractError.reusedIdentifier(kind: "attestation", id: approval.attestationID)
                }
            }
        }
    }
}
