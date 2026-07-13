import Foundation

public struct ActivationAffectedComponentReference: Codable, Hashable, Sendable {
    public let componentKind: String
    public let componentID: String

    public init(componentKind: String, componentID: String) throws {
        let kind = "activation_affected_component_reference"
        self.componentKind = try IFLCanonContractSupport.canonicalSlug(
            componentKind,
            kind: kind,
            field: "component_kind"
        )
        self.componentID = try IFLCanonContractSupport.canonicalSlug(
            componentID,
            kind: kind,
            field: "component_id"
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case componentKind = "component_kind"
        case componentID = "component_id"
    }

    public init(from decoder: any Decoder) throws {
        let kind = "activation_affected_component_reference"
        try IFLCanonContractSupport.rejectUnknownKeys(
            from: decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: kind
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            componentKind: container.decode(String.self, forKey: .componentKind),
            componentID: container.decode(String.self, forKey: .componentID)
        )
    }
}

public struct ActivationDigestTransition: Codable, Hashable, Sendable {
    public let targetNamespace: CandidateTargetNamespace
    public let targetRelativePath: String
    public let affectedComponents: [ActivationAffectedComponentReference]
    public let beforeEntry: CanonicalTreeEntry?
    public let afterEntry: CanonicalTreeEntry

    public init(
        targetNamespace: CandidateTargetNamespace,
        targetRelativePath: String,
        affectedComponents: [ActivationAffectedComponentReference],
        beforeEntry: CanonicalTreeEntry?,
        afterEntry: CanonicalTreeEntry
    ) throws {
        let kind = "activation_digest_transition"
        let target = try CandidateTargetPath.validating(
            namespace: targetNamespace,
            rawValue: targetRelativePath
        )
        let basename = target.rawValue.split(separator: "/").last.map(String.init) ?? target.rawValue
        guard !target.rawValue.hasPrefix("activations/"),
              !basename.hasSuffix(".approval.json"),
              !basename.hasSuffix(".receipt.json")
        else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "approval and activation artifacts are excluded from resolved transitions"
            )
        }
        try IFLCanonContractSupport.requireNonEmpty(
            affectedComponents,
            kind: kind,
            field: "affected_components"
        )
        try IFLCanonContractSupport.requireUnique(
            affectedComponents,
            kind: "activation_affected_component",
            id: { $0.componentKind + "\0" + $0.componentID }
        )
        guard afterEntry.relativePath == target.rawValue,
              beforeEntry?.relativePath == nil || beforeEntry?.relativePath == target.rawValue
        else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "before and after entries must use the transition target path"
            )
        }
        guard beforeEntry != afterEntry else {
            throw ContractError.invalidContract(kind: kind, reason: "before and after entries must differ")
        }
        try Self.validatePortableEntry(afterEntry, kind: kind)
        if let beforeEntry {
            try Self.validatePortableEntry(beforeEntry, kind: kind)
            guard beforeEntry.kind == .regularFile,
                  afterEntry.kind == .regularFile,
                  beforeEntry.mode == afterEntry.mode
            else {
                throw ContractError.invalidContract(
                    kind: kind,
                    reason: "an existing transition must retain a regular file and its exact mode"
                )
            }
        }

        self.targetNamespace = targetNamespace
        self.targetRelativePath = target.rawValue
        self.affectedComponents = affectedComponents.sorted {
            IFLCanonContractSupport.canonicalLess(
                $0.componentKind + "\0" + $0.componentID,
                $1.componentKind + "\0" + $1.componentID
            )
        }
        self.beforeEntry = beforeEntry
        self.afterEntry = afterEntry
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case targetNamespace = "target_namespace"
        case targetRelativePath = "target_relative_path"
        case affectedComponents = "affected_components"
        case beforeEntry = "before_entry"
        case afterEntry = "after_entry"
    }

    public init(from decoder: any Decoder) throws {
        let kind = "activation_digest_transition"
        try IFLCanonContractSupport.rejectUnknownKeys(
            from: decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: kind
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawComponents = try container.decode(
            [ActivationAffectedComponentReference].self,
            forKey: .affectedComponents
        )
        try self.init(
            targetNamespace: container.decode(CandidateTargetNamespace.self, forKey: .targetNamespace),
            targetRelativePath: container.decode(String.self, forKey: .targetRelativePath),
            affectedComponents: rawComponents,
            beforeEntry: IFLCanonContractSupport.decodeOptionalRejectingNull(
                CanonicalTreeEntry.self,
                from: container,
                forKey: .beforeEntry,
                kind: kind,
                field: "before_entry"
            ),
            afterEntry: container.decode(CanonicalTreeEntry.self, forKey: .afterEntry)
        )
        guard rawComponents == affectedComponents else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "affected_components must use canonical order"
            )
        }
    }

    private static func validatePortableEntry(
        _ entry: CanonicalTreeEntry,
        kind: String
    ) throws {
        guard entry.mode == CandidatePortableMode.file.rawValue
            || entry.mode == CandidatePortableMode.executable.rawValue
        else {
            throw ContractError.invalidContract(kind: kind, reason: "entry mode must be portable 420 or 493")
        }
        if entry.kind == .directory, entry.mode != CandidatePortableMode.executable.rawValue {
            throw ContractError.invalidContract(kind: kind, reason: "directory entries must use mode 493")
        }
    }
}

