import Foundation

public struct CandidateOverlayTransformDescriptor: Sendable {
    public static let v1 = CandidateOverlayTransformDescriptor()

    public let schemaVersion = 1
    public let identity = "urn:ifl:standards:canon-activation-transform:v1"
    public let overlaySchemaIdentity = "urn:ifl:standards:schema:candidate-overlay:v1"
    public let overlaySchemaDigest = HashDigest(
        uncheckedLowercaseSHA256: "0fdd05841617ce9578e8fdac4922f94eefc23ea822b169526d5e087f7a1980cf"
    )
    public let componentBundleSchemaIdentity = ComponentBundleSchemaIdentity.v1
    public let componentBundleSchemaDigest = ComponentBundleSchemaIdentity.v1.schemaDigest
    public let publicationAuthorityMapIdentity = CandidatePublicationAuthorityMap.v1.identity
    public let publicationAuthorityMapDigest = CandidatePublicationAuthorityMap.v1.digest
    public let pathNamespacePolicy = "canon-and-plugin-derived-exact-paths/v1"
    public let publicationModePolicy = "portable-modes-420-493/v1"
    public let mutationPolicy = "no-delete-no-existing-chmod/v1"
    public let canonSnapshotContentPolicyVersion = 1
    public let fullPluginInventoryPolicyVersion = 1
    public let transformAlgorithmVersion = 1
    public let digest = HashDigest(
        uncheckedLowercaseSHA256: "4f4c9dee027c5f91ef68e9a8c25697c10d1a0e1b40ea9cf6f45b215d61c924a0"
    )

    private init() {}

    public func canonicalFileData() throws -> Data {
        var data = try CanonicalJSON.encode(DescriptorWire(
            canonSnapshotContentPolicyVersion: canonSnapshotContentPolicyVersion,
            componentBundleSchemaDigest: componentBundleSchemaDigest,
            componentBundleSchemaIdentity: componentBundleSchemaIdentity,
            fullPluginInventoryPolicyVersion: fullPluginInventoryPolicyVersion,
            identity: identity,
            mutationPolicy: mutationPolicy,
            overlaySchemaDigest: overlaySchemaDigest,
            overlaySchemaIdentity: overlaySchemaIdentity,
            pathNamespacePolicy: pathNamespacePolicy,
            publicationAuthorityMapDigest: publicationAuthorityMapDigest,
            publicationAuthorityMapIdentity: publicationAuthorityMapIdentity,
            publicationModePolicy: publicationModePolicy,
            schemaVersion: schemaVersion,
            transformAlgorithmVersion: transformAlgorithmVersion
        ))
        data.append(0x0A)
        return data
    }
}

private struct DescriptorWire: Encodable {
    let canonSnapshotContentPolicyVersion: Int
    let componentBundleSchemaDigest: HashDigest
    let componentBundleSchemaIdentity: ComponentBundleSchemaIdentity
    let fullPluginInventoryPolicyVersion: Int
    let identity: String
    let mutationPolicy: String
    let overlaySchemaDigest: HashDigest
    let overlaySchemaIdentity: String
    let pathNamespacePolicy: String
    let publicationAuthorityMapDigest: HashDigest
    let publicationAuthorityMapIdentity: String
    let publicationModePolicy: String
    let schemaVersion: Int
    let transformAlgorithmVersion: Int

    private enum CodingKeys: String, CodingKey {
        case canonSnapshotContentPolicyVersion = "canon_snapshot_content_policy_version"
        case componentBundleSchemaDigest = "component_bundle_schema_digest"
        case componentBundleSchemaIdentity = "component_bundle_schema_identity"
        case fullPluginInventoryPolicyVersion = "full_plugin_inventory_policy_version"
        case identity
        case mutationPolicy = "mutation_policy"
        case overlaySchemaDigest = "overlay_schema_digest"
        case overlaySchemaIdentity = "overlay_schema_identity"
        case pathNamespacePolicy = "path_namespace_policy"
        case publicationAuthorityMapDigest = "publication_authority_map_digest"
        case publicationAuthorityMapIdentity = "publication_authority_map_identity"
        case publicationModePolicy = "publication_mode_policy"
        case schemaVersion = "schema_version"
        case transformAlgorithmVersion = "transform_algorithm_version"
    }
}

