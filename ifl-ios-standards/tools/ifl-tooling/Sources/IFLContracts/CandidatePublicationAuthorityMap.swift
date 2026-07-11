import Foundation

public enum CandidatePublicationComponentFamily: String, Codable, CaseIterable, Hashable, Sendable {
    case standardsCore = "standards-core"
    case runtimeAgents = "runtime-agents"
    case enterpriseRouting = "enterprise-routing"
    case scaffolds
}

public struct CandidatePublicationAuthorityRow: Hashable, Sendable {
    public let componentFamily: CandidatePublicationComponentFamily
    public let artifactKind: DerivedArtifactKind
    public let publicationKind: CandidatePublicationKind
    public let targetNamespace: CandidateTargetNamespace
    public let targetPath: PluginDerivedTargetPath
    public let targetMode: CandidatePortableMode
}

public struct CandidatePublicationAuthorityMap: Sendable {
    public static let v1 = CandidatePublicationAuthorityMap()

    public let identity = "urn:ifl:standards:candidate-publication-authority-map:v1"
    public let digest = HashDigest(
        uncheckedLowercaseSHA256: "43e707943f8c800653b991cafa6ca90aa9eed6a641f7c9a41a4ab162fc0a1e88"
    )
    public let rows: [CandidatePublicationAuthorityRow]

    private init() {
        rows = Self.compiledRows
    }

    public func row(for path: PluginDerivedTargetPath) -> CandidatePublicationAuthorityRow? {
        rows.first { $0.targetPath == path }
    }

    public func allows(
        componentFamily: CandidatePublicationComponentFamily,
        artifactKind: DerivedArtifactKind,
        targetPath: PluginDerivedTargetPath,
        publicationKind: CandidatePublicationKind,
        mode: CandidatePortableMode
    ) -> Bool {
        row(for: targetPath).map {
            $0.componentFamily == componentFamily
                && $0.artifactKind == artifactKind
                && $0.publicationKind == publicationKind
                && $0.targetNamespace == .pluginDerived
                && $0.targetMode == mode
        } ?? false
    }

    public func canonicalFileData() throws -> Data {
        var data = try CanonicalJSON.encode(DescriptorWire(
            identity: identity,
            rows: rows.map(RowWire.init),
            schemaVersion: 1
        ))
        data.append(0x0A)
        return data
    }

