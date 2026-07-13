import Foundation
@testable import IFLContracts
import Testing

@Suite("CanonActivationContractTests")
struct CanonActivationContractTests {
    @Test("activation receipt binds transform, resolved, base/resolved plugin, published, and approval identities")
    func activationReceiptContract() throws {
        let receipt = try validReceipt()
        #expect(receipt.digestTransitions.count == 1)
        #expect(receipt.activationTransformIdentity == CandidateOverlayTransformDescriptor.v1.identity)
        #expect(receipt.activationTransformDigest == CandidateOverlayTransformDescriptor.v1.digest)
        #expect(try receipt.resolvedActivationDigest == digest("a"))
        #expect(try receipt.basePluginInventoryDigest == digest("b"))
        #expect(try receipt.resolvedPluginInventoryDigest == digest("c"))

        let keys = try Set(jsonObject(receipt).keys)
        #expect(!keys.contains("receipt_digest"))
        #expect(!keys.contains("post_root_digest"))
        #expect(!keys.contains("final_plugin_inventory_digest"))

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
            try validReceipt(transformDigest: digest("e"))
        }

        var unknown = try jsonObject(receipt)
        unknown["final_plugin_inventory_digest"] = try digest("e").rawValue
        #expect(throws: ContractError.self) {
            try CanonicalJSON.decode(CanonActivationReceipt.self, from: jsonData(unknown))
        }
    }

    @Test("activation transitions are path-centric with complete before/after entries and affected components")
    func activationTransitionContract() throws {
        let path = "rules/core/test.rules.json"
        let before = try treeEntry(path: path, digestCharacter: "3", mode: 420)
        let after = try treeEntry(path: path, digestCharacter: "4", mode: 420)
        let transition = try ActivationDigestTransition(
            targetNamespace: .canon,
            targetRelativePath: path,
            affectedComponents: [
                ActivationAffectedComponentReference(componentKind: "standards-core", componentID: "component-z"),
                ActivationAffectedComponentReference(componentKind: "standards-core", componentID: "component-a"),
            ],
            beforeEntry: before,
            afterEntry: after
        )
        #expect(transition.affectedComponents.map(\.componentID) == ["component-a", "component-z"])
        #expect(transition.beforeEntry == before)
        #expect(transition.afterEntry == after)

        #expect(throws: ContractError.self) {
            try ActivationDigestTransition(
                targetNamespace: .canon,
                targetRelativePath: path,
                affectedComponents: transition.affectedComponents,
                beforeEntry: before,
                afterEntry: before
            )
        }
        #expect(throws: ContractError.self) {
            try ActivationDigestTransition(
                targetNamespace: .canon,
                targetRelativePath: path,
                affectedComponents: transition.affectedComponents,
                beforeEntry: before,
                afterEntry: treeEntry(path: "rules/core/other.rules.json", digestCharacter: "4", mode: 420)
            )
        }
        #expect(throws: ContractError.self) {
            try ActivationDigestTransition(
                targetNamespace: .canon,
                targetRelativePath: "activations/overlay.receipt.json",
                affectedComponents: transition.affectedComponents,
                beforeEntry: nil,
                afterEntry: treeEntry(path: "activations/overlay.receipt.json", digestCharacter: "4", mode: 420)
            )
        }

        var object = try jsonObject(transition)
        object["before_entry"] = NSNull()
        #expect(throws: ContractError.self) {
            try CanonicalJSON.decode(ActivationDigestTransition.self, from: jsonData(object))
        }
    }

    @Test("existing transitions preserve regular-file kind and mode while absent-before creates files or directories")
    func activationTransitionKindAndModeInvariants() throws {
        let path = "rules/core/test.rules.json"
        let affected = try [
            ActivationAffectedComponentReference(
                componentKind: "standards-core",
                componentID: "component-core"
            ),
        ]
        let expected = ContractError.invalidContract(
            kind: "activation_digest_transition",
            reason: "an existing transition must retain a regular file and its exact mode"
        )

        try expectContractError(expected) {
            try ActivationDigestTransition(
                targetNamespace: .canon,
                targetRelativePath: path,
                affectedComponents: affected,
                beforeEntry: treeEntry(path: path, digestCharacter: "3", mode: 420),
                afterEntry: treeEntry(path: path, digestCharacter: "4", mode: 493)
            )
        }
        try expectContractError(expected) {
            try ActivationDigestTransition(
                targetNamespace: .canon,
                targetRelativePath: path,
                affectedComponents: affected,
                beforeEntry: directoryEntry(path: path),
                afterEntry: treeEntry(path: path, digestCharacter: "4", mode: 493)
            )
        }
        try expectContractError(expected) {
            try ActivationDigestTransition(
                targetNamespace: .canon,
                targetRelativePath: path,
                affectedComponents: affected,
                beforeEntry: treeEntry(path: path, digestCharacter: "3", mode: 493),
                afterEntry: directoryEntry(path: path)
            )
        }

        let newFile = try ActivationDigestTransition(
            targetNamespace: .canon,
            targetRelativePath: path,
            affectedComponents: affected,
            beforeEntry: nil,
            afterEntry: treeEntry(path: path, digestCharacter: "4", mode: 420)
        )
        let directoryPath = "rules/core/new"
        let newDirectory = try ActivationDigestTransition(
            targetNamespace: .canon,
            targetRelativePath: directoryPath,
            affectedComponents: affected,
            beforeEntry: nil,
            afterEntry: directoryEntry(path: directoryPath)
        )
        #expect(newFile.beforeEntry == nil)
        #expect(newDirectory.afterEntry.kind == .directory)
    }

    @Test("activation receipt schema enumerates every representable transition mode and kind")
    func activationTransitionSchemaParity() throws {
        let schemaRoot = try activationReceiptSchema()
        let definitions = try #require(schemaRoot["$defs"] as? [String: Any])
        let transitionSchema = try #require(
            definitions["activation_digest_transition"] as? [String: Any]
        )
        let valid = try jsonObject(validReceipt().digestTransitions[0])
        #expect(schemaAccepts(valid, against: transitionSchema, root: schemaRoot))

        var chmod = valid
        var chmodAfter = try #require(chmod["after_entry"] as? [String: Any])
        chmodAfter["mode"] = 493
        chmod["after_entry"] = chmodAfter
        #expect(!schemaAccepts(chmod, against: transitionSchema, root: schemaRoot))

        var directoryReplacement = valid
        directoryReplacement["before_entry"] = [
            "kind": "directory",
            "mode": 493,
            "relative_path": "rules/core/test.rules.json",
        ]
        var fileAfter = try #require(directoryReplacement["after_entry"] as? [String: Any])
        fileAfter["mode"] = 493
        directoryReplacement["after_entry"] = fileAfter
        #expect(!schemaAccepts(directoryReplacement, against: transitionSchema, root: schemaRoot))

        var newDirectory = valid
        newDirectory.removeValue(forKey: "before_entry")
        newDirectory["target_relative_path"] = "rules/core/new"
        newDirectory["after_entry"] = [
            "kind": "directory",
            "mode": 493,
            "relative_path": "rules/core/new",
        ]
        #expect(schemaAccepts(newDirectory, against: transitionSchema, root: schemaRoot))
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
            try CanonicalJSON.decode(CanonActivationReceipt.self, from: jsonData(receiptObject))
        }

        var exceptionObject = try jsonObject(validException())
        exceptionObject["expires_at"] = "2027-07-06T00:00:00.000+00:00"
        #expect(throws: ContractError.self) {
            try CanonicalJSON.decode(ExceptionRecord.self, from: jsonData(exceptionObject))
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
            try SourceSemanticBinding(sourceKind: "skill", sourceID: "skill-001", digest: digest("1"))
        }
        #expect(throws: ContractError.self) {
            try SourceSemanticBinding(sourceKind: "rule", sourceID: "unchecked", digest: digest("1"))
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
                    SourceSemanticBinding(sourceKind: "rule", sourceID: "TEST-CANON-001", digest: digest("2")),
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
                    SourceSemanticBinding(sourceKind: "adr", sourceID: "ADR-9999", digest: digest("2")),
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
        var payloadObject = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        payloadObject.removeValue(forKey: "delta_digest")
        let payloadData = try JSONSerialization.data(
            withJSONObject: payloadObject,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        #expect(CanonicalTreeDigest.sha256(payloadData) == delta.deltaDigest)

        var tampered = try jsonObject(delta)
        tampered["delta_digest"] = try digest("e").rawValue
        #expect(throws: ContractError.self) {
            try CanonicalJSON.decode(DerivedRegistrationDelta.self, from: jsonData(tampered))
        }
    }
}

