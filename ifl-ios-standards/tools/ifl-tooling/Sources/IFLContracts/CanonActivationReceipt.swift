import Foundation

public struct ActivationDigestTransition: Codable, Hashable, Sendable {
    public let componentKind: String
    public let componentID: String
    public let relativePath: String
    public let beforeFullDigest: HashDigest?
    public let afterFullDigest: HashDigest

    public init(
        componentKind: String,
        componentID: String,
        relativePath: String,
        beforeFullDigest: HashDigest?,
        afterFullDigest: HashDigest
    ) throws {
        let kind = "activation_digest_transition"
        let validatedKind = try IFLCanonContractSupport.nonBlank(
            componentKind,
            kind: kind,
            field: "component_kind"
        )
        let validatedID = try Self.validateComponentID(
            componentID,
            for: validatedKind,
            contractKind: kind
        )
        let path = try IFLCanonContractSupport.exactRelativePath(
            relativePath,
            kind: kind,
            field: "relative_path"
        )
        let basename = path.split(
            separator: "/",
            omittingEmptySubsequences: false
        ).last.map(String.init) ?? path
        guard !path.hasPrefix("activations/"),
              !basename.hasSuffix(".approval.json"),
              !basename.hasSuffix(".receipt.json")
        else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "activation receipts and approval sidecars are excluded from snapshot transitions"
            )
        }
        let before = try beforeFullDigest.map(IFLCanonContractSupport.digest)
        let after = try IFLCanonContractSupport.digest(afterFullDigest)
        if let before, before == after {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "before and after digests must differ"
            )
        }

        self.componentKind = validatedKind
        self.componentID = validatedID
        self.relativePath = path
        self.beforeFullDigest = before
        self.afterFullDigest = after
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case componentKind = "component_kind"
        case componentID = "component_id"
        case relativePath = "relative_path"
        case beforeFullDigest = "before_full_digest"
        case afterFullDigest = "after_full_digest"
    }

    public init(from decoder: any Decoder) throws {
        let kind = "activation_digest_transition"
        try IFLCanonContractSupport.rejectUnknownKeys(
            from: decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: kind
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            componentKind: container.decode(String.self, forKey: .componentKind),
            componentID: container.decode(String.self, forKey: .componentID),
            relativePath: container.decode(String.self, forKey: .relativePath),
            beforeFullDigest: IFLCanonContractSupport.decodeOptionalRejectingNull(
                HashDigest.self,
                from: container,
                forKey: .beforeFullDigest,
                kind: kind,
                field: "before_full_digest"
            ),
            afterFullDigest: container.decode(HashDigest.self, forKey: .afterFullDigest)
        )
    }

    private static func validateComponentID(
        _ componentID: String,
        for componentKind: String,
        contractKind: String
    ) throws -> String {
        switch componentKind {
        case "rule":
            return try RuleID(validating: componentID).rawValue
        case "profile":
            return try ProfileID(validating: componentID).rawValue
        case "adr":
            return try ADRIdentifier(validating: componentID).rawValue
        case "requirement", "traceability", "requirement_traceability":
            return try RequirementID(validating: componentID).rawValue
        case "check":
            return try IFLCanonContractSupport.canonicalUppercaseIdentifier(
                componentID,
                prefix: "CHK-",
                kind: contractKind,
                field: "component_id"
            )
        case "fixture":
            return try IFLCanonContractSupport.canonicalUppercaseIdentifier(
                componentID,
                prefix: "FIX-",
                kind: contractKind,
                field: "component_id"
            )
        case "migration":
            return try IFLCanonContractSupport.canonicalUppercaseIdentifier(
                componentID,
                prefix: "MIG-",
                kind: contractKind,
                field: "component_id"
            )
        case "chapter", "index", "derived_registration":
            return try IFLCanonContractSupport.canonicalSlug(
                componentID,
                kind: contractKind,
                field: "component_id"
            )
        default:
            throw ContractError.invalidContract(
                kind: contractKind,
                reason: "component_kind is not a supported snapshot component kind"
            )
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
    public let baseSnapshotContentDigest: HashDigest
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
        baseSnapshotContentDigest: HashDigest,
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
        guard sidecarPath.hasPrefix("activations/"),
              sidecarPath.hasSuffix(".approval.json")
        else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "approval_sidecar_relative_path must identify an activation approval sidecar"
            )
        }
        try IFLCanonContractSupport.requireNonEmpty(
            digestTransitions,
            kind: kind,
            field: "digest_transitions"
        )
        try IFLCanonContractSupport.requireUnique(
            digestTransitions,
            kind: "activation_transition_component",
            id: { $0.componentKind + "\u{0}" + $0.componentID }
        )
        try IFLCanonContractSupport.requireUnique(
            digestTransitions,
            kind: "activation_transition_path",
            id: { $0.relativePath }
        )

        let validatedIntegrationApproval = try ReviewApprovalReference(
            schemaVersion: integrationApproval.schemaVersion,
            approvalID: integrationApproval.approvalID,
            principalID: integrationApproval.principalID,
            actorID: integrationApproval.actorID,
            roleID: integrationApproval.roleID,
            reviewedComponentID: integrationApproval.reviewedComponentID,
            reviewedComponentDigest: integrationApproval.reviewedComponentDigest,
            attestationID: integrationApproval.attestationID,
            attestationDigest: integrationApproval.attestationDigest
        )
        let validatedOverlayID = try IFLCanonContractSupport.nonBlank(
            overlayID,
            kind: kind,
            field: "overlay_id"
        )
        let validatedOverlayDigest = try IFLCanonContractSupport.digest(overlayDigest)
        guard validatedIntegrationApproval.reviewedComponentID == validatedOverlayID else {
            throw ContractError.unresolvedReference(
                kind: "integration_approval_overlay",
                id: validatedOverlayID
            )
        }
        guard validatedIntegrationApproval.reviewedComponentDigest == validatedOverlayDigest else {
            throw ContractError.digestMismatch(
                kind: "integration_approval_overlay",
                expected: validatedOverlayDigest.rawValue,
                actual: validatedIntegrationApproval.reviewedComponentDigest.rawValue
            )
        }
        let baseDigest = try IFLCanonContractSupport.digest(baseSnapshotContentDigest)
        let publishedDigest = try IFLCanonContractSupport.digest(publishedSnapshotContentDigest)
        guard baseDigest != publishedDigest else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "base and published snapshot content digests must differ"
            )
        }

        self.schemaVersion = schemaVersion
        self.activationID = try IFLCanonContractSupport.nonBlank(
            activationID,
            kind: kind,
            field: "activation_id"
        )
        self.transactionID = try IFLCanonContractSupport.nonBlank(
            transactionID,
            kind: kind,
            field: "transaction_id"
        )
        self.targetCanonVersion = targetCanonVersion
        self.targetProductVersion = try IFLCanonContractSupport.semanticVersion(
            targetProductVersion,
            kind: kind,
            field: "target_product_version"
        )
        self.overlayID = validatedOverlayID
        self.overlayDigest = validatedOverlayDigest
        self.integrationApproval = validatedIntegrationApproval
        self.approvalSourceArtifactID = try IFLCanonContractSupport.nonBlank(
            approvalSourceArtifactID,
            kind: kind,
            field: "approval_source_artifact_id"
        )
        self.approvalSourceArtifactDigest = try IFLCanonContractSupport.digest(
            approvalSourceArtifactDigest
        )
        self.approvalSidecarRelativePath = sidecarPath
        self.approvalSidecarDigest = try IFLCanonContractSupport.digest(approvalSidecarDigest)
        self.approvalTimestamp = try IFLCanonContractSupport.canonicalDate(
            approvalTimestamp,
            kind: kind,
            field: "approval_timestamp"
        )
        self.baseSnapshotContentDigest = baseDigest
        self.publishedSnapshotContentDigest = publishedDigest
        self.digestTransitions = digestTransitions.sorted {
            IFLCanonContractSupport.canonicalLess(
                $0.relativePath + "\u{0}" + $0.componentKind + "\u{0}" + $0.componentID,
                $1.relativePath + "\u{0}" + $1.componentKind + "\u{0}" + $1.componentID
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
        case baseSnapshotContentDigest = "base_snapshot_content_digest"
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
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawTransitions = try container.decode(
            [ActivationDigestTransition].self,
            forKey: .digestTransitions
        )
        try self.init(
            schemaVersion: container.decode(Int.self, forKey: .schemaVersion),
            activationID: container.decode(String.self, forKey: .activationID),
            transactionID: container.decode(String.self, forKey: .transactionID),
            targetCanonVersion: container.decode(Int.self, forKey: .targetCanonVersion),
            targetProductVersion: container.decode(String.self, forKey: .targetProductVersion),
            overlayID: container.decode(String.self, forKey: .overlayID),
            overlayDigest: container.decode(HashDigest.self, forKey: .overlayDigest),
            integrationApproval: container.decode(
                ReviewApprovalReference.self,
                forKey: .integrationApproval
            ),
            approvalSourceArtifactID: container.decode(String.self, forKey: .approvalSourceArtifactID),
            approvalSourceArtifactDigest: container.decode(
                HashDigest.self,
                forKey: .approvalSourceArtifactDigest
            ),
            approvalSidecarRelativePath: container.decode(
                String.self,
                forKey: .approvalSidecarRelativePath
            ),
            approvalSidecarDigest: container.decode(HashDigest.self, forKey: .approvalSidecarDigest),
            approvalTimestamp: IFLCanonContractSupport.decodeCanonicalDate(
                from: container,
                forKey: .approvalTimestamp,
                kind: kind,
                field: "approval_timestamp"
            ),
            baseSnapshotContentDigest: container.decode(
                HashDigest.self,
                forKey: .baseSnapshotContentDigest
            ),
            publishedSnapshotContentDigest: container.decode(
                HashDigest.self,
                forKey: .publishedSnapshotContentDigest
            ),
            digestTransitions: rawTransitions
        )
        guard rawTransitions == digestTransitions else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "digest_transitions must use canonical order"
            )
        }
    }
}