public struct CanonActivationReceipt: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let activationID: String
    public let transactionID: String
    public let targetCanonVersion: Int
    public let targetProductVersion: String
    public let overlayID: String
    public let overlayDigest: HashDigest
    public let integrationApproval: ReviewApprovalReference
    public let approvalSourceArtifactID: String
    public let approvalSourceArtifactDigest: HashDigest
    public let approvalSidecarRelativePath: String
    public let approvalSidecarDigest: HashDigest
    public let approvalTimestamp: Date
    public let activationTransformIdentity: String
    public let activationTransformDigest: HashDigest
    public let resolvedActivationDigest: HashDigest
    public let baseSnapshotContentDigest: HashDigest
    public let basePluginInventoryDigest: HashDigest
    public let resolvedPluginInventoryDigest: HashDigest
    public let publishedSnapshotContentDigest: HashDigest
    public let digestTransitions: [ActivationDigestTransition]

    public init(
        schemaVersion: Int,
        activationID: String,
        transactionID: String,
        targetCanonVersion: Int,
        targetProductVersion: String,
        overlayID: String,
        overlayDigest: HashDigest,
        integrationApproval: ReviewApprovalReference,
        approvalSourceArtifactID: String,
        approvalSourceArtifactDigest: HashDigest,
        approvalSidecarRelativePath: String,
        approvalSidecarDigest: HashDigest,
        approvalTimestamp: Date,
        activationTransformIdentity: String,
        activationTransformDigest: HashDigest,
        resolvedActivationDigest: HashDigest,
        baseSnapshotContentDigest: HashDigest,
        basePluginInventoryDigest: HashDigest,
        resolvedPluginInventoryDigest: HashDigest,
        publishedSnapshotContentDigest: HashDigest,
        digestTransitions: [ActivationDigestTransition]
    ) throws {
        let kind = "canon_activation_receipt"
        try IFLCanonContractSupport.validateSchemaVersion(schemaVersion, kind: kind)
        guard targetCanonVersion == 1 else {
            throw ContractError.unsupportedSchemaVersion(kind: "target_canon", value: targetCanonVersion)
        }
        let sidecarPath = try IFLCanonContractSupport.exactRelativePath(
            approvalSidecarRelativePath,
            kind: kind,
            field: "approval_sidecar_relative_path"
        )
        guard sidecarPath.hasPrefix("activations/"), sidecarPath.hasSuffix(".approval.json") else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "approval_sidecar_relative_path must identify an activation approval sidecar"
            )
        }
        let descriptor = CandidateOverlayTransformDescriptor.v1
        guard activationTransformIdentity == descriptor.identity else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "activation_transform_identity does not select the compiled v1 descriptor"
            )
        }
        let transformDigest = try IFLCanonContractSupport.digest(activationTransformDigest)
        guard transformDigest == descriptor.digest else {
            throw ContractError.digestMismatch(
                kind: "activation_transform",
                expected: descriptor.digest.rawValue,
                actual: transformDigest.rawValue
            )
        }
        let validatedOverlayID = try IFLCanonContractSupport.canonicalSlug(
            overlayID,
            kind: kind,
            field: "overlay_id"
        )
        let validatedOverlayDigest = try IFLCanonContractSupport.digest(overlayDigest)
        guard integrationApproval.reviewedComponentID == validatedOverlayID else {
            throw ContractError.unresolvedReference(kind: "integration_approval_overlay", id: validatedOverlayID)
        }
        guard integrationApproval.reviewedComponentDigest == validatedOverlayDigest else {
            throw ContractError.digestMismatch(
                kind: "integration_approval_overlay",
                expected: validatedOverlayDigest.rawValue,
                actual: integrationApproval.reviewedComponentDigest.rawValue
            )
        }
        let baseSnapshot = try IFLCanonContractSupport.digest(baseSnapshotContentDigest)
        let published = try IFLCanonContractSupport.digest(publishedSnapshotContentDigest)
        guard baseSnapshot != published else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "base and published snapshot content digests must differ"
            )
        }
        let basePlugin = try IFLCanonContractSupport.digest(basePluginInventoryDigest)
        let resolvedPlugin = try IFLCanonContractSupport.digest(resolvedPluginInventoryDigest)
        guard basePlugin != resolvedPlugin else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "base and resolved plugin inventory digests must differ"
            )
        }
        try IFLCanonContractSupport.requireNonEmpty(
            digestTransitions,
            kind: kind,
            field: "digest_transitions"
        )
        try IFLCanonContractSupport.requireUnique(
            digestTransitions,
            kind: "activation_transition_path",
            id: { $0.targetNamespace.rawValue + "\0" + $0.targetRelativePath }
        )

        self.schemaVersion = schemaVersion
        self.activationID = try IFLCanonContractSupport.nonBlank(activationID, kind: kind, field: "activation_id")
        self.transactionID = try IFLCanonContractSupport.nonBlank(transactionID, kind: kind, field: "transaction_id")
        self.targetCanonVersion = targetCanonVersion
        self.targetProductVersion = try IFLCanonContractSupport.semanticVersion(
            targetProductVersion,
            kind: kind,
            field: "target_product_version"
        )
        self.overlayID = validatedOverlayID
        self.overlayDigest = validatedOverlayDigest
        self.integrationApproval = integrationApproval
        self.approvalSourceArtifactID = try IFLCanonContractSupport.nonBlank(
            approvalSourceArtifactID,
            kind: kind,
            field: "approval_source_artifact_id"
        )
        self.approvalSourceArtifactDigest = try IFLCanonContractSupport.digest(approvalSourceArtifactDigest)
        self.approvalSidecarRelativePath = sidecarPath
        self.approvalSidecarDigest = try IFLCanonContractSupport.digest(approvalSidecarDigest)
        self.approvalTimestamp = try IFLCanonContractSupport.canonicalDate(
            approvalTimestamp,
            kind: kind,
            field: "approval_timestamp"
        )
        self.activationTransformIdentity = activationTransformIdentity
        self.activationTransformDigest = transformDigest
        self.resolvedActivationDigest = try IFLCanonContractSupport.digest(resolvedActivationDigest)
        self.baseSnapshotContentDigest = baseSnapshot
        self.basePluginInventoryDigest = basePlugin
        self.resolvedPluginInventoryDigest = resolvedPlugin
        self.publishedSnapshotContentDigest = published
        self.digestTransitions = digestTransitions.sorted {
            IFLCanonContractSupport.canonicalLess(
                $0.targetNamespace.rawValue + "\0" + $0.targetRelativePath,
                $1.targetNamespace.rawValue + "\0" + $1.targetRelativePath
            )
        }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case activationID = "activation_id"
        case transactionID = "transaction_id"
        case targetCanonVersion = "target_canon_version"
        case targetProductVersion = "target_product_version"
        case overlayID = "overlay_id"
        case overlayDigest = "overlay_digest"
        case integrationApproval = "integration_approval"
        case approvalSourceArtifactID = "approval_source_artifact_id"
        case approvalSourceArtifactDigest = "approval_source_artifact_digest"
        case approvalSidecarRelativePath = "approval_sidecar_relative_path"
        case approvalSidecarDigest = "approval_sidecar_digest"
        case approvalTimestamp = "approval_timestamp"
        case activationTransformIdentity = "activation_transform_identity"
        case activationTransformDigest = "activation_transform_digest"
        case resolvedActivationDigest = "resolved_activation_digest"
        case baseSnapshotContentDigest = "base_snapshot_content_digest"
        case basePluginInventoryDigest = "base_plugin_inventory_digest"
        case resolvedPluginInventoryDigest = "resolved_plugin_inventory_digest"
        case publishedSnapshotContentDigest = "published_snapshot_content_digest"
        case digestTransitions = "digest_transitions"
    }

    public init(from decoder: any Decoder) throws {
        let kind = "canon_activation_receipt"
        try IFLCanonContractSupport.rejectUnknownKeys(
            from: decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: kind
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let transitions = try c.decode([ActivationDigestTransition].self, forKey: .digestTransitions)
        try self.init(
            schemaVersion: c.decode(Int.self, forKey: .schemaVersion),
            activationID: c.decode(String.self, forKey: .activationID),
            transactionID: c.decode(String.self, forKey: .transactionID),
            targetCanonVersion: c.decode(Int.self, forKey: .targetCanonVersion),
            targetProductVersion: c.decode(String.self, forKey: .targetProductVersion),
            overlayID: c.decode(String.self, forKey: .overlayID),
            overlayDigest: c.decode(HashDigest.self, forKey: .overlayDigest),
            integrationApproval: c.decode(ReviewApprovalReference.self, forKey: .integrationApproval),
            approvalSourceArtifactID: c.decode(String.self, forKey: .approvalSourceArtifactID),
            approvalSourceArtifactDigest: c.decode(HashDigest.self, forKey: .approvalSourceArtifactDigest),
            approvalSidecarRelativePath: c.decode(String.self, forKey: .approvalSidecarRelativePath),
            approvalSidecarDigest: c.decode(HashDigest.self, forKey: .approvalSidecarDigest),
            approvalTimestamp: IFLCanonContractSupport.decodeCanonicalDate(
                from: c,
                forKey: .approvalTimestamp,
                kind: kind,
                field: "approval_timestamp"
            ),
            activationTransformIdentity: c.decode(String.self, forKey: .activationTransformIdentity),
            activationTransformDigest: c.decode(HashDigest.self, forKey: .activationTransformDigest),
            resolvedActivationDigest: c.decode(HashDigest.self, forKey: .resolvedActivationDigest),
            baseSnapshotContentDigest: c.decode(HashDigest.self, forKey: .baseSnapshotContentDigest),
            basePluginInventoryDigest: c.decode(HashDigest.self, forKey: .basePluginInventoryDigest),
            resolvedPluginInventoryDigest: c.decode(HashDigest.self, forKey: .resolvedPluginInventoryDigest),
            publishedSnapshotContentDigest: c.decode(HashDigest.self, forKey: .publishedSnapshotContentDigest),
            digestTransitions: transitions
        )
        guard transitions == digestTransitions else {
            throw ContractError.invalidContract(kind: kind, reason: "digest_transitions must use canonical order")
        }
    }
}
