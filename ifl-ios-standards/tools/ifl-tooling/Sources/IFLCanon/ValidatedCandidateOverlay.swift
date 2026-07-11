import IFLContracts

public struct ValidatedCandidateOverlay: Sendable {
    package let overlayID: CandidateOverlayID
    package let overlayDigest: HashDigest
    package let manifest: CandidateOverlayManifest
    package let componentBundles: [String: CandidateComponentBundle]
    package let candidateTreeCapture: CandidateTreeCapture
    package let basePluginEvidence: BasePluginSnapshotEvidence
    package let canonEvidence: CanonSnapshotEvidence
    package let transformDescriptor: CandidateOverlayTransformDescriptor
}