public enum RuleLifecycleSource: String, Codable, Hashable, Sendable {
    case constantActive = "constant_active"
}

public enum RuleEffectiveInSource: String, Codable, Hashable, Sendable {
    case targetProductVersion = "target_product_version"
}

public struct RuleActivationTransform: Codable, Hashable, Sendable {
    public let id: RuleID
    public let lifecycleSource: RuleLifecycleSource
    public let effectiveInSource: RuleEffectiveInSource

    public init(
        id: RuleID,
        lifecycleSource: RuleLifecycleSource,
        effectiveInSource: RuleEffectiveInSource
    ) throws {
        self.id = try IFLCanonContractSupport.ruleID(id)
        self.lifecycleSource = lifecycleSource
        self.effectiveInSource = effectiveInSource
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case lifecycleSource = "lifecycle_source"
        case effectiveInSource = "effective_in_source"
    }

    public init(from decoder: any Decoder) throws {
        try IFLCanonContractSupport.rejectUnknownKeys(
            from: decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: "rule_activation_transform"
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(RuleID.self, forKey: .id),
            lifecycleSource: container.decode(RuleLifecycleSource.self, forKey: .lifecycleSource),
            effectiveInSource: container.decode(RuleEffectiveInSource.self, forKey: .effectiveInSource)
        )
    }
}

public enum ADRStatusSource: String, Codable, Hashable, Sendable {
    case constantAccepted = "constant_accepted"
}

public enum ADRAcceptedAtSource: String, Codable, Hashable, Sendable {
    case integrationApprovalTimestamp = "integration_approval_timestamp"
}

public struct ADRActivationTransform: Codable, Hashable, Sendable {
    public let id: ADRIdentifier
    public let statusSource: ADRStatusSource
    public let acceptedAtSource: ADRAcceptedAtSource

    public init(
        id: ADRIdentifier,
        statusSource: ADRStatusSource,
        acceptedAtSource: ADRAcceptedAtSource
    ) throws {
        self.id = try IFLCanonContractSupport.adrID(id)
        self.statusSource = statusSource
        self.acceptedAtSource = acceptedAtSource
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case statusSource = "status_source"
        case acceptedAtSource = "accepted_at_source"
    }

    public init(from decoder: any Decoder) throws {
        try IFLCanonContractSupport.rejectUnknownKeys(
            from: decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: "adr_activation_transform"
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(ADRIdentifier.self, forKey: .id),
            statusSource: container.decode(ADRStatusSource.self, forKey: .statusSource),
            acceptedAtSource: container.decode(ADRAcceptedAtSource.self, forKey: .acceptedAtSource)
        )
    }
}

public struct RequirementActivationTransform: Codable, Hashable, Sendable {
    public let id: RequirementID
    public let targetStatus: RequirementStatus

    public init(id: RequirementID, targetStatus: RequirementStatus) throws {
        self.id = try IFLCanonContractSupport.requirementID(id)
        self.targetStatus = targetStatus
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case targetStatus = "target_status"
    }

    public init(from decoder: any Decoder) throws {
        try IFLCanonContractSupport.rejectUnknownKeys(
            from: decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: "requirement_activation_transform"
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(RequirementID.self, forKey: .id),
            targetStatus: container.decode(RequirementStatus.self, forKey: .targetStatus)
        )
    }
}

public enum IndexActivationSourceKind: String, Codable, CaseIterable, Hashable, Sendable {
    case ruleRecord = "rule_record"
    case profileRecord = "profile_record"
    case adrMetadata = "adr_metadata"
    case chapterMetadata = "chapter_metadata"
    case derivedRegistrationEntry = "derived_registration_entry"
}

