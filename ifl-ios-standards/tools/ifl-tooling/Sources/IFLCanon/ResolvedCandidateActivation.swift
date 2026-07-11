import Foundation
import IFLContracts

package struct ResolvedCandidateOutputFile: Hashable {
    package let targetNamespace: CandidateTargetNamespace
    package let targetRelativePath: String
    package let bytes: Data
    package let contentDigest: HashDigest
    package let mode: UInt16
    package let affectedComponents: [ActivationAffectedComponentReference]

    var targetKey: String {
        targetNamespace.rawValue + "\0" + targetRelativePath
    }
}

package struct ResolvedCandidateOutputDirectory: Hashable {
    package let targetNamespace: CandidateTargetNamespace
    package let targetRelativePath: String
    package let mode: UInt16
    package let affectedComponents: [ActivationAffectedComponentReference]

    var targetKey: String {
        targetNamespace.rawValue + "\0" + targetRelativePath
    }
}

public struct ResolvedCandidateActivation: Sendable {
    package let overlayID: String
    package let overlayDigest: HashDigest
    package let targetCanonVersion: Int
    package let targetProductVersion: String
    package let baseSnapshotContentDigest: HashDigest
    package let approvalInput: CanonActivationApprovalInput
    package let activationTransformIdentity: String
    package let activationTransformDigest: HashDigest
    package let outputFiles: [ResolvedCandidateOutputFile]
    package let outputDirectories: [ResolvedCandidateOutputDirectory]
    package let digestTransitions: [ActivationDigestTransition]
    package let baseCanonInventory: CanonicalTreeInventory
    package let baseCanonInventoryDigest: HashDigest
    package let basePluginInventory: CanonicalTreeInventory
    package let basePluginInventoryDigest: HashDigest
    package let candidateTreeCapture: CandidateTreeCapture
    package let projectedPublishedCanonInventory: CanonicalTreeInventory
    package let publishedSnapshotContentDigest: HashDigest
    package let resolvedPluginInventory: CanonicalTreeInventory
    package let resolvedPluginInventoryDigest: HashDigest
    package let resolvedCanonSnapshot: CanonSnapshot
    package let resolvedActivationDigest: HashDigest
}
