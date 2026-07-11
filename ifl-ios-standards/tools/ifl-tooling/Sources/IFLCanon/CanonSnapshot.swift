import IFLContracts

public struct CanonSnapshot: Sendable {
    public let canonVersion: Int
    public let rules: [RuleRecord]
    public let profiles: [ProfileRecord]
    public let selectedProfileIDs: [ProfileID]
    public let adrs: [ADRMetadata]
    public let adrMarkdownByID: [ADRIdentifier: String]
    public let chapters: [ChapterMetadata]
    public let requirementRegistry: RequirementRegistry
    public let derivedArtifacts: [DerivedRegistrationEntry]
    public let snapshotContentDigest: HashDigest
    package let candidateOverlayEvidence: CanonSnapshotEvidence?

    public init(
        canonVersion: Int,
        rules: [RuleRecord],
        profiles: [ProfileRecord],
        selectedProfileIDs: [ProfileID],
        adrs: [ADRMetadata],
        adrMarkdownByID: [ADRIdentifier: String],
        chapters: [ChapterMetadata],
        requirementRegistry: RequirementRegistry,
        derivedArtifacts: [DerivedRegistrationEntry],
        snapshotContentDigest: HashDigest
    ) {
        self.init(
            canonVersion: canonVersion,
            rules: rules,
            profiles: profiles,
            selectedProfileIDs: selectedProfileIDs,
            adrs: adrs,
            adrMarkdownByID: adrMarkdownByID,
            chapters: chapters,
            requirementRegistry: requirementRegistry,
            derivedArtifacts: derivedArtifacts,
            snapshotContentDigest: snapshotContentDigest,
            candidateOverlayEvidence: nil
        )
    }

    init(
        canonVersion: Int,
        rules: [RuleRecord],
        profiles: [ProfileRecord],
        selectedProfileIDs: [ProfileID],
        adrs: [ADRMetadata],
        adrMarkdownByID: [ADRIdentifier: String],
        chapters: [ChapterMetadata],
        requirementRegistry: RequirementRegistry,
        derivedArtifacts: [DerivedRegistrationEntry],
        snapshotContentDigest: HashDigest,
        candidateOverlayEvidence: CanonSnapshotEvidence?
    ) {
        self.canonVersion = canonVersion
        self.rules = rules
        self.profiles = profiles
        self.selectedProfileIDs = selectedProfileIDs
        self.adrs = adrs
        self.adrMarkdownByID = adrMarkdownByID
        self.chapters = chapters
        self.requirementRegistry = requirementRegistry
        self.derivedArtifacts = derivedArtifacts
        self.snapshotContentDigest = snapshotContentDigest
        self.candidateOverlayEvidence = candidateOverlayEvidence
    }
}
