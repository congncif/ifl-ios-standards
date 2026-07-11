public enum PluginReleaseWorkflow {
    public static let definition = WorkflowDefinition(
        workType: .pluginRelease,
        stages: [
            .candidateAssembly,
            .releaseVerification,
            .productReleaseGate,
            .readyForExternalReleaseEffect,
        ],
        transitions: [
            .init(from: .candidateAssembly, event: .candidateSubmitted, to: .releaseVerification),
            .init(from: .releaseVerification, event: .releaseChecksPassed, to: .productReleaseGate),
            .init(from: .releaseVerification, event: .releaseChecksFailed, to: .candidateAssembly),
            .init(from: .productReleaseGate, event: .productReleaseApproved, to: .readyForExternalReleaseEffect),
            .init(from: .productReleaseGate, event: .releaseChangesRequired, to: .candidateAssembly),
            .init(from: .readyForExternalReleaseEffect, event: .closeQualification, to: .readyForExternalReleaseEffect),
        ]
    )

    public static func allows(_ request: ReleaseEffectRequest, in state: RunState) -> Bool {
        let targets: Set<ReleaseEffectTarget> = [
            .qualificationPayload,
            .finalQualificationManifest,
            .finalQualificationSignature,
            .distributionSHA256Sums,
            .terminalReport,
        ]
        return state.workType == .pluginRelease &&
            state.stage == .readyForExternalReleaseEffect &&
            state.status == .running &&
            state.candidateGenerationID == request.candidateGenerationID &&
            request.effectClass == .e1 &&
            targets.contains(request.target)
    }
}
