import Foundation
@testable import IFLContracts
import Testing

@Suite("CanonActivationContractTests")
struct CanonActivationContractTests {
    @Test("overlay binds exact typed families and independent component approvals")
    func overlayRequiresCompleteTypedBindings() throws {
        let overlay = try validOverlay()
        #expect(overlay.rules[0].relativePath == "rules/test.rules.json")
        #expect(overlay.profiles[0].orderedRuleIDs.map(\.rawValue) == ["TEST-CANON-001"])
        #expect(overlay.requirementTraceability[0].registryRelativePath == "registry/requirements.json")
        #expect(overlay.indexes[0].entries.map(\.id) == ["entry-b", "skill.test"])
        #expect(overlay.derivedRegistrationDeltas[0].targets.map(\.indexKey) == ["skill.test"])

        #expect(throws: ContractError.self) {
            try validOverlay(migrations: [])
        }
        #expect(throws: ContractError.self) {
            try validOverlay(indexes: [])
        }

        let componentDigest = try digest("1")
        let owner = try approval(
            approvalID: "approval-owner",
            principalID: "principal-owner",
            actorID: "actor-owner",
            roleID: "Canon Maintainer",
            componentDigest: componentDigest
        )
        let sameActor = try approval(
            approvalID: "approval-same-actor",
            principalID: "principal-other",
            actorID: "actor-owner",
            roleID: "Independent Reviewer",
            componentDigest: componentDigest
        )
        let samePrincipal = try approval(
            approvalID: "approval-same-principal",
            principalID: "principal-owner",
            actorID: "actor-other",
            roleID: "Independent Reviewer",
            componentDigest: componentDigest
        )
        #expect(throws: ContractError.self) {
            try ReviewedComponentApproval(
                componentID: "component-core",
                componentKind: "canon_bundle",
                componentDigest: componentDigest,
                accountableOwnerApproval: owner,
                independentReviewerApproval: sameActor
            )
        }
        #expect(throws: ContractError.self) {
            try ReviewedComponentApproval(
                componentID: "component-core",
                componentKind: "canon_bundle",
                componentDigest: componentDigest,
                accountableOwnerApproval: owner,
                independentReviewerApproval: samePrincipal
            )
        }
    }

    @Test("activation fields reject orphan, ambiguous, and uncovered typed bindings")
    func activationFieldJoinAndCoverage() throws {
        let overlay = try validOverlay()
        let requiredPaths = [
            "rules/test.rules.json",
            "adrs/ADR-9999.json",
            "registry/requirements.json",
            "indexes/canon.index.json",
            "skills/test/SKILL.md",
        ]
        for path in requiredPaths {
            let missing = overlay.activationFields.filter { $0.relativePath != path }
            #expect(throws: ContractError.self) {
                try validOverlay(activationFields: missing)
            }
        }

        var orphaned = overlay.activationFields
        try orphaned.append(ActivationFieldReference(
            relativePath: "rules/orphan.rules.json",
            jsonPointer: "/rules/0/lifecycle"
        ))
        #expect(throws: ContractError.self) {
            try validOverlay(activationFields: orphaned)
        }

        let ambiguousRequirement = try RequirementTraceabilityOverlayBinding(
            requirementID: RequirementID(validating: "REQ-OTHER"),
            reviewedComponentID: "component-core",
            registryRelativePath: "registry/requirements.json",
            requirementJSONPointer: "/requirements/0/status",
            traceabilityJSONPointer: "/traceability/0",
            beforeRequirementRecordDigest: nil,
            beforeTraceabilityRecordDigest: nil,
            candidateRequirementRecordDigest: digest("1"),
            candidateTraceabilityRecordDigest: digest("2"),
            expectedActivatedRequirementDigest: digest("3"),
            expectedActivatedTraceabilityDigest: digest("4")
        )
        #expect(throws: ContractError.self) {
            try validOverlay(
                requirementTraceability: overlay.requirementTraceability + [ambiguousRequirement]
            )
        }
    }

    @Test("requirement activation pointers use exact vocabulary and canonical record index")
    func requirementActivationPointerVocabularyAndIdentity() throws {
        #expect(throws: ContractError.self) {
            try requirementBinding(
                requirementJSONPointer: "/records/0/status",
                traceabilityJSONPointer: "/traceability/0"
            )
        }
        #expect(throws: ContractError.self) {
            try requirementBinding(
                requirementJSONPointer: "/requirements/0/status",
                traceabilityJSONPointer: "/traceability/0/status"
            )
        }

        let first = try requirementBinding(
            requirementID: "REQ-CONVERGENCE",
            recordIndex: 0
        )
        let wrongSecond = try requirementBinding(
            requirementID: "REQ-OTHER",
            recordIndex: 2
        )
        let overlay = try validOverlay()
        var fields = overlay.activationFields.filter {
            $0.relativePath != "registry/requirements.json"
        }
        fields += try [
            ActivationFieldReference(
                relativePath: "registry/requirements.json",
                jsonPointer: "/requirements/0/status"
            ),
            ActivationFieldReference(
                relativePath: "registry/requirements.json",
                jsonPointer: "/traceability/0"
            ),
            ActivationFieldReference(
                relativePath: "registry/requirements.json",
                jsonPointer: "/requirements/2/status"
            ),
            ActivationFieldReference(
                relativePath: "registry/requirements.json",
                jsonPointer: "/traceability/2"
            ),
        ]
        #expect(throws: ContractError.self) {
            try validOverlay(
                requirementTraceability: [first, wrongSecond],
                activationFields: fields
            )
        }
    }

    @Test("derived publication index keys are globally unique")
    func derivedPublicationIndexKeysAreGloballyUnique() throws {
        let overlay = try validOverlay()
        let duplicateIndexKey = try derivedBinding(
            deltaID: "delta-002",
            relativePath: "registry/derived-002.delta.json",
            indexKey: "skill.test",
            targetPath: "skills/other/SKILL.md",
            digestCharacter: "8"
        )
        var activationFields = overlay.activationFields
        try activationFields.append(ActivationFieldReference(
            relativePath: "skills/other/SKILL.md",
            jsonPointer: ""
        ))
        let error = contractError {
            _ = try validOverlay(
                derivedRegistrationDeltas: overlay.derivedRegistrationDeltas + [duplicateIndexKey],
                activationFields: activationFields
            )
        }
        #expect(error == .duplicateIdentifier(
            kind: "derived_target_index",
            id: "skill.test"
        ))
    }

    @Test("derived publication target paths are globally unique")
    func derivedPublicationTargetPathsAreGloballyUnique() throws {
        let overlay = try validOverlay()
        let duplicateTargetPath = try derivedBinding(
            deltaID: "delta-002",
            relativePath: "registry/derived-002.delta.json",
            indexKey: "entry-b",
            targetPath: "skills/test/SKILL.md",
            digestCharacter: "8"
        )
        let error = contractError {
            _ = try validOverlay(
                derivedRegistrationDeltas: overlay.derivedRegistrationDeltas + [duplicateTargetPath],
                activationFields: overlay.activationFields
            )
        }
        #expect(error == .duplicateIdentifier(
            kind: "derived_target_path",
            id: "skills/test/SKILL.md"
        ))
    }

    @Test("derived target paths cannot overlap any governed artifact family")
    func derivedTargetPathsAreDisjointFromGovernedArtifacts() throws {
        let overlay = try validOverlay()
        let defaultTargetPath = try #require(
            overlay.derivedRegistrationDeltas.first?.targets.first?.targetPath
        )
        let activationFieldsWithoutTarget = overlay.activationFields.filter {
            !($0.relativePath == defaultTargetPath && $0.jsonPointer.isEmpty)
        }

        for (_, collisionPath) in [
            ("rule", "rules/test.rules.json"),
            ("adr", "adrs/ADR-9999.json"),
            ("requirement_registry", "registry/requirements.json"),
            ("traceability", "registry/requirements.json"),
            ("index", "indexes/canon.index.json"),
            ("delta", "registry/derived.delta.json"),
            ("chapter", "chapters/chapter.json"),
            ("check", "checks/check.json"),
            ("fixture", "fixtures/fixture.json"),
            ("migration", "migrations/migration.json"),
        ] {
            let collision = try derivedBinding(
                targetPath: collisionPath,
                digestCharacter: "8"
            )
            let collisionField = try ActivationFieldReference(
                relativePath: collisionPath,
                jsonPointer: ""
            )
            let error = contractError {
                _ = try validOverlay(
                    derivedRegistrationDeltas: [collision],
                    activationFields: activationFieldsWithoutTarget + [collisionField]
                )
            }
            #expect(error == .duplicateIdentifier(
                kind: "overlay_artifact_path",
                id: collisionPath
            ))
        }
    }

    @Test("derived activation authorizes exact target and index surfaces, never delta metadata")
    func derivedActivationUsesPublicationSurfaces() throws {
        let overlay = try validOverlay()
        let deltaPath = try #require(overlay.derivedRegistrationDeltas.first?.relativePath)
        let targetPath = try #require(
            overlay.derivedRegistrationDeltas.first?.targets.first?.targetPath
        )
        let fieldsWithoutDerived = overlay.activationFields.filter {
            $0.relativePath != deltaPath && $0.relativePath != targetPath
        }
        let deltaMetadataField = try ActivationFieldReference(
            relativePath: deltaPath,
            jsonPointer: "/entries/0/file_digest"
        )
        let deltaMetadataFields = fieldsWithoutDerived + [deltaMetadataField]
        #expect(throws: ContractError.self) {
            try validOverlay(activationFields: deltaMetadataFields)
        }

        let targetField = try ActivationFieldReference(
            relativePath: targetPath,
            jsonPointer: ""
        )
        let targetFields = fieldsWithoutDerived + [targetField]
        let bound = try validOverlay(activationFields: targetFields)
        #expect(bound.activationFields.contains {
            $0.relativePath == targetPath && $0.jsonPointer.isEmpty
        })
    }

    @Test("activation transitions preserve exact family-specific identifiers")
    func activationTransitionExactIdentifierGrammar() throws {
        for (kind, id, path) in [
            ("check", "CHK-CAN-001", "checks/canon.json"),
            ("fixture", "FIX-CAN-001", "fixtures/canon.json"),
            ("migration", "MIG-CAN-001", "migrations/canon.json"),
        ] {
            let transition = try ActivationDigestTransition(
                componentKind: kind,
                componentID: id,
                relativePath: path,
                beforeFullDigest: nil,
                afterFullDigest: digest("4")
            )
            #expect(transition.componentID == id)
        }

        for (kind, id) in [
            ("check", "check-001"),
            ("fixture", "CHK-WRONG-001"),
            ("migration", "FIX-WRONG-001"),
        ] {
            #expect(throws: ContractError.self) {
                try ActivationDigestTransition(
                    componentKind: kind,
                    componentID: id,
                    relativePath: "artifacts/value.json",
                    beforeFullDigest: nil,
                    afterFullDigest: digest("4")
                )
            }
        }
    }

    @Test("every declared index entry has an activation field")
    func indexActivationCoverageIsPerEntry() throws {
        let overlay = try validOverlay()
        let incomplete = overlay.activationFields.filter {
            $0.jsonPointer != "/entries/entry-b/record_digest"
        }
        #expect(throws: ContractError.self) {
            try validOverlay(activationFields: incomplete)
        }
    }

    @Test("RFC 6901 escaped identifiers join against decoded index entry IDs")
    func escapedJSONPointerTokensJoinByIdentifier() throws {
        let overlay = try validOverlay()
        let escapedIndex = try IndexOverlayBinding(
            id: "canon-index",
            relativePath: "indexes/canon.index.json",
            beforeFullDigest: nil,
            expectedActivatedFullDigest: digest("d"),
            entries: [
                IndexEntryOverlayBinding(id: "entry/a~b", expectedRecordDigest: digest("a")),
                IndexEntryOverlayBinding(id: "skill.test", expectedRecordDigest: digest("b")),
            ]
        )
        var fields = overlay.activationFields.filter {
            $0.relativePath != "indexes/canon.index.json"
        }
        fields += try [
            ActivationFieldReference(
                relativePath: "indexes/canon.index.json",
                jsonPointer: "/entries/entry~1a~0b/record_digest"
            ),
            ActivationFieldReference(
                relativePath: "indexes/canon.index.json",
                jsonPointer: "/entries/skill.test/record_digest"
            ),
        ]
        let bound = try validOverlay(indexes: [escapedIndex], activationFields: fields)
        #expect(bound.indexes[0].entries.map(\.id) == ["entry/a~b", "skill.test"])
    }

    @Test("optional before digests are absent and explicit null is rejected")
    func optionalBeforeDigestWireContract() throws {
        let rule = try RuleOverlayBinding(
            id: RuleID(validating: "TEST-CANON-001"),
            reviewedComponentID: "component-core",
            relativePath: "rules/test.rules.json",
            semanticDigest: digest("1"),
            beforeFullDigest: nil,
            expectedActivatedFullDigest: digest("2")
        )
        try assertAbsentAndNullRejected(
            rule,
            key: "before_full_digest",
            type: RuleOverlayBinding.self
        )

        let adr = try ADROverlayBinding(
            id: ADRIdentifier(validating: "ADR-9999"),
            reviewedComponentID: "component-core",
            relativePath: "adrs/ADR-9999.json",
            semanticDigest: digest("3"),
            beforeFullDigest: nil,
            expectedActivatedFullDigest: digest("4")
        )
        try assertAbsentAndNullRejected(
            adr,
            key: "before_full_digest",
            type: ADROverlayBinding.self
        )

        let requirement = try requirementBinding(
            beforeRequirementRecordDigest: nil,
            beforeTraceabilityRecordDigest: nil
        )
        try assertAbsentAndNullRejected(
            requirement,
            key: "before_requirement_record_digest",
            type: RequirementTraceabilityOverlayBinding.self
        )
        try assertAbsentAndNullRejected(
            requirement,
            key: "before_traceability_record_digest",
            type: RequirementTraceabilityOverlayBinding.self
        )

        let index = try indexBinding(beforeFullDigest: nil)
        try assertAbsentAndNullRejected(
            index,
            key: "before_full_digest",
            type: IndexOverlayBinding.self
        )

        let transition = try ActivationDigestTransition(
            componentKind: "rule",
            componentID: "TEST-CANON-001",
            relativePath: "rules/test.rules.json",
            beforeFullDigest: nil,
            afterFullDigest: digest("5")
        )
        try assertAbsentAndNullRejected(
            transition,
            key: "before_full_digest",
            type: ActivationDigestTransition.self
        )
    }

    @Test("overlay rejects unchecked IDs, unknown keys, noncanonical arrays, and non-SemVer versions")
    func overlayStrictDecodingAndIdentifiers() throws {
        #expect(throws: ContractError.self) {
            try RuleOverlayBinding(
                id: RuleID(rawValue: "unchecked"),
                reviewedComponentID: "component-core",
                relativePath: "rules/test.rules.json",
                semanticDigest: digest("1"),
                beforeFullDigest: nil,
                expectedActivatedFullDigest: digest("2")
            )
        }
        #expect(throws: ContractError.self) {
            try RequirementTraceabilityOverlayBinding(
                requirementID: RequirementID(rawValue: "unchecked"),
                reviewedComponentID: "component-core",
                registryRelativePath: "registry/requirements.json",
                requirementJSONPointer: "/requirements/0/status",
                traceabilityJSONPointer: "/traceability/0",
                beforeRequirementRecordDigest: nil,
                beforeTraceabilityRecordDigest: nil,
                candidateRequirementRecordDigest: digest("1"),
                candidateTraceabilityRecordDigest: digest("2"),
                expectedActivatedRequirementDigest: digest("3"),
                expectedActivatedTraceabilityDigest: digest("4")
            )
        }

        for invalidVersion in ["1", "1.0", "01.0.0", "1.0.0-", "1.0.0+bad!", "1.0.0-01"] {
            #expect(throws: ContractError.self) {
                try validOverlay(targetProductVersion: invalidVersion)
            }
        }

        let overlay = try validOverlay()
        var unknown = try jsonObject(overlay)
        unknown["integration_approval"] = ["approval_id": "must-not-be-here"]
        #expect(throws: ContractError.self) {
            try CanonicalJSON.decode(
                CandidateOverlayManifest.self,
                from: jsonData(unknown)
            )
        }

        var noncanonical = try jsonObject(overlay)
        var indexes = try #require(noncanonical["indexes"] as? [[String: Any]])
        var entries = try #require(indexes[0]["entries"] as? [[String: Any]])
        entries.reverse()
        indexes[0]["entries"] = entries
        noncanonical["indexes"] = indexes
        #expect(throws: ContractError.self) {
            try CanonicalJSON.decode(
                CandidateOverlayManifest.self,
                from: jsonData(noncanonical)
            )
        }
    }

    @Test("activation receipt binds exact overlay approval and excludes activation metadata")
    func activationReceiptContract() throws {
        let receipt = try validReceipt()
        #expect(receipt.digestTransitions.count == 1)

        let keys = try Set(jsonObject(receipt).keys)
        #expect(!keys.contains("receipt_digest"))
        #expect(!keys.contains("post_root_digest"))

        #expect(throws: ContractError.self) {
            try validReceipt(approvalOverlayID: "overlay-other")
        }
        #expect(throws: ContractError.self) {
            try validReceipt(approvalDigestCharacter: "4")
        }
        #expect(throws: ContractError.self) {
            try validReceipt(publishedDigestCharacter: "8")
        }
        #expect(throws: ContractError.self) {
            try validReceipt(targetProductVersion: "1.0")
        }
        #expect(throws: ContractError.self) {
            try ActivationDigestTransition(
                componentKind: "rule",
                componentID: "TEST-CANON-001",
                relativePath: "activations/overlay-001.receipt.json",
                beforeFullDigest: digest("3"),
                afterFullDigest: digest("4")
            )
        }
        #expect(throws: ContractError.self) {
            try ActivationDigestTransition(
                componentKind: "approval_sidecar",
                componentID: "sidecar-001",
                relativePath: "rules/test.rules.json",
                beforeFullDigest: digest("3"),
                afterFullDigest: digest("4")
            )
        }
    }

    @Test("activation transition kind is closed and component IDs are kind-aware")
    func activationTransitionKindAndIDGrammar() throws {
        #expect(throws: ContractError.self) {
            try ActivationDigestTransition(
                componentKind: "unknown",
                componentID: "component-001",
                relativePath: "rules/test.rules.json",
                beforeFullDigest: nil,
                afterFullDigest: digest("4")
            )
        }
        #expect(throws: ContractError.self) {
            try ActivationDigestTransition(
                componentKind: "rule",
                componentID: "unchecked",
                relativePath: "rules/test.rules.json",
                beforeFullDigest: nil,
                afterFullDigest: digest("4")
            )
        }
        #expect(throws: ContractError.self) {
            try ActivationDigestTransition(
                componentKind: "adr",
                componentID: "ADR-1",
                relativePath: "adrs/ADR-1.json",
                beforeFullDigest: nil,
                afterFullDigest: digest("4")
            )
        }
        #expect(throws: ContractError.self) {
            try ActivationDigestTransition(
                componentKind: "index",
                componentID: "Index Bad",
                relativePath: "indexes/canon.index.json",
                beforeFullDigest: nil,
                afterFullDigest: digest("4")
            )
        }
    }

    @Test("approval and exception timestamps must round-trip through canonical JSON exactly")
    func canonicalTimestampContract() throws {
        let subMillisecond = Date(timeIntervalSince1970: 1_783_315_200.1234)
        #expect(throws: ContractError.self) {
            try validReceipt(approvalTimestamp: subMillisecond)
        }
        #expect(throws: ContractError.self) {
            try validException(expiresAt: subMillisecond)
        }

        var receiptObject = try jsonObject(validReceipt())
        receiptObject["approval_timestamp"] = "2026-07-06T00:00:00.000+00:00"
        #expect(throws: ContractError.self) {
            try CanonicalJSON.decode(
                CanonActivationReceipt.self,
                from: jsonData(receiptObject)
            )
        }

        var exceptionObject = try jsonObject(validException())
        exceptionObject["expires_at"] = "2027-07-06T00:00:00.000+00:00"
        #expect(throws: ContractError.self) {
            try CanonicalJSON.decode(
                ExceptionRecord.self,
                from: jsonData(exceptionObject)
            )
        }
    }

    @Test("exceptions are exact, compensated, expiring, and independently approved")
    func exceptionContract() throws {
        let exception = try validException()
        #expect(exception.ruleID.rawValue == "TEST-CANON-001")

        #expect(throws: ContractError.self) {
            try validException(exactScope: ["*"])
        }
        #expect(throws: ContractError.self) {
            try validException(approverPrincipalID: "principal-owner")
        }
        #expect(throws: ContractError.self) {
            try validException(approverActorID: "actor-owner")
        }
        #expect(throws: ContractError.self) {
            try validException(compensatingControls: [])
        }
    }

    @Test("derived registration delta has closed semantic sources and exact citation joins")
    func derivedRegistrationSemanticBindings() throws {
        #expect(throws: ContractError.self) {
            try SourceSemanticBinding(
                sourceKind: "skill",
                sourceID: "skill-001",
                digest: digest("1")
            )
        }
        #expect(throws: ContractError.self) {
            try SourceSemanticBinding(
                sourceKind: "rule",
                sourceID: "unchecked",
                digest: digest("1")
            )
        }
        #expect(throws: ContractError.self) {
            try DerivedRegistrationEntry(
                indexKey: "skill.test",
                targetPath: "skills/test/SKILL.md",
                artifactKind: "skill",
                fileDigest: digest("1"),
                citedRuleIDs: [RuleID(validating: "TEST-CANON-001")],
                citedADRIDs: [ADRIdentifier(validating: "ADR-9999")],
                sourceSemanticBindings: [
                    SourceSemanticBinding(
                        sourceKind: "rule",
                        sourceID: "TEST-CANON-001",
                        digest: digest("2")
                    ),
                ]
            )
        }
        #expect(throws: ContractError.self) {
            try DerivedRegistrationEntry(
                indexKey: "skill.test",
                targetPath: "skills/test/SKILL.md",
                artifactKind: "skill",
                fileDigest: digest("1"),
                citedRuleIDs: [],
                citedADRIDs: [],
                sourceSemanticBindings: [
                    SourceSemanticBinding(
                        sourceKind: "adr",
                        sourceID: "ADR-9999",
                        digest: digest("2")
                    ),
                ]
            )
        }
    }

    @Test("derived registration delta digest excludes delta_digest and detects tampering")
    func derivedRegistrationDeltaDigest() throws {
        let entryB = try derivedEntry(targetPath: "skills/zeta/SKILL.md", digestCharacter: "b")
        let entryA = try derivedEntry(targetPath: "agents/alpha.md", digestCharacter: "a")
        let delta = try DerivedRegistrationDelta(
            schemaVersion: 1,
            deltaID: "delta-001",
            ownerRoleID: "Runtime/Skill Owner",
            baseSnapshotContentDigest: digest("0"),
            entries: [entryB, entryA]
        )
        #expect(delta.entries.map(\.targetPath) == ["agents/alpha.md", "skills/zeta/SKILL.md"])

        let encoded = try CanonicalJSON.encode(delta)
        var payloadObject = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        payloadObject.removeValue(forKey: "delta_digest")
        let payloadData = try JSONSerialization.data(
            withJSONObject: payloadObject,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        let independentlyComputed = CanonicalTreeDigest.sha256(payloadData)
        #expect(independentlyComputed == delta.deltaDigest)

        let decoded = try CanonicalJSON.decode(DerivedRegistrationDelta.self, from: encoded)
        #expect(decoded == delta)

        var tampered = try jsonObject(delta)
        tampered["delta_digest"] = try digest("e").rawValue
        #expect(throws: ContractError.self) {
            try CanonicalJSON.decode(
                DerivedRegistrationDelta.self,
                from: jsonData(tampered)
            )
        }

        var noncanonical = try jsonObject(delta)
        var entries = try #require(noncanonical["entries"] as? [[String: Any]])
        entries.reverse()
        noncanonical["entries"] = entries
        #expect(throws: ContractError.self) {
            try CanonicalJSON.decode(
                DerivedRegistrationDelta.self,
                from: jsonData(noncanonical)
            )
        }
    }
}

