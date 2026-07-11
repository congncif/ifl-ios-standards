import Foundation
@testable import IFLContracts
import Testing

@Suite("CanonicalRelativePathParityTests")
struct CanonicalRelativePathParityTests {
    @Test("schema format and Swift contracts accept the same canonical path corpus")
    func schemaAndSwiftContractParity() throws {
        let definitions = try schemaDefinitions()
        let normativePattern = try #require(definitions.first?.pattern)
        let validPaths = [
            "file.json",
            "nested/value.txt",
            "sp ace/é.json",
            "bracket].json",
        ]
        let invalidPaths = [
            "",
            "/absolute",
            "a//b",
            "a/",
            ".",
            "..",
            "./a",
            "a/.",
            "a/../b",
            "a\\b",
            "*.json",
            "a?.json",
            "a[bc].json",
            "nul\u{0000}byte",
            "c0\u{001F}control",
            "del\u{007F}control",
            "c1\u{0085}control",
            "line\u{2028}separator",
            "paragraph\u{2029}separator",
            "e\u{301}.json",
        ]

        for definition in definitions {
            #expect(
                definition.pattern == normativePattern,
                "\(definition.filename) does not publish the normative canonical relative-path pattern"
            )
            #expect(
                definition.format == "ifl-canonical-relative-path-v1",
                "\(definition.filename) does not bind the canonical relative-path format"
            )
            #expect(
                definition.assertsFormat,
                "\(definition.filename) does not require canonical relative-path format assertion"
            )
        }

        for path in validPaths {
            for definition in definitions {
                #expect(
                    try schemaAccepts(path, definition: definition),
                    "\(definition.filename) rejected valid path: \(path)"
                )
            }
            #expect(try CanonicalRelativePath(validating: path).rawValue == path)
            #expect(
                try IFLCanonContractSupport.exactRelativePath(
                    path,
                    kind: "path_parity_test",
                    field: "relative_path"
                ) == path
            )
        }

        for path in invalidPaths {
            for definition in definitions {
                #expect(
                    try !schemaAccepts(path, definition: definition),
                    "\(definition.filename) accepted invalid path: \(path)"
                )
            }
            #expect(throws: CanonicalTreeError.self) {
                try CanonicalRelativePath(validating: path)
            }
            #expect(throws: ContractError.self) {
                try IFLCanonContractSupport.exactRelativePath(
                    path,
                    kind: "path_parity_test",
                    field: "relative_path"
                )
            }
        }
    }

    @Test("specialized schema paths match their production contract entry points")
    func specializedSchemaAndSwiftContractParity() throws {
        let contracts = try specializedPathContracts()

        for contract in contracts {
            #expect(
                contract.definition.format == "ifl-canonical-relative-path-v1",
                "\(contract.definition.filename) does not bind the canonical relative-path format"
            )
            #expect(
                contract.definition.assertsFormat,
                "\(contract.definition.filename) does not require canonical relative-path format assertion"
            )

            for path in contract.validPaths {
                let schemaResult = try schemaAccepts(path, definition: contract.definition)
                let swiftResult = swiftAccepts(path, contract: contract.contract)
                #expect(
                    schemaResult,
                    "\(contract.definition.filename) rejected specialized valid path: \(path)"
                )
                #expect(
                    swiftResult,
                    "\(contract.contract) rejected specialized valid path: \(path)"
                )
                #expect(schemaResult == swiftResult)
            }

            for path in contract.invalidPaths {
                let schemaResult = try schemaAccepts(path, definition: contract.definition)
                let swiftResult = swiftAccepts(path, contract: contract.contract)
                #expect(
                    !schemaResult,
                    "\(contract.definition.filename) accepted specialized invalid path: \(path)"
                )
                #expect(
                    !swiftResult,
                    "\(contract.contract) accepted specialized invalid path: \(path)"
                )
                #expect(schemaResult == swiftResult)
            }
        }
    }

    @Test("ADR publication paths use an ASCII ID-plus-slug basename paired across metadata and Markdown")
    func adrPublicationPathGrammar() throws {
        _ = try adrOverlay(
            id: "ADR-9999",
            metadataPath: "adrs/ADR-9999-test.json",
            markdownPath: "adrs/ADR-9999-test.md"
        )

        let invalidPairs = [
            ("ADR-9999", "adrs/ADR-9999-.json", "adrs/ADR-9999-.md"),
            ("ADR-9999", "adrs/ADR-\u{FF11}\u{FF12}\u{FF13}\u{FF14}-test.json", "adrs/ADR-\u{FF11}\u{FF12}\u{FF13}\u{FF14}-test.md"),
            ("ADR-9999", "adrs/ADR-9999-tést.json", "adrs/ADR-9999-tést.md"),
            ("ADR-9999", "adrs/ADR-0001-test.json", "adrs/ADR-0001-test.md"),
        ]
        for (id, metadata, markdown) in invalidPairs {
            #expect(throws: ContractError.self) {
                try adrOverlay(id: id, metadataPath: metadata, markdownPath: markdown)
            }
        }
    }
}

