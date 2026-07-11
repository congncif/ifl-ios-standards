public struct WorkflowTransition: Codable, Hashable, Sendable {
    public let from: WorkflowStage
    public let event: WorkflowEventKind
    public let to: WorkflowStage

    public init(from: WorkflowStage, event: WorkflowEventKind, to: WorkflowStage) {
        self.from = from
        self.event = event
        self.to = to
    }
}

public struct WorkflowDefinition: Codable, Hashable, Sendable {
    public let workType: WorkType
    public let stages: [WorkflowStage]
    public let transitions: [WorkflowTransition]

    public init(
        workType: WorkType,
        stages: [WorkflowStage],
        transitions: [WorkflowTransition]
    ) {
        self.workType = workType
        self.stages = stages
        self.transitions = transitions
    }

    func destination(from stage: WorkflowStage, for event: WorkflowEventKind) -> WorkflowStage? {
        transitions.first { $0.from == stage && $0.event == event }?.to
    }

    func validateCanonical(for workType: WorkType) throws {
        let canonical: WorkflowDefinition
        switch workType {
        case .engineeringRun:
            canonical = EngineeringWorkflow.definition
        case .pluginRelease:
            canonical = PluginReleaseWorkflow.definition
        }
        guard self == canonical else { throw WorkflowError.invalidDefinition }

        let keys = transitions.map { TransitionKey(from: $0.from, event: $0.event) }
        guard Set(stages).count == stages.count,
              Set(keys).count == keys.count,
              transitions.allSatisfy({ stages.contains($0.from) && stages.contains($0.to) })
        else { throw WorkflowError.invalidDefinition }
    }
}

private struct TransitionKey: Hashable {
    let from: WorkflowStage
    let event: WorkflowEventKind
}
