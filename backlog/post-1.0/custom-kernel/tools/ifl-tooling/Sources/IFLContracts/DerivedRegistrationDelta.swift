public enum DerivedArtifactKind: String, Codable, CaseIterable, Hashable, Sendable {
    case constitution
    case rulebook
    case specification
    case compactReference = "compact_reference"
    case checklist
    case guide
    case skill
    case agent
    case template
    case scaffold
    case wrapper
    case processContract = "process_contract"
    case example
    case migrationGuide = "migration_guide"
}

public struct SourceSemanticBinding: Codable, Hashable, Sendable {
    public let sourceKind: String
    public let sourceID: String
    public let digest: HashDigest

    public init(sourceKind: String, sourceID: String, digest: HashDigest) throws {
        let kind = "source_semantic_binding"
        let validatedKind = try IFLCanonContractSupport.nonBlank(sourceKind, kind: kind, field: "source_kind")
        let validatedID = try IFLCanonContractSupport.nonBlank(sourceID, kind: kind, field: "source_id")
        switch validatedKind {
        case "rule":
            _ = try RuleID(validating: validatedID)
        case "profile":
            _ = try ProfileID(validating: validatedID)
        case "adr":
            _ = try ADRIdentifier(validating: validatedID)
        case "requirement":
            _ = try RequirementID(validating: validatedID)
        case "chapter":
            _ = try IFLCanonContractSupport.canonicalSlug(validatedID, kind: kind, field: "source_id")
        default:
            throw ContractError.invalidContract(
                kind: kind,
                reason: "source_kind must be one of rule, profile, adr, requirement, or chapter"
            )
        }
        self.sourceKind = validatedKind
        self.sourceID = validatedID
        self.digest = try IFLCanonContractSupport.digest(digest)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case sourceKind = "source_kind"
        case sourceID = "source_id"
        case digest
    }

    public init(from decoder: any Decoder) throws {
        let kind = "source_semantic_binding"
        try IFLCanonContractSupport.rejectUnknownKeys(
            from: decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: kind
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            sourceKind: container.decode(String.self, forKey: .sourceKind),
            sourceID: container.decode(String.self, forKey: .sourceID),
            digest: container.decode(HashDigest.self, forKey: .digest)
        )
    }
}

public struct DerivedRegistrationEntry: Codable, Hashable, Sendable {
    public let indexKey: String
    public let targetPath: String
    public let artifactKind: DerivedArtifactKind
    public let fileDigest: HashDigest
    public let citedRuleIDs: [RuleID]
    public let citedADRIDs: [ADRIdentifier]
    public let sourceSemanticBindings: [SourceSemanticBinding]