private extension CanonActivationContractTests {
    func validOverlay(
        targetProductVersion: String = "1.0.0-rc.1",
        migrations: [ExactArtifactBinding]? = nil,
        requirementTraceability: [RequirementTraceabilityOverlayBinding]? = nil,
        indexes: [IndexOverlayBinding]? = nil,
        derivedRegistrationDeltas: [DerivedRegistrationOverlayBinding]? = nil,
        activationFields: [ActivationFieldReference]? = nil
    ) throws -> CandidateOverlayManifest {
        let componentDigest = try digest("1")
        let reviewed = try ReviewedComponentApproval(
            componentID: "component-core",
            componentKind: "canon_bundle",
            componentDigest: componentDigest,
            accountableOwnerApproval: approval(
                approvalID: "approval-owner",
                principalID: "principal-owner",
                actorID: "actor-owner",
                roleID: "Canon Maintainer",
                componentDigest: componentDigest
            ),
            independentReviewerApproval: approval(
                approvalID: "approval-reviewer",
                principalID: "principal-reviewer",
                actorID: "actor-reviewer",
                roleID: "Independent Reviewer",
                componentDigest: componentDigest
            )
        )
        let chapter = try exactBinding(id: "chapter-001", path: "chapters/chapter.json", digestCharacter: "2")
        let check = try exactBinding(id: "CHK-CAN-001", path: "checks/check.json", digestCharacter: "3")
        let fixture = try exactBinding(id: "FIX-CAN-001", path: "fixtures/fixture.json", digestCharacter: "4")
        let migration = try exactBinding(id: "MIG-CAN-001", path: "migrations/migration.json", digestCharacter: "5")
        let defaultRequirement = try requirementBinding(
            beforeRequirementRecordDigest: nil,
            beforeTraceabilityRecordDigest: nil
        )
        let defaultIndex = try indexBinding(beforeFullDigest: nil)
        let derived = try DerivedRegistrationOverlayBinding(
            deltaID: "delta-001",
            reviewedComponentID: "component-core",
            relativePath: "registry/derived.delta.json",
            deltaDigest: digest("6"),
            targets: [
                DerivedTargetBinding(
                    indexKey: "skill.test",
                    targetPath: "skills/test/SKILL.md",
                    expectedFileDigest: digest("7")
                ),
            ]
        )
        let defaultActivationFields = try [
            ActivationFieldReference(
                relativePath: "rules/test.rules.json",
                jsonPointer: "/rules/0/lifecycle"
            ),
            ActivationFieldReference(
                relativePath: "adrs/ADR-9999.json",
                jsonPointer: "/adrs/0/status"
            ),
            ActivationFieldReference(
                relativePath: "registry/requirements.json",
                jsonPointer: "/requirements/0/status"
            ),
            ActivationFieldReference(
                relativePath: "registry/requirements.json",
                jsonPointer: "/traceability/0"
            ),
            ActivationFieldReference(
                relativePath: "indexes/canon.index.json",
                jsonPointer: "/entries/entry-b/record_digest"
            ),
            ActivationFieldReference(
                relativePath: "indexes/canon.index.json",
                jsonPointer: "/entries/skill.test/record_digest"
            ),
            ActivationFieldReference(
                relativePath: "skills/test/SKILL.md",
                jsonPointer: ""
            ),
        ]

        return try CandidateOverlayManifest(
            schemaVersion: 1,
            overlayID: "overlay-001",
            targetCanonVersion: 1,
            targetProductVersion: targetProductVersion,
            baseSnapshotContentDigest: digest("0"),
            reviewedComponents: [reviewed],
            rules: [RuleOverlayBinding(
                id: RuleID(validating: "TEST-CANON-001"),
                reviewedComponentID: "component-core",
                relativePath: "rules/test.rules.json",
                semanticDigest: digest("3"),
                beforeFullDigest: nil,
                expectedActivatedFullDigest: digest("5")
            )],
            profiles: [ProfileOverlayBinding(
                id: ProfileID(validating: "minimal"),
                reviewedComponentID: "component-core",
                exactFileDigest: digest("6"),
                orderedRuleIDs: [RuleID(validating: "TEST-CANON-001")]
            )],
            adrs: [ADROverlayBinding(
                id: ADRIdentifier(validating: "ADR-9999"),
                reviewedComponentID: "component-core",
                relativePath: "adrs/ADR-9999.json",
                semanticDigest: digest("7"),
                beforeFullDigest: digest("8"),
                expectedActivatedFullDigest: digest("9")
            )],
            chapters: [chapter],
            requirementTraceability: requirementTraceability ?? [defaultRequirement],
            checks: [check],
            fixtures: [fixture],
            migrations: migrations ?? [migration],
            indexes: indexes ?? [defaultIndex],
            derivedRegistrationDeltas: derivedRegistrationDeltas ?? [derived],
            activationFields: activationFields ?? defaultActivationFields,
            expectedPublishedSnapshotContentDigest: digest("e")
        )
    }