    private static let compiledRows: [CandidatePublicationAuthorityRow] = [
        CandidatePublicationAuthorityRow(
            componentFamily: .runtimeAgents,
            artifactKind: .agent,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "agents/architecture-standards-reviewer.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .runtimeAgents,
            artifactKind: .agent,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "agents/code-quality-reviewer.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .runtimeAgents,
            artifactKind: .agent,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "agents/data-integrity-reviewer.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .runtimeAgents,
            artifactKind: .agent,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "agents/domain-product-designer.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .runtimeAgents,
            artifactKind: .agent,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "agents/flow-orchestrator.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .runtimeAgents,
            artifactKind: .agent,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "agents/implementation-planner.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .runtimeAgents,
            artifactKind: .agent,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "agents/ios-architect.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .runtimeAgents,
            artifactKind: .agent,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "agents/ios-coder.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .runtimeAgents,
            artifactKind: .agent,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "agents/ios-doc-scribe.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .runtimeAgents,
            artifactKind: .agent,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "agents/ios-implementer.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .runtimeAgents,
            artifactKind: .agent,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "agents/ios-orchestrator.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .runtimeAgents,
            artifactKind: .agent,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "agents/ios-planner.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .runtimeAgents,
            artifactKind: .agent,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "agents/ios-researcher.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .runtimeAgents,
            artifactKind: .agent,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "agents/ios-review-triage.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .runtimeAgents,
            artifactKind: .agent,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "agents/ios-reviewer.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .runtimeAgents,
            artifactKind: .agent,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "agents/ios-tester.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .runtimeAgents,
            artifactKind: .agent,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "agents/product-release-assembler.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .runtimeAgents,
            artifactKind: .agent,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "agents/product-release-validator.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .runtimeAgents,
            artifactKind: .agent,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "agents/requirements-analyst.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .runtimeAgents,
            artifactKind: .agent,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "agents/run-evidence-reviewer.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .runtimeAgents,
            artifactKind: .agent,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "agents/security-privacy-reviewer.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .runtimeAgents,
            artifactKind: .agent,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "agents/test-strategist.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .scaffolds,
            artifactKind: .wrapper,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "bin/ifl-init"),
            targetMode: .executable
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .scaffolds,
            artifactKind: .wrapper,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "bin/ifl-new-board"),
            targetMode: .executable
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .scaffolds,
            artifactKind: .wrapper,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "bin/ifl-new-module"),
            targetMode: .executable
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .scaffolds,
            artifactKind: .scaffold,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "scaffolds/manifest.json"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .scaffolds,
            artifactKind: .template,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "scaffolds/templates/board/blocktask/board.template.json"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .scaffolds,
            artifactKind: .template,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "scaffolds/templates/board/flow/board.template.json"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .scaffolds,
            artifactKind: .template,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "scaffolds/templates/board/shared/board.template.json"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .scaffolds,
            artifactKind: .template,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "scaffolds/templates/board/swiftui/board.template.json"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .scaffolds,
            artifactKind: .template,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "scaffolds/templates/board/uikit/board.template.json"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .scaffolds,
            artifactKind: .template,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "scaffolds/templates/board/viewless/board.template.json"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .scaffolds,
            artifactKind: .template,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "scaffolds/templates/init/project.template.json"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .scaffolds,
            artifactKind: .template,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "scaffolds/templates/module/bazel/module.template.json"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .scaffolds,
            artifactKind: .template,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "scaffolds/templates/module/cocoapods/module.template.json"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .scaffolds,
            artifactKind: .template,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "scaffolds/templates/module/common/module.template.json"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .scaffolds,
            artifactKind: .template,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "scaffolds/templates/module/swiftpm/module.template.json"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .scaffolds,
            artifactKind: .template,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "scaffolds/templates/module/xcode/module.template.json"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .skill,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "skills/boardy-adopt/SKILL.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .skill,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "skills/boardy-communication/SKILL.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .skill,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "skills/boardy-io-interface/SKILL.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .skill,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "skills/boardy-new-board/SKILL.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .skill,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "skills/boardy-new-module/SKILL.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .skill,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "skills/boardy-plugin-composition/SKILL.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .skill,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "skills/boardy-refactor/SKILL.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .skill,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "skills/boardy-review/SKILL.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .skill,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "skills/boardy-service-layer/SKILL.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .skill,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "skills/boardy-testing/SKILL.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .skill,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "skills/boardy-troubleshoot/SKILL.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .skill,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "skills/boardy-vip/SKILL.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .skill,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "skills/brain-architect/SKILL.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .skill,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "skills/brain-design/SKILL.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .skill,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "skills/brain-execute/SKILL.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .skill,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "skills/brain-flow/SKILL.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .skill,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "skills/brain-plan/SKILL.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .skill,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "skills/brain-review/SKILL.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .skill,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "skills/brain-testing/SKILL.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .skill,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "skills/enterprise-ios/SKILL.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .guide,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "skills/enterprise-ios/references/chapter-routing.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .guide,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "skills/enterprise-ios/references/evidence-routing.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .skill,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "skills/init/SKILL.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .runtimeAgents,
            artifactKind: .guide,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/AGENT_MODEL_TIERING.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .standardsCore,
            artifactKind: .constitution,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/CONSTITUTION.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .standardsCore,
            artifactKind: .compactReference,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/brain/QUICK_REF.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .standardsCore,
            artifactKind: .guide,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/brain/patterns/VIP.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .standardsCore,
            artifactKind: .rulebook,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/brain/rulebook/02-architectural-principles.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .standardsCore,
            artifactKind: .rulebook,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/brain/rulebook/03-dependency-rules.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .rulebook,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/brain/rulebook/04-module-design-rules.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .standardsCore,
            artifactKind: .rulebook,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/brain/rulebook/05-interface-module-rules.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .standardsCore,
            artifactKind: .rulebook,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/brain/rulebook/09-ui-layer-rules.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .standardsCore,
            artifactKind: .rulebook,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/brain/rulebook/10-visibility-api-export-rules.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .rulebook,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/brain/rulebook/11-state-management-rules.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .rulebook,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/brain/rulebook/14-build-scalability-rules.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .rulebook,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/brain/rulebook/15-testing-philosophy.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .rulebook,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/brain/rulebook/17-anti-patterns.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .rulebook,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/brain/rulebook/18-decision-heuristics.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .checklist,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/brain/rulebook/19-architecture-review-checklist.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .standardsCore,
            artifactKind: .rulebook,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/brain/rulebook/20-non-negotiable-rules.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .guide,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/enterprise/chapters/accessibility-global-readiness.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .guide,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/enterprise/chapters/data-lifecycle.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .guide,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/enterprise/chapters/mobile-security.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .guide,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/enterprise/chapters/modern-testing.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .guide,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/enterprise/chapters/observability-operability.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .guide,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/enterprise/chapters/performance-resilience.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .guide,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/enterprise/chapters/privacy-compliance.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .guide,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/enterprise/chapters/supply-chain-legal.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .guide,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/enterprise/chapters/swift-6-concurrency.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .guide,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/enterprise/chapters/swiftui-production.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .standardsCore,
            artifactKind: .migrationGuide,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/migrations/legacy-crosswalk.v1.json"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .runtimeAgents,
            artifactKind: .processContract,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/process/approval-modes.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .runtimeAgents,
            artifactKind: .processContract,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/process/requirement-intake.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .runtimeAgents,
            artifactKind: .guide,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/rules/BRIEFING_HANDOFF.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .standardsCore,
            artifactKind: .compactReference,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/rules/QUICK_REF.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .standardsCore,
            artifactKind: .guide,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/rules/SPEC_CONTRACT.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .standardsCore,
            artifactKind: .guide,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/rules/SPEC_SYNC.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .runtimeAgents,
            artifactKind: .processContract,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/runtime/review-convergence.contract.json"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .runtimeAgents,
            artifactKind: .template,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/runtime/templates/claude-agent.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .runtimeAgents,
            artifactKind: .template,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/runtime/templates/codex-role-prompt.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .specification,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/ACTIVATION_BARRIER.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .specification,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/ADOPTION.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .standardsCore,
            artifactKind: .specification,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/ARCHITECTURE.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .specification,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/BOARDY_FOUNDATIONS.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .migrationGuide,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/BROWNFIELD_MIGRATION.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .specification,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/BUS_PATTERNS.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .specification,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/COMMUNICATION.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .specification,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/COMPOSABLE_BOARD.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .specification,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/CONTEXT_NAVIGATION.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .specification,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/CONVENTIONS.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .standardsCore,
            artifactKind: .specification,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/CROSS_MODULE_DI.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .guide,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/DECISION_TREES.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .example,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/EXAMPLES.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .standardsCore,
            artifactKind: .example,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/EXAMPLES_BARRIER_BOARD.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .standardsCore,
            artifactKind: .example,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/EXAMPLES_COMPOSABLE_BOARD.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .example,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/EXAMPLES_EXTENSIBLE_PROVIDER.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .standardsCore,
            artifactKind: .example,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/EXAMPLES_IO.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .example,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/EXAMPLES_NONUI_BOARDS.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .example,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/EXAMPLES_PER_ACTIVATION_RESOURCES.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .example,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/EXAMPLES_PLUGIN.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .example,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/EXAMPLES_SERVICE.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .example,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/EXAMPLES_VIEWLESS_BOARD.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .standardsCore,
            artifactKind: .example,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/EXAMPLES_VIP_BOARD.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .specification,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/EXTENSIBLE_PROVIDER.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .guide,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/GREENFIELD_SETUP.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .standardsCore,
            artifactKind: .specification,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/IO_INTERFACE.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .standardsCore,
            artifactKind: .specification,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/LAYERING.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .standardsCore,
            artifactKind: .specification,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/MICROBOARD_NONUI.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .standardsCore,
            artifactKind: .specification,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/MICROBOARD_UI.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .guide,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/MODULE_CREATION.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .specification,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/PACKAGE_MANAGER.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .specification,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/PER_ACTIVATION_RESOURCES.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .standardsCore,
            artifactKind: .specification,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/PLUGINS_INTEGRATION.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .standardsCore,
            artifactKind: .guide,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/README.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .guide,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/REFACTOR_PLAYBOOK.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .standardsCore,
            artifactKind: .checklist,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/REVIEWER_CHECKLIST.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .guide,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/REVIEW_PLAYBOOK.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .specification,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/SDK_FIRST.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .specification,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/SERVICE_LAYER.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .specification,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/TESTING.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .guide,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/TROUBLESHOOTING.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .specification,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/VIP_COMPONENTS.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .standardsCore,
            artifactKind: .compactReference,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/compact/BOARDY_CHEATSHEET.compact.md"),
            targetMode: .file
        ),
        CandidatePublicationAuthorityRow(
            componentFamily: .enterpriseRouting,
            artifactKind: .compactReference,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetPath: PluginDerivedTargetPath(compiledRawValue: "standards/specs/compact/TESTING.compact.md"),
            targetMode: .file
        ),
    ]
}

private struct DescriptorWire: Encodable {
    let identity: String
    let rows: [RowWire]
    let schemaVersion: Int

    private enum CodingKeys: String, CodingKey {
        case identity
        case rows
        case schemaVersion = "schema_version"
    }
}

private struct RowWire: Encodable {
    let artifactKind: DerivedArtifactKind
    let componentFamily: CandidatePublicationComponentFamily
    let publicationKind: CandidatePublicationKind
    let targetMode: CandidatePortableMode
    let targetNamespace: CandidateTargetNamespace
    let targetRelativePath: String

    init(_ row: CandidatePublicationAuthorityRow) {
        artifactKind = row.artifactKind
        componentFamily = row.componentFamily
        publicationKind = row.publicationKind
        targetMode = row.targetMode
        targetNamespace = row.targetNamespace
        targetRelativePath = row.targetPath.rawValue
    }

    private enum CodingKeys: String, CodingKey {
        case artifactKind = "artifact_kind"
        case componentFamily = "component_family"
        case publicationKind = "publication_kind"
        case targetMode = "target_mode"
        case targetNamespace = "target_namespace"
        case targetRelativePath = "target_relative_path"
    }
}