private extension CanonicalRelativePathParityTests {
    struct SchemaDefinition {
        let filename: String
        let pattern: String
        let format: String?
        let assertsFormat: Bool
    }

    enum SpecializedSwiftContract: CustomStringConvertible {
        case adrReferenceArtifact
        case activationApprovalSidecar
        case activationSnapshot
        case canonTarget

        var description: String {
            switch self {
            case .adrReferenceArtifact:
                "ADRMetadata.init(referenceArtifactIDs:)"
            case .activationApprovalSidecar:
                "CanonActivationReceipt.init(approvalSidecarRelativePath:)"
            case .activationSnapshot:
                "ActivationDigestTransition.init(relativePath:)"
            case .canonTarget:
                "CanonTargetPath.init(validating:)"
            }
        }
    }

    struct SpecializedPathContract {
        let definition: SchemaDefinition
        let contract: SpecializedSwiftContract
        let validPaths: [String]
        let invalidPaths: [String]
    }

    var pluginRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func schemaDefinitions() throws -> [SchemaDefinition] {
        let schemas = [
            (filename: "candidate-component-bundle.schema.json", definition: "exact_relative_path"),
            (filename: "candidate-overlay.schema.json", definition: "exact_relative_path"),
            (filename: "canonical-tree-inventory.schema.json", definition: "relative_path"),
            (filename: "derived-artifact.schema.json", definition: "exact_relative_path"),
            (filename: "derived-registration-delta.schema.json", definition: "exact_relative_path"),
            (filename: "exception.schema.json", definition: "exact_relative_path"),
            (filename: "fixture.schema.json", definition: "exact_relative_path"),
        ]

        return try schemas.map {
            try schemaDefinition(filename: $0.filename, definition: $0.definition)
        }
    }

