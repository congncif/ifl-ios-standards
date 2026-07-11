import Darwin
import Foundation
@testable import IFLCanon
import IFLContracts
import Testing

@Suite("CandidateOverlayValidatorTests", .serialized)
struct CandidateOverlayValidatorTests {
    @Test("exact immutable capture validates without changing the retained plugin")
    func exactCaptureValidatesWithoutWrites() throws {
        try CandidateOverlayFixture.withValidFixture { fixture in
            let before = try CanonicalTreeScanner().scan(
                root: fixture.pluginRoot,
                policy: CanonicalTreePolicy(excludedRoots: [])
            )
            let token = try fixture.validate()
            let after = try CanonicalTreeScanner().scan(
                root: fixture.pluginRoot,
                policy: CanonicalTreePolicy(excludedRoots: [])
            )

            #expect(before == after)
            #expect(token.overlayID == fixture.overlayID)
            #expect(token.manifest == fixture.manifest)
            #expect(token.componentBundles["core-authority-v1"] == fixture.bundle)
            #expect(
                try token.candidateTreeCapture.captureDigest
                    == (CanonicalTreeDigest.digest(token.candidateTreeCapture.inventory))
            )
            #expect(token.basePluginEvidence.inventory == before)
        }
    }

    @Test(
        "candidate physical closure rejects extra, omitted, and mode-drifted paths",
        arguments: ["extra", "omitted", "mode"]
    )
    func physicalClosureMatrix(_ mutation: String) throws {
        try CandidateOverlayFixture.withValidFixture { fixture in
            switch mutation {
            case "extra":
                try fixture.addExtraCandidateFile()
            case "omitted":
                try fixture.removeCandidateFile(
                    relativePath: "payloads/evidence/checks/CHK-CAN-001.json"
                )
            case "mode":
                try fixture.setCandidateMode(
                    0o600,
                    relativePath: "candidate-overlay.v1.json"
                )
            default:
                Issue.record("Unknown fixture mutation \(mutation)")
            }

            expectTypedValidationFailure {
                _ = try fixture.validate()
            }
        }
    }

    @Test("manifest and component bytes are canonical, digest-bound, and joined")
    func canonicalAndComponentJoinFailures() throws {
        try CandidateOverlayFixture.withValidFixture { fixture in
            try fixture.makeManifestNonCanonical()
            expectTypedValidationFailure {
                _ = try fixture.validate()
            }
        }

        try CandidateOverlayFixture.withValidFixture { fixture in
            try fixture.mutateBundleBytes()
            expectTypedValidationFailure {
                _ = try fixture.validate()
            }
        }
    }

    @Test("semantic prestates, authority roles, and existing-target preconditions fail closed")
    func semanticAuthorityAndBeforeEntryFailures() throws {
        var activeRule = CandidateOverlayFixture.Options()
        activeRule.ruleLifecycle = .active
        _ = try CandidateOverlayFixture.withValidFixture(options: activeRule) { fixture in
            expectTypedValidationFailure {
                _ = try fixture.validate()
            }
        }

        var wrongFamily = CandidateOverlayFixture.Options()
        wrongFamily.componentKind = "standards-core"
        _ = try CandidateOverlayFixture.withValidFixture(options: wrongFamily) { fixture in
            expectTypedValidationFailure {
                _ = try fixture.validate()
            }
        }

        var missingBefore = CandidateOverlayFixture.Options()
        missingBefore.omitPluginTargetBeforeEntry = true
        _ = try CandidateOverlayFixture.withValidFixture(options: missingBefore) { fixture in
            expectTypedValidationFailure {
                _ = try fixture.validate()
            }
        }

        var draftADR = CandidateOverlayFixture.Options()
        draftADR.adrStatus = .draft
        _ = try CandidateOverlayFixture.withValidFixture(options: draftADR) { fixture in
            expectTypedValidationFailure {
                _ = try fixture.validate()
            }
        }
    }

    @Test("schema rebinding, reviewer separation, and transform closure fail closed")
    func schemaApprovalAndTransformFailures() throws {
        try CandidateOverlayFixture.withValidFixture { fixture in
            try fixture.makeBundleClaimConfusionWithRecomputedReviewDigest()
            expectTypedValidationFailure {
                _ = try fixture.validate()
            }
        }

        try CandidateOverlayFixture.withValidFixture { fixture in
            try fixture.makeApprovalActorsOverlap()
            expectTypedValidationFailure {
                _ = try fixture.validate()
            }
        }

        try CandidateOverlayFixture.withValidFixture { fixture in
            try fixture.removeRuleTransform()
            expectTypedValidationFailure {
                _ = try fixture.validate()
            }
        }
    }

    @Test("caller-supplied typed Canon state cannot reattach retained evidence")
    func forgedTypedSnapshotCannotBorrowEvidence() throws {
        try CandidateOverlayFixture.withValidFixture { fixture in
            let base = fixture.baseSnapshot
            let forged = CanonSnapshot(
                canonVersion: base.canonVersion,
                rules: [],
                profiles: base.profiles,
                selectedProfileIDs: base.selectedProfileIDs,
                adrs: base.adrs,
                adrMarkdownByID: base.adrMarkdownByID,
                chapters: base.chapters,
                requirementRegistry: base.requirementRegistry,
                derivedArtifacts: base.derivedArtifacts,
                snapshotContentDigest: base.snapshotContentDigest
            )

            expectContractFailure(
                "candidate validation requires Canon evidence from the same retained plugin authority"
            ) {
                _ = try CandidateOverlayValidator(anchor: fixture.anchor).validate(
                    overlayID: fixture.overlayID,
                    base: forged
                )
            }
        }
    }

    @Test("missing candidate inputs preserve pre- and post-manifest failure categories")
    func phaseSpecificMissingInputs() throws {
        try CandidateOverlayFixture.withValidFixture { fixture in
            try fixture.removeCandidateFile(relativePath: "candidate-overlay.v1.json")
            do {
                _ = try fixture.validate()
                Issue.record("Expected fixed manifest to be missing")
            } catch let error as ContractError {
                #expect(error == .unresolvedReference(
                    kind: "canon file",
                    id: "candidate-overlay.v1.json"
                ))
            } catch {
                Issue.record("Unexpected missing-manifest error: \(error)")
            }
        }

        for relativePath in [
            "components/core-authority-v1.bundle.json",
            "payloads/evidence/checks/CHK-CAN-001.json",
        ] {
            try CandidateOverlayFixture.withValidFixture { fixture in
                try fixture.removeCandidateFile(relativePath: relativePath)
                expectDescriptorFailure(
                    "accepted candidate source is missing: \(relativePath)"
                ) {
                    _ = try fixture.validate()
                }
            }
        }
    }

    @Test("same-byte plugin replacement is metadata integrity drift")
    func validatorMetadataDriftIsNotEqualDigestMismatch() throws {
        try CandidateOverlayFixture.withValidFixture { fixture in
            let mutation = CandidateOverlayMutation {
                try fixture.replacePluginFilePreservingBytes(
                    relativePath: "skills/brain-execute/SKILL.md"
                )
            }
            let validator = CandidateOverlayValidator(
                anchor: fixture.anchor,
                eventHandler: { event in
                    if event == .willRescanPlugin {
                        try mutation.runOnce()
                    }
                }
            )

            expectDescriptorFailure(
                "retained plugin object metadata changed at skills/brain-execute/SKILL.md"
            ) {
                _ = try validator.validate(
                    overlayID: fixture.overlayID,
                    base: fixture.baseSnapshot
                )
            }
        }
    }

    @Test(
        "two-component source and namespace closure is exact and component-local",
        arguments: TwoComponentFixtureMutation.allCases
    )
    func twoComponentClosure(_ mutation: TwoComponentFixtureMutation) throws {
        try CandidateOverlayFixture.withValidFixture { fixture in
            try fixture.installTwoComponentMutation(mutation)
            let reason = switch mutation {
            case .duplicateCandidateSource:
                "candidate source path is claimed by multiple components: payloads/evidence/fixtures/FIX-CAN-001.json"
            case .fileDirectoryConflict:
                "publication namespace has a file/directory conflict at plugin_derived:standards/specs/EXAMPLES.md"
            case .missingComponentLocalParent:
                "component secondary-authority-v1 lacks a local directory claim for plugin_derived:standards/specs"
            }
            expectContractFailure(reason) {
                _ = try fixture.validate()
            }
        }
    }

    @Test(
        "optional publication families require the authority row's exact artifact kind",
        arguments: OptionalAuthorityMismatch.allCases
    )
    func optionalPublicationAuthorityKind(_ mismatch: OptionalAuthorityMismatch) throws {
        try CandidateOverlayFixture.withValidFixture { fixture in
            try fixture.publishOptionalAuthorityMismatch(mismatch)
            expectContractFailure("optional plugin publication lacks one exact authority row") {
                _ = try fixture.validate()
            }
        }
    }

    @Test("derived authority lookup cannot borrow a cross-component artifact ID")
    func derivedAuthorityUsesCompositeIdentity() throws {
        try CandidateOverlayFixture.withValidFixture { fixture in
            try fixture.installCrossComponentDerivedArtifactReuse()
            expectContractFailure("plugin-derived publication lacks one exact authority row") {
                _ = try fixture.validate()
            }
        }
    }

    @Test("regular index entries join their governed transform source")
    func regularIndexJoinsTransformSource() throws {
        try CandidateOverlayFixture.withValidFixture { fixture in
            try fixture.substituteProfileSourceIntoRulesIndex()
            expectContractFailure(
                "candidate regular index entry does not join its activation source"
            ) {
                _ = try fixture.validate()
            }
        }
    }

    @Test("derived index entries equal their decoded delta and transform")
    func derivedIndexJoinsDeltaAndTransform() throws {
        try CandidateOverlayFixture.withValidFixture { fixture in
            try fixture.driftDerivedIndexFromDelta()
            expectContractFailure(
                "candidate derived index entry differs from decoded delta or transform"
            ) {
                _ = try fixture.validate()
            }
        }
    }

    @Test("candidate indexes preserve undeclared top-level fields")
    func indexTopLevelFieldsRemainBaseEqual() throws {
        try CandidateOverlayFixture.withValidFixture { fixture in
            try fixture.mutateRulesIndexTopLevelID()
            expectContractFailure("candidate index top-level fields differ from base") {
                _ = try fixture.validate()
            }
        }
    }

    @Test("unanchored and independently anchored Canon snapshots cannot mint a token")
    func crossAnchorAndUnanchoredSnapshotsFail() throws {
        try CandidateOverlayFixture.withValidFixture { fixture in
            let ordinary = try FileCanonRepository(root: fixture.canonRoot).snapshot(profiles: [])
            expectTypedValidationFailure {
                _ = try CandidateOverlayValidator(anchor: fixture.anchor).validate(
                    overlayID: fixture.overlayID,
                    base: ordinary
                )
            }

            let second = try CandidateOverlayFixture.retainedAnchor(at: fixture.pluginRoot)
            let crossAnchored = try FileCanonRepository(
                anchor: second.canonRootAnchor()
            ).snapshot(profiles: [])
            expectTypedValidationFailure {
                _ = try CandidateOverlayValidator(anchor: fixture.anchor).validate(
                    overlayID: fixture.overlayID,
                    base: crossAnchored
                )
            }
        }
    }

    @Test("full-plugin mutation after initial evidence is rejected before token creation")
    func fullPluginMutationIsRejected() throws {
        try CandidateOverlayFixture.withValidFixture { fixture in
            let mutation = CandidateOverlayMutation {
                let file = fixture.pluginRoot.appendingPathComponent("unrelated.txt")
                try Data("late mutation\n".utf8).write(to: file)
                try CandidateOverlayFixture.setMode(0o644, at: file)
            }
            let validator = CandidateOverlayValidator(
                anchor: fixture.anchor,
                eventHandler: { event in
                    if event == .didCaptureCandidateFile("candidate-overlay.v1.json") {
                        try mutation.runOnce()
                    }
                }
            )

            expectTypedValidationFailure {
                _ = try validator.validate(
                    overlayID: fixture.overlayID,
                    base: fixture.baseSnapshot
                )
            }
        }
    }

    @Test("every candidate file is captured exactly once")
    func everyCandidateFileIsCapturedOnce() throws {
        try CandidateOverlayFixture.withValidFixture { fixture in
            let events = CandidateOverlayEventStore()
            let token = try fixture.validate(eventHandler: events.record)
            let capturedPaths = events.events.compactMap { event -> String? in
                guard case let .didCaptureCandidateFile(path) = event else { return nil }
                return path
            }
            let counts = Dictionary(grouping: capturedPaths, by: { $0 }).mapValues(\.count)

            #expect(counts.count == token.candidateTreeCapture.filesByRelativePath.count)
            #expect(counts.values.allSatisfy { $0 == 1 })
            #expect(Set(counts.keys) == Set(token.candidateTreeCapture.filesByRelativePath.keys))
        }
    }

    @Test("all 142 compiled plugin-derived authority rows pass the real validator join")
    func exhaustiveAuthorityRows() throws {
        let rows = CandidatePublicationAuthorityMap.v1.rows
        #expect(rows.count == 142)
        for row in rows {
            var options = CandidateOverlayFixture.Options()
            options.componentKind = row.componentFamily.rawValue
            options.pluginTargetPath = row.targetPath.rawValue
            options.derivedArtifactKind = row.artifactKind
            options.pluginTargetMode = row.targetMode
            try CandidateOverlayFixture.withValidFixture(options: options) { fixture in
                let token = try fixture.validate()
                #expect(token.manifest.reviewedComponents.first?.componentKind
                    == row.componentFamily.rawValue)
            }
        }
    }
}

private func expectContractFailure(
    _ reason: String,
    operation: () throws -> Void
) {
    do {
        try operation()
        Issue.record("Expected candidate contract failure: \(reason)")
    } catch let error as ContractError {
        #expect(error == .invalidContract(
            kind: "candidate_overlay_validation",
            reason: reason
        ))
    } catch {
        Issue.record("Unexpected candidate contract error: \(error)")
    }
}

private func expectDescriptorFailure(
    _ reason: String,
    operation: () throws -> Void
) {
    do {
        try operation()
        Issue.record("Expected descriptor failure: \(reason)")
    } catch let error as CanonDescriptorFailure {
        #expect(error == .integrityViolation(reason))
    } catch {
        Issue.record("Unexpected descriptor error: \(error)")
    }
}

private func expectTypedValidationFailure(operation: () throws -> Void) {
    do {
        try operation()
        Issue.record("Expected typed candidate validation failure")
    } catch is ContractError {
        return
    } catch is CanonDescriptorFailure {
        return
    } catch {
        Issue.record("Unexpected untyped candidate validation error: \(error)")
    }
}