    func requirementBinding(
        requirementID: String = "REQ-CONVERGENCE",
        recordIndex: Int = 0,
        requirementJSONPointer: String? = nil,
        traceabilityJSONPointer: String? = nil,
        beforeRequirementRecordDigest: HashDigest? = nil,
        beforeTraceabilityRecordDigest: HashDigest? = nil
    ) throws -> RequirementTraceabilityOverlayBinding {
        try RequirementTraceabilityOverlayBinding(
            requirementID: RequirementID(validating: requirementID),
            reviewedComponentID: "component-core",
            registryRelativePath: "registry/requirements.json",
            requirementJSONPointer: requirementJSONPointer ?? "/requirements/\(recordIndex)/status",
            traceabilityJSONPointer: traceabilityJSONPointer ?? "/traceability/\(recordIndex)",
            beforeRequirementRecordDigest: beforeRequirementRecordDigest,
            beforeTraceabilityRecordDigest: beforeTraceabilityRecordDigest,
            candidateRequirementRecordDigest: digest("a"),
            candidateTraceabilityRecordDigest: digest("b"),
            expectedActivatedRequirementDigest: digest("c"),
            expectedActivatedTraceabilityDigest: digest("d")
        )
    }

    func indexBinding(beforeFullDigest: HashDigest?) throws -> IndexOverlayBinding {
        try IndexOverlayBinding(
            id: "canon-index",
            relativePath: "indexes/canon.index.json",
            beforeFullDigest: beforeFullDigest,
            expectedActivatedFullDigest: digest("d"),
            entries: [
                IndexEntryOverlayBinding(id: "skill.test", expectedRecordDigest: digest("b")),
                IndexEntryOverlayBinding(id: "entry-b", expectedRecordDigest: digest("a")),
            ]
        )
    }