    func specializedPathContracts() throws -> [SpecializedPathContract] {
        try [
            SpecializedPathContract(
                definition: schemaDefinition(
                    filename: "candidate-component-bundle.schema.json",
                    definition: "canon_target_path"
                ),
                contract: .canonTarget,
                validPaths: [
                    "rules",
                    "rules/core/test.rules.json",
                    "profiles/minimal.profile.json",
                    "adrs/ADR-9999-test.md",
                    "chapters/core/test.chapter.json",
                    "registry/derived-artifacts.index.json",
                    "registry/requirements.v1.json",
                ],
                invalidPaths: [
                    "VERSION",
                    "schemas/v1/rule.schema.json",
                    "registry/namespaces.v1.json",
                    "activations/overlay.receipt.json",
                    "tools/ifl-tooling/Package.swift",
                ]
            ),
            SpecializedPathContract(
                definition: schemaDefinition(
                    filename: "adr-metadata.schema.json",
                    definition: "canonical_relative_path"
                ),
                contract: .adrReferenceArtifact,
                validPaths: [
                    "standards/canon/VERSION",
                    "references/é.json",
                ],
                invalidPaths: [
                    "references/bracket].json",
                    "references/brace{.json",
                    "references/brace}.json",
                    "references/bracket]\u{301}.json",
                    "references/brace{\u{301}.json",
                    "references/brace}\u{301}.json",
                ]
            ),
            SpecializedPathContract(
                definition: schemaDefinition(
                    filename: "activation-receipt.schema.json",
                    definition: "approval_sidecar_path"
                ),
                contract: .activationApprovalSidecar,
                validPaths: [
                    "activations/overlay-001.approval.json",
                    "activations/nested/bracket].approval.json",
                    "activations/nested/braces{}.approval.json",
                ],
                invalidPaths: [
                    "overlay-001.approval.json",
                    "activations/overlay-001.json",
                    "activations/overlay-001.approval.json/child",
                    "activations/../overlay-001.approval.json",
                    "activations/a[bc].approval.json",
                ]
            ),
            SpecializedPathContract(
                definition: schemaDefinition(
                    filename: "activation-receipt.schema.json",
                    definition: "snapshot_relative_path"
                ),
                contract: .activationSnapshot,
                validPaths: [
                    "rules/test.rules.json",
                    "rules/bracket].json",
                    "rules/braces{}.json",
                ],
                invalidPaths: [
                    "activations/test.json",
                    "rules/test.approval.json",
                    "rules/test.receipt.json",
                    "rules/a[bc].json",
                    "/rules/test.rules.json",
                ]
            ),
        ]
    }