private extension CanonActivationContractTests {
    func validReceipt(
        targetProductVersion: String = "1.0.0-rc.1",
        approvalOverlayID: String = "overlay-001",
        approvalDigestCharacter: Character = "5",
        publishedDigestCharacter: Character = "9",
        approvalTimestamp: Date = Date(timeIntervalSince1970: 1_783_315_200),
        transformDigest: HashDigest = CandidateOverlayTransformDescriptor.v1.digest
    ) throws -> CanonActivationReceipt {
        let reference = try approval(
            approvalID: "integration-approval",
            principalID: "principal-integration",
            actorID: "actor-integration",
            roleID: "Integration Reviewer",
            componentID: approvalOverlayID,
            componentDigest: digest(approvalDigestCharacter)
        )
        let path = "rules/core/test.rules.json"
        let transition = try ActivationDigestTransition(
            targetNamespace: .canon,
            targetRelativePath: path,
            affectedComponents: [
                ActivationAffectedComponentReference(componentKind: "standards-core", componentID: "component-core"),
            ],
            beforeEntry: treeEntry(path: path, digestCharacter: "3", mode: 420),
            afterEntry: treeEntry(path: path, digestCharacter: "4", mode: 420)
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
            activationTransformIdentity: CandidateOverlayTransformDescriptor.v1.identity,
            activationTransformDigest: transformDigest,
            resolvedActivationDigest: digest("a"),
            baseSnapshotContentDigest: digest("8"),
            basePluginInventoryDigest: digest("b"),
            resolvedPluginInventoryDigest: digest("c"),
            publishedSnapshotContentDigest: digest(publishedDigestCharacter),
            digestTransitions: [transition]
        )
    }

