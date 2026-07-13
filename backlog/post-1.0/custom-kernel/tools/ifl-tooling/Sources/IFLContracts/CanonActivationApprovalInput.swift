import Foundation

public struct CanonActivationApprovalInput: Hashable, Sendable {
    public let integrationApproval: ReviewApprovalReference
    public let approvalTimestamp: Date
    public let approvalSourceArtifactID: String
    public let approvalSourceArtifactDigest: HashDigest
    public let approvalSidecarRelativePath: String
    public let approvalSidecarBytes: Data
    public let approvalSidecarDigest: HashDigest

    package init(
        integrationApproval: ReviewApprovalReference,
        approvalTimestamp: Date,
        approvalSourceArtifactID: String,
        approvalSourceArtifactDigest: HashDigest,
        approvalSidecarRelativePath: String,
        approvalSidecarBytes: Data,
        approvalSidecarDigest: HashDigest
    ) throws {
        let kind = "canon_activation_approval_input"
        let sourceID = try IFLCanonContractSupport.nonBlank(
            approvalSourceArtifactID,
            kind: kind,
            field: "approval_source_artifact_id"
        )
        let sidecarPath = try IFLCanonContractSupport.exactRelativePath(
            approvalSidecarRelativePath,
            kind: kind,
            field: "approval_sidecar_relative_path"
        )
        guard sidecarPath.hasSuffix(".approval.json") else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "approval_sidecar_relative_path must identify an approval JSON sidecar"
            )
        }
        let storedDigest = try IFLCanonContractSupport.digest(approvalSidecarDigest)
        let actualDigest = CanonicalTreeDigest.sha256(approvalSidecarBytes)
        guard storedDigest == actualDigest else {
            throw ContractError.digestMismatch(
                kind: "approval_sidecar",
                expected: storedDigest.rawValue,
                actual: actualDigest.rawValue
            )
        }
        let object = try JSONSerialization.jsonObject(with: approvalSidecarBytes)
        var canonicalBytes = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        canonicalBytes.append(0x0A)
        guard canonicalBytes == approvalSidecarBytes else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "approval sidecar bytes must be canonical JSON followed by exactly one LF"
            )
        }

        self.integrationApproval = integrationApproval
        self.approvalTimestamp = try IFLCanonContractSupport.canonicalDate(
            approvalTimestamp,
            kind: kind,
            field: "approval_timestamp"
        )
        self.approvalSourceArtifactID = sourceID
        self.approvalSourceArtifactDigest = try IFLCanonContractSupport.digest(
            approvalSourceArtifactDigest
        )
        self.approvalSidecarRelativePath = sidecarPath
        self.approvalSidecarBytes = approvalSidecarBytes
        self.approvalSidecarDigest = storedDigest
    }
}
