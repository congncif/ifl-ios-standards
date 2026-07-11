public struct TransitionDecision: Codable, Hashable, Sendable {
    public let proposedState: RunState
    public let invalidatedArtifactIDs: [String]
    public let requiredActions: [String]
    public let reasonCode: String

    public init(
        proposedState: RunState,
        invalidatedArtifactIDs: [String] = [],
        requiredActions: [String] = [],
        reasonCode: String
    ) {
        self.proposedState = proposedState
        self.invalidatedArtifactIDs = invalidatedArtifactIDs
        self.requiredActions = requiredActions
        self.reasonCode = reasonCode
    }
}