    func derivedBinding(
        deltaID: String = "delta-001",
        relativePath: String = "registry/derived.delta.json",
        indexKey: String = "skill.test",
        targetPath: String = "skills/test/SKILL.md",
        digestCharacter: Character = "7"
    ) throws -> DerivedRegistrationOverlayBinding {
        try DerivedRegistrationOverlayBinding(
            deltaID: deltaID,
            reviewedComponentID: "component-core",
            relativePath: relativePath,
            deltaDigest: digest("6"),
            targets: [
                DerivedTargetBinding(
                    indexKey: indexKey,
                    targetPath: targetPath,
                    expectedFileDigest: digest(digestCharacter)
                ),
            ]
        )
    }

    func validReceipt(
        targetProductVersion: String = "1.0.0-rc.1",
        approvalOverlayID: String = "overlay-001",
        approvalDigestCharacter: Character = "5",
        publishedDigestCharacter: Character = "9",
        approvalTimestamp: Date = Date(timeIntervalSince1970: 1_783_315_200)
    ) throws -> CanonActivationReceipt {
        let reference = try approval(
            approvalID: "integration-approval",
            principalID: "principal-integration",
            actorID: "actor-integration",
            roleID: "Integration Reviewer",
            componentID: approvalOverlayID,
            componentDigest: digest(approvalDigestCharacter)
        )
        let transition = try ActivationDigestTransition(
            componentKind: "rule",
            componentID: "TEST-CANON-001",
            relativePath: "rules/test.rules.json",
            beforeFullDigest: digest("3"),
            afterFullDigest: digest("4")
        )
        return try CanonActivationReceipt(
            schemaVersion: 1,
            activationID: "activation-001",
            transactionID: "transaction-001",
            targetCanonVersion: 1,
            targetProductVersion: targetProductVersion,
            overlayID: "overlay-001",
            overlayDigest: digest("5"),
            integrationApproval: reference,
            approvalSourceArtifactID: "integration-review-report",
            approvalSourceArtifactDigest: digest("6"),
            approvalSidecarRelativePath: "activations/overlay-001.approval.json",
            approvalSidecarDigest: digest("7"),
            approvalTimestamp: approvalTimestamp,
            baseSnapshotContentDigest: digest("8"),
            publishedSnapshotContentDigest: digest(publishedDigestCharacter),
            digestTransitions: [transition]
        )
    }