public struct IndexEntryActivationTransform: Codable, Hashable, Sendable {
    public let indexID: String
    public let entryID: String
    public let sourceKind: IndexActivationSourceKind
    public let sourceID: String
    public let sourceRelativePath: String

    public init(
        indexID: String,
        entryID: String,
        sourceKind: IndexActivationSourceKind,
        sourceID: String,
        sourceRelativePath: String
    ) throws {
        let kind = "index_entry_activation_transform"
        self.indexID = try IFLCanonContractSupport.canonicalSlug(indexID, kind: kind, field: "index_id")
        self.entryID = try IFLCanonContractSupport.nonBlank(entryID, kind: kind, field: "entry_id")
        self.sourceKind = sourceKind
        switch sourceKind {
        case .ruleRecord:
            _ = try RuleID(validating: sourceID)
        case .profileRecord:
            _ = try ProfileID(validating: sourceID)
        case .adrMetadata:
            _ = try ADRIdentifier(validating: sourceID)
        case .chapterMetadata:
            _ = try IFLCanonContractSupport.canonicalSlug(sourceID, kind: kind, field: "source_id")
        case .derivedRegistrationEntry:
            _ = try IFLCanonContractSupport.nonBlank(sourceID, kind: kind, field: "source_id")
        }
        self.sourceID = sourceID
        self.sourceRelativePath = try IFLCanonContractSupport.exactRelativePath(
            sourceRelativePath,
            kind: kind,
            field: "source_relative_path"
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case indexID = "index_id"
        case entryID = "entry_id"
        case sourceKind = "source_kind"
        case sourceID = "source_id"
        case sourceRelativePath = "source_relative_path"
    }

    public init(from decoder: any Decoder) throws {
        let kind = "index_entry_activation_transform"
        try IFLCanonContractSupport.rejectUnknownKeys(
            from: decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: kind
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            indexID: container.decode(String.self, forKey: .indexID),
            entryID: container.decode(String.self, forKey: .entryID),
            sourceKind: container.decode(IndexActivationSourceKind.self, forKey: .sourceKind),
            sourceID: container.decode(String.self, forKey: .sourceID),
            sourceRelativePath: container.decode(String.self, forKey: .sourceRelativePath)
        )
    }
}

public struct DerivedPublicationTransform: Codable, Hashable, Sendable {
    public let deltaID: String
    public let indexKey: String
    public let bundleArtifactID: String
    public let bundlePublicationID: String

    public init(
        deltaID: String,
        indexKey: String,
        bundleArtifactID: String,
        bundlePublicationID: String
    ) throws {
        let kind = "derived_publication_transform"
        self.deltaID = try IFLCanonContractSupport.canonicalSlug(deltaID, kind: kind, field: "delta_id")
        self.indexKey = try IFLCanonContractSupport.nonBlank(indexKey, kind: kind, field: "index_key")
        self.bundleArtifactID = try IFLCanonContractSupport.canonicalSlug(
            bundleArtifactID,
            kind: kind,
            field: "bundle_artifact_id"
        )
        self.bundlePublicationID = try IFLCanonContractSupport.canonicalSlug(
            bundlePublicationID,
            kind: kind,
            field: "bundle_publication_id"
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case deltaID = "delta_id"
        case indexKey = "index_key"
        case bundleArtifactID = "bundle_artifact_id"
        case bundlePublicationID = "bundle_publication_id"
    }

    public init(from decoder: any Decoder) throws {
        let kind = "derived_publication_transform"
        try IFLCanonContractSupport.rejectUnknownKeys(
            from: decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: kind
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            deltaID: container.decode(String.self, forKey: .deltaID),
            indexKey: container.decode(String.self, forKey: .indexKey),
            bundleArtifactID: container.decode(String.self, forKey: .bundleArtifactID),
            bundlePublicationID: container.decode(String.self, forKey: .bundlePublicationID)
        )
    }
}

public struct ActivationTransformSet: Codable, Hashable, Sendable {
    public let rules: [RuleActivationTransform]
    public let adrs: [ADRActivationTransform]
    public let requirements: [RequirementActivationTransform]
    public let indexEntries: [IndexEntryActivationTransform]
    public let derivedPublications: [DerivedPublicationTransform]

