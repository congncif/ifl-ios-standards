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
}