    func schemaDefinition(filename: String, definition: String) throws -> SchemaDefinition {
        let url = pluginRoot.appendingPathComponent("standards/canon/schemas/v1/\(filename)")
        let root = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        )
        let definitions = try #require(root["$defs"] as? [String: Any])
        let relativePath = try #require(definitions[definition] as? [String: Any])
        return try SchemaDefinition(
            filename: "\(filename)#/$defs/\(definition)",
            pattern: #require(relativePath["pattern"] as? String),
            format: relativePath["format"] as? String,
            assertsFormat: relativePath["x-ifl-format-assertion-required"] as? Bool ?? false
        )
    }

    func schemaAccepts(_ value: String, definition: SchemaDefinition) throws -> Bool {
        let expression = try NSRegularExpression(pattern: definition.pattern)
        let range = NSRange(value.startIndex ..< value.endIndex, in: value)
        guard expression.firstMatch(in: value, range: range)?.range == range else {
            return false
        }

        guard definition.format == "ifl-canonical-relative-path-v1",
              definition.assertsFormat
        else {
            return true
        }
        return value.utf8.elementsEqual(value.precomposedStringWithCanonicalMapping.utf8)
    }

    func swiftAccepts(_ path: String, contract: SpecializedSwiftContract) -> Bool {
        do {
            switch contract {
            case .adrReferenceArtifact:
                _ = try adrMetadata(referenceArtifactPath: path)
            case .activationApprovalSidecar:
                _ = try activationReceipt(approvalSidecarPath: path)
            case .activationSnapshot:
                _ = try ActivationDigestTransition(
                    targetNamespace: .canon,
                    targetRelativePath: path,
                    affectedComponents: [
                        ActivationAffectedComponentReference(
                            componentKind: "standards-core",
                            componentID: "component-core"
                        ),
                    ],
                    beforeEntry: nil,
                    afterEntry: CanonicalTreeEntry(
                        relativePath: path,
                        kind: .regularFile,
                        contentSHA256: digest("4"),
                        mode: 420
                    )
                )
            case .canonTarget:
                _ = try CanonTargetPath(validating: path)
            }
            return true
        } catch {
            return false
        }
    }

    func adrMetadata(referenceArtifactPath: String) throws -> ADRMetadata {
        try ADRMetadata(
            schemaVersion: 1,
            id: ADRIdentifier(validating: "ADR-9999"),
            title: "Path parity",
            status: .draft,
            ownerRoleID: "Canon Maintainer",
            decisionDate: "2026-07-11",
            markdownDigest: digest("a"),
            context: "Context",
            decision: "Decision",
            alternatives: [],
            consequences: [],
            migration: [],
            affectedRuleIDs: [],
            affectedProfileIDs: [],
            verificationImpact: [],
            checkIDs: [],
            fixtureIDs: [],
            referenceArtifactIDs: [referenceArtifactPath],
            migrationIDs: [],
            supersedesADRIDs: [],
            supersededBy: nil,
            acceptedAt: nil
        )
    }

    func adrOverlay(
        id: String,
        metadataPath: String,
        markdownPath: String
    ) throws -> ADROverlayBinding {
        try ADROverlayBinding(
            id: ADRIdentifier(validating: id),
            reviewedComponentID: "core-authority-v1",
            metadataBundleArtifactID: "adr-metadata",
            metadataBundlePublicationID: "publish-adr-metadata",
            metadataTargetRelativePath: metadataPath,
            markdownBundleArtifactID: "adr-markdown",
            markdownBundlePublicationID: "publish-adr-markdown",
            markdownTargetRelativePath: markdownPath,
            semanticDigest: digest("a"),
            beforeMetadataFullDigest: nil,
            candidateMetadataFullDigest: digest("b"),
            candidateMarkdownFullDigest: digest("c")
        )
    }

    func activationReceipt(approvalSidecarPath: String) throws -> CanonActivationReceipt {
        let overlayDigest = try digest("5")
        let approval = try ReviewApprovalReference(
            schemaVersion: 1,
            approvalID: "integration-approval",
            principalID: "principal-integration",
            actorID: "actor-integration",
            roleID: "Integration Reviewer",
            reviewedComponentID: "overlay-001",
            reviewedComponentDigest: overlayDigest,
            attestationID: "attestation-integration",
            attestationDigest: digest("f")
        )
        let transition = try ActivationDigestTransition(
            targetNamespace: .canon,
            targetRelativePath: "rules/test.rules.json",
            affectedComponents: [
                ActivationAffectedComponentReference(
                    componentKind: "standards-core",
                    componentID: "component-core"
                ),
            ],
            beforeEntry: CanonicalTreeEntry(
                relativePath: "rules/test.rules.json",
                kind: .regularFile,
                contentSHA256: digest("3"),
                mode: 420
            ),
            afterEntry: CanonicalTreeEntry(
                relativePath: "rules/test.rules.json",
                kind: .regularFile,
                contentSHA256: digest("4"),
                mode: 420
            )
        )
        return try CanonActivationReceipt(
            schemaVersion: 1,
            activationID: "activation-001",
            transactionID: "transaction-001",
            targetCanonVersion: 1,
            targetProductVersion: "1.0.0-rc.1",
            overlayID: "overlay-001",
            overlayDigest: overlayDigest,
            integrationApproval: approval,
            approvalSourceArtifactID: "integration-review-report",
            approvalSourceArtifactDigest: digest("6"),
            approvalSidecarRelativePath: approvalSidecarPath,
            approvalSidecarDigest: digest("7"),
            approvalTimestamp: Date(timeIntervalSince1970: 1_783_315_200),
            activationTransformIdentity: CandidateOverlayTransformDescriptor.v1.identity,
            activationTransformDigest: CandidateOverlayTransformDescriptor.v1.digest,
            resolvedActivationDigest: digest("a"),
            baseSnapshotContentDigest: digest("8"),
            basePluginInventoryDigest: digest("b"),
            resolvedPluginInventoryDigest: digest("c"),
            publishedSnapshotContentDigest: digest("9"),
            digestTransitions: [transition]
        )
    }

    func digest(_ character: Character) throws -> HashDigest {
        try HashDigest(validating: String(repeating: character, count: 64))
    }
}