    public init(
        rules: [RuleActivationTransform],
        adrs: [ADRActivationTransform],
        requirements: [RequirementActivationTransform],
        indexEntries: [IndexEntryActivationTransform],
        derivedPublications: [DerivedPublicationTransform]
    ) throws {
        let kind = "activation_transform_set"
        try IFLCanonContractSupport.requireNonEmpty(rules, kind: kind, field: "rules")
        try IFLCanonContractSupport.requireNonEmpty(adrs, kind: kind, field: "adrs")
        try IFLCanonContractSupport.requireNonEmpty(requirements, kind: kind, field: "requirements")
        try IFLCanonContractSupport.requireNonEmpty(indexEntries, kind: kind, field: "index_entries")
        try IFLCanonContractSupport.requireNonEmpty(
            derivedPublications,
            kind: kind,
            field: "derived_publications"
        )
        try IFLCanonContractSupport.requireUnique(rules, kind: "rule_transform", id: { $0.id.rawValue })
        try IFLCanonContractSupport.requireUnique(adrs, kind: "adr_transform", id: { $0.id.rawValue })
        try IFLCanonContractSupport.requireUnique(
            requirements,
            kind: "requirement_transform",
            id: { $0.id.rawValue }
        )
        try IFLCanonContractSupport.requireUnique(
            indexEntries,
            kind: "index_entry_transform",
            id: { $0.indexID + "\0" + $0.entryID }
        )
        try IFLCanonContractSupport.requireUnique(
            derivedPublications,
            kind: "derived_publication_transform",
            id: { $0.deltaID + "\0" + $0.indexKey }
        )
        self.rules = rules.sorted { IFLCanonContractSupport.canonicalLess($0.id.rawValue, $1.id.rawValue) }
        self.adrs = adrs.sorted { IFLCanonContractSupport.canonicalLess($0.id.rawValue, $1.id.rawValue) }
        self.requirements = requirements.sorted {
            IFLCanonContractSupport.canonicalLess($0.id.rawValue, $1.id.rawValue)
        }
        self.indexEntries = indexEntries.sorted {
            IFLCanonContractSupport.canonicalLess($0.indexID + "\0" + $0.entryID, $1.indexID + "\0" + $1.entryID)
        }
        self.derivedPublications = derivedPublications.sorted {
            IFLCanonContractSupport.canonicalLess($0.deltaID + "\0" + $0.indexKey, $1.deltaID + "\0" + $1.indexKey)
        }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case rules
        case adrs
        case requirements
        case indexEntries = "index_entries"
        case derivedPublications = "derived_publications"
    }

    public init(from decoder: any Decoder) throws {
        let kind = "activation_transform_set"
        try IFLCanonContractSupport.rejectUnknownKeys(
            from: decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: kind
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawRules = try container.decode([RuleActivationTransform].self, forKey: .rules)
        let rawADRs = try container.decode([ADRActivationTransform].self, forKey: .adrs)
        let rawRequirements = try container.decode(
            [RequirementActivationTransform].self,
            forKey: .requirements
        )
        let rawIndexEntries = try container.decode(
            [IndexEntryActivationTransform].self,
            forKey: .indexEntries
        )
        let rawDerived = try container.decode(
            [DerivedPublicationTransform].self,
            forKey: .derivedPublications
        )
        try self.init(
            rules: rawRules,
            adrs: rawADRs,
            requirements: rawRequirements,
            indexEntries: rawIndexEntries,
            derivedPublications: rawDerived
        )
        guard rawRules == rules,
              rawADRs == adrs,
              rawRequirements == requirements,
              rawIndexEntries == indexEntries,
              rawDerived == derivedPublications
        else {
            throw ContractError.invalidContract(kind: kind, reason: "transform arrays must use canonical order")
        }
    }
}