    func approval(
        approvalID: String,
        principalID: String,
        actorID: String,
        roleID: String,
        componentID: String = "component-core",
        componentDigest: HashDigest
    ) throws -> ReviewApprovalReference {
        try ReviewApprovalReference(
            schemaVersion: 1,
            approvalID: approvalID,
            principalID: principalID,
            actorID: actorID,
            roleID: roleID,
            reviewedComponentID: componentID,
            reviewedComponentDigest: componentDigest,
            attestationID: "attestation-\(approvalID)",
            attestationDigest: digest("f")
        )
    }

    func exactBinding(
        id: String,
        path: String,
        digestCharacter: Character
    ) throws -> ExactArtifactBinding {
        try ExactArtifactBinding(
            id: id,
            reviewedComponentID: "component-core",
            relativePath: path,
            digest: digest(digestCharacter)
        )
    }

    func validException(
        exactScope: [String] = ["rules/test.rules.json"],
        approverPrincipalID: String = "principal-approver",
        approverActorID: String = "actor-approver",
        compensatingControls: [String] = ["Independent verification on every change"],
        expiresAt: Date = Date(timeIntervalSince1970: 1_814_860_800)
    ) throws -> ExceptionRecord {
        try ExceptionRecord(
            schemaVersion: 1,
            id: "exception-001",
            ruleID: RuleID(validating: "TEST-CANON-001"),
            exactScope: exactScope,
            reason: "Temporary migration constraint",
            riskClass: .high,
            compensatingControls: compensatingControls,
            ownerPrincipalID: "principal-owner",
            ownerActorID: "actor-owner",
            ownerRoleID: "Canon Maintainer",
            approverPrincipalID: approverPrincipalID,
            approverActorID: approverActorID,
            approverRoleID: "Independent Reviewer",
            expiresAt: expiresAt,
            affectedArtifactDigest: digest("a"),
            removalPlan: "Remove after migration completes"
        )
    }