    func treeEntry(path: String, digestCharacter: Character, mode: UInt16) throws -> CanonicalTreeEntry {
        try CanonicalTreeEntry(
            relativePath: path,
            kind: .regularFile,
            contentSHA256: digest(digestCharacter),
            mode: mode
        )
    }

    func directoryEntry(path: String) throws -> CanonicalTreeEntry {
        try CanonicalTreeEntry(
            relativePath: path,
            kind: .directory,
            contentSHA256: nil,
            mode: 493
        )
    }

    func activationReceiptSchema() throws -> [String: Any] {
        let pluginRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = pluginRoot.appendingPathComponent(
            "standards/canon/schemas/v1/activation-receipt.schema.json"
        )
        return try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        )
    }

    func expectContractError(
        _ expected: ContractError,
        operation: () throws -> some Any
    ) throws {
        do {
            _ = try operation()
            Issue.record("expected \(expected)")
        } catch let error as ContractError {
            #expect(error == expected)
        } catch {
            Issue.record("expected ContractError, received \(error)")
        }
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

    func derivedEntry(targetPath: String, digestCharacter: Character) throws -> DerivedRegistrationEntry {
        try DerivedRegistrationEntry(
            indexKey: targetPath,
            targetPath: targetPath,
            artifactKind: "skill",
            fileDigest: digest(digestCharacter),
            citedRuleIDs: [RuleID(validating: "TEST-CANON-001")],
            citedADRIDs: [ADRIdentifier(validating: "ADR-9999")],
            sourceSemanticBindings: [
                SourceSemanticBinding(sourceKind: "adr", sourceID: "ADR-9999", digest: digest(digestCharacter)),
                SourceSemanticBinding(sourceKind: "rule", sourceID: "TEST-CANON-001", digest: digest(digestCharacter)),
            ]
        )
    }

    func digest(_ character: Character) throws -> HashDigest {
        try HashDigest(validating: String(repeating: character, count: 64))
    }

    func jsonObject(_ value: some Encodable) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: CanonicalJSON.encode(value)) as? [String: Any])
    }

    func jsonData(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
    }
}