    public init(
        indexKey: String,
        targetPath: String,
        artifactKind: DerivedArtifactKind,
        fileDigest: HashDigest,
        citedRuleIDs: [RuleID],
        citedADRIDs: [ADRIdentifier],
        sourceSemanticBindings: [SourceSemanticBinding]
    ) throws {
        let kind = "derived_registration_entry"
        self.indexKey = try IFLCanonContractSupport.nonBlank(indexKey, kind: kind, field: "index_key")
        self.targetPath = try IFLCanonContractSupport.exactRelativePath(targetPath, kind: kind, field: "target_path")
        self.artifactKind = artifactKind
        self.fileDigest = try IFLCanonContractSupport.digest(fileDigest)

        let rules = try citedRuleIDs.map(IFLCanonContractSupport.ruleID)
        try IFLCanonContractSupport.requireUnique(rules, kind: "cited_rule", id: { $0.rawValue })
        self.citedRuleIDs = rules.sorted { IFLCanonContractSupport.canonicalLess($0.rawValue, $1.rawValue) }

        let adrs = try citedADRIDs.map(IFLCanonContractSupport.adrID)
        try IFLCanonContractSupport.requireUnique(adrs, kind: "cited_adr", id: { $0.rawValue })
        self.citedADRIDs = adrs.sorted { IFLCanonContractSupport.canonicalLess($0.rawValue, $1.rawValue) }

        try IFLCanonContractSupport.requireNonEmpty(
            sourceSemanticBindings,
            kind: kind,
            field: "source_semantic_bindings"
        )
        try IFLCanonContractSupport.requireUnique(
            sourceSemanticBindings,
            kind: "source_semantic_binding",
            id: { $0.sourceKind + "\u{0}" + $0.sourceID }
        )
        let sortedSources = sourceSemanticBindings.sorted {
            IFLCanonContractSupport.canonicalLess(
                $0.sourceKind + "\u{0}" + $0.sourceID,
                $1.sourceKind + "\u{0}" + $1.sourceID
            )
        }
        let citedRuleValues = Set(rules.map(\.rawValue))
        let boundRuleValues = Set(
            sortedSources
                .filter { $0.sourceKind == "rule" }
                .map(\.sourceID)
        )
        guard citedRuleValues == boundRuleValues else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "cited_rule_ids must exactly match rule source_semantic_bindings"
            )
        }
        let citedADRValues = Set(adrs.map(\.rawValue))
        let boundADRValues = Set(
            sortedSources
                .filter { $0.sourceKind == "adr" }
                .map(\.sourceID)
        )
        guard citedADRValues == boundADRValues else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "cited_adr_ids must exactly match adr source_semantic_bindings"
            )
        }
        self.sourceSemanticBindings = sortedSources
    }

    public init(
        indexKey: String,
        targetPath: String,
        artifactKind: String,
        fileDigest: HashDigest,
        citedRuleIDs: [RuleID],
        citedADRIDs: [ADRIdentifier],
        sourceSemanticBindings: [SourceSemanticBinding]
    ) throws {
        guard let validatedArtifactKind = DerivedArtifactKind(rawValue: artifactKind) else {
            throw ContractError.invalidContract(
                kind: "derived_registration_entry",
                reason: "artifact_kind must be a registered derived artifact kind"
            )
        }
        try self.init(
            indexKey: indexKey,
            targetPath: targetPath,
            artifactKind: validatedArtifactKind,
            fileDigest: fileDigest,
            citedRuleIDs: citedRuleIDs,
            citedADRIDs: citedADRIDs,
            sourceSemanticBindings: sourceSemanticBindings
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case indexKey = "index_key"
        case targetPath = "target_path"
        case artifactKind = "artifact_kind"
        case fileDigest = "file_digest"
        case citedRuleIDs = "cited_rule_ids"
        case citedADRIDs = "cited_adr_ids"
        case sourceSemanticBindings = "source_semantic_bindings"
    }

    public init(from decoder: any Decoder) throws {
        let kind = "derived_registration_entry"
        try IFLCanonContractSupport.rejectUnknownKeys(
            from: decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: kind
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawRules = try container.decode([RuleID].self, forKey: .citedRuleIDs)
        let rawADRs = try container.decode([ADRIdentifier].self, forKey: .citedADRIDs)
        let rawSources = try container.decode([SourceSemanticBinding].self, forKey: .sourceSemanticBindings)
        try self.init(
            indexKey: container.decode(String.self, forKey: .indexKey),
            targetPath: container.decode(String.self, forKey: .targetPath),
            artifactKind: container.decode(String.self, forKey: .artifactKind),
            fileDigest: container.decode(HashDigest.self, forKey: .fileDigest),
            citedRuleIDs: rawRules,
            citedADRIDs: rawADRs,
            sourceSemanticBindings: rawSources
        )
        guard rawRules == citedRuleIDs,
              rawADRs == citedADRIDs,
              rawSources == sourceSemanticBindings
        else {
            throw ContractError.invalidContract(kind: kind, reason: "arrays must use canonical order")
        }
    }
}

public struct DerivedRegistrationDelta: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let deltaID: String
    public let ownerRoleID: String
    public let baseSnapshotContentDigest: HashDigest
    public let entries: [DerivedRegistrationEntry]
    public let deltaDigest: HashDigest

    public init(
        schemaVersion: Int,
        deltaID: String,
        ownerRoleID: String,
        baseSnapshotContentDigest: HashDigest,
        entries: [DerivedRegistrationEntry]
    ) throws {
        let kind = "derived_registration_delta"
        try IFLCanonContractSupport.validateSchemaVersion(schemaVersion, kind: kind)
        let validatedDeltaID = try IFLCanonContractSupport.nonBlank(deltaID, kind: kind, field: "delta_id")
        let validatedOwner = try IFLCanonContractSupport.nonBlank(ownerRoleID, kind: kind, field: "owner_role_id")
        let validatedBaseDigest = try IFLCanonContractSupport.digest(baseSnapshotContentDigest)
        try IFLCanonContractSupport.requireNonEmpty(entries, kind: kind, field: "entries")
        try IFLCanonContractSupport.requireUnique(entries, kind: "derived_registration_index", id: { $0.indexKey })
        try IFLCanonContractSupport.requireUnique(entries, kind: "derived_registration_target", id: { $0.targetPath })
        let sortedEntries = entries.sorted {
            IFLCanonContractSupport.canonicalLess($0.targetPath, $1.targetPath)
        }

        self.schemaVersion = schemaVersion
        self.deltaID = validatedDeltaID
        self.ownerRoleID = validatedOwner
        self.baseSnapshotContentDigest = validatedBaseDigest
        self.entries = sortedEntries
        let payload = DerivedRegistrationDeltaDigestPayload(
            schemaVersion: schemaVersion,
            deltaID: validatedDeltaID,
            ownerRoleID: validatedOwner,
            baseSnapshotContentDigest: validatedBaseDigest,
            entries: sortedEntries
        )
        deltaDigest = try CanonicalTreeDigest.sha256(CanonicalJSON.encode(payload))
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case deltaID = "delta_id"
        case ownerRoleID = "owner_role_id"
        case baseSnapshotContentDigest = "base_snapshot_content_digest"
        case entries
        case deltaDigest = "delta_digest"
    }

    public init(from decoder: any Decoder) throws {
        let kind = "derived_registration_delta"
        try IFLCanonContractSupport.rejectUnknownKeys(
            from: decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: kind
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawEntries = try container.decode([DerivedRegistrationEntry].self, forKey: .entries)
        let suppliedDigest = try container.decode(HashDigest.self, forKey: .deltaDigest)
        try self.init(
            schemaVersion: container.decode(Int.self, forKey: .schemaVersion),
            deltaID: container.decode(String.self, forKey: .deltaID),
            ownerRoleID: container.decode(String.self, forKey: .ownerRoleID),
            baseSnapshotContentDigest: container.decode(HashDigest.self, forKey: .baseSnapshotContentDigest),
            entries: rawEntries
        )
        guard rawEntries == entries else {
            throw ContractError.invalidContract(kind: kind, reason: "entries must be sorted by target_path")
        }
        guard suppliedDigest == deltaDigest else {
            throw ContractError.digestMismatch(
                kind: kind,
                expected: deltaDigest.rawValue,
                actual: suppliedDigest.rawValue
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(deltaID, forKey: .deltaID)
        try container.encode(ownerRoleID, forKey: .ownerRoleID)
        try container.encode(baseSnapshotContentDigest, forKey: .baseSnapshotContentDigest)
        try container.encode(entries, forKey: .entries)
        try container.encode(deltaDigest, forKey: .deltaDigest)
    }
}

private struct DerivedRegistrationDeltaDigestPayload: Encodable {
    let schemaVersion: Int
    let deltaID: String
    let ownerRoleID: String
    let baseSnapshotContentDigest: HashDigest
    let entries: [DerivedRegistrationEntry]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case deltaID = "delta_id"
        case ownerRoleID = "owner_role_id"
        case baseSnapshotContentDigest = "base_snapshot_content_digest"
        case entries
    }
}