    func derivedEntry(
        targetPath: String,
        digestCharacter: Character
    ) throws -> DerivedRegistrationEntry {
        try DerivedRegistrationEntry(
            indexKey: targetPath,
            targetPath: targetPath,
            artifactKind: "skill",
            fileDigest: digest(digestCharacter),
            citedRuleIDs: [RuleID(validating: "TEST-CANON-001")],
            citedADRIDs: [ADRIdentifier(validating: "ADR-9999")],
            sourceSemanticBindings: [
                SourceSemanticBinding(
                    sourceKind: "adr",
                    sourceID: "ADR-9999",
                    digest: digest(digestCharacter)
                ),
                SourceSemanticBinding(
                    sourceKind: "rule",
                    sourceID: "TEST-CANON-001",
                    digest: digest(digestCharacter)
                ),
            ]
        )
    }

    func assertAbsentAndNullRejected<T: Codable>(
        _ value: T,
        key: String,
        type: T.Type
    ) throws {
        var object = try jsonObject(value)
        #expect(object[key] == nil)
        object[key] = NSNull()
        #expect(throws: ContractError.self) {
            try CanonicalJSON.decode(type, from: jsonData(object))
        }
    }

    func digest(_ character: Character) throws -> HashDigest {
        try HashDigest(validating: String(repeating: String(character), count: 64))
    }

    func contractError(_ operation: () throws -> Void) -> ContractError? {
        do {
            try operation()
            return nil
        } catch let error as ContractError {
            return error
        } catch {
            return nil
        }
    }

    func jsonObject(_ value: some Encodable) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: CanonicalJSON.encode(value))
        return try #require(object as? [String: Any])
    }

    func jsonData(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
    }
}
