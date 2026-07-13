import Foundation
@testable import IFLCanon
import IFLContracts
import Testing

@Suite("CandidateOverlayResolverTests", .serialized)
struct CandidateOverlayResolverTests {
    @Test("closed transforms produce exact sorted files, directories, and path transitions")
    func completeTransformAndOutputClosure() throws {
        try ResolverCandidateFixture.withResolvableFixture { fixture in
            let candidate = try fixture.validate()
            let approval = try ResolverCandidateFixture.approval(
                for: candidate,
                timestamp: ResolverCandidateFixture.approvalTimestamp
            )
            let resolved = try CandidateOverlayResolver().resolve(
                candidate,
                approval: approval
            )

            let expectedFiles = try ResolverCandidateFixture.expectedFiles(
                fixture: fixture,
                approvalTimestamp: approval.approvalTimestamp
            )
            let expectedDirectories = try ResolverCandidateFixture.expectedDirectories()
            #expect(resolved.outputFiles.map(\.targetKey) == expectedFiles.map(\.targetKey))
            #expect(resolved.outputFiles.map(\.bytes) == expectedFiles.map(\.bytes))
            #expect(resolved.outputFiles.map(\.contentDigest) == expectedFiles.map(\.contentDigest))
            #expect(resolved.outputFiles.map(\.mode) == expectedFiles.map(\.mode))
            #expect(
                resolved.outputFiles.map(\.affectedComponents)
                    == expectedFiles.map(\.affectedComponents)
            )
            #expect(resolved.outputDirectories == expectedDirectories)

            let expectedTransitions = try ResolverCandidateFixture.expectedTransitions(
                candidate: candidate,
                files: expectedFiles,
                directories: expectedDirectories
            )
            #expect(resolved.digestTransitions == expectedTransitions)
            #expect(Set(resolved.digestTransitions.map(\.normalizedPluginKey)).count == expectedTransitions.count)
        }
    }

    @Test("approval overlay ID and digest are independently bound before output")
    func mismatchedApprovalIsRejectedByExactCause() throws {
        try ResolverCandidateFixture.withResolvableFixture { fixture in
            let candidate = try fixture.validate()
            let wrongIDApproval = try ResolverCandidateFixture.approval(
                overlayID: "wrong-overlay",
                overlayDigest: candidate.overlayDigest,
                timestamp: ResolverCandidateFixture.approvalTimestamp
            )
            expectResolverFailure(
                .unresolvedReference(
                    kind: "integration_approval_overlay",
                    id: candidate.overlayID.rawValue
                )
            ) {
                _ = try CandidateOverlayResolver().resolve(
                    candidate,
                    approval: wrongIDApproval
                )
            }

            let wrongDigest = CanonicalTreeDigest.sha256(Data("wrong overlay".utf8))
            let wrongDigestApproval = try ResolverCandidateFixture.approval(
                overlayID: candidate.overlayID.rawValue,
                overlayDigest: wrongDigest,
                timestamp: ResolverCandidateFixture.approvalTimestamp
            )
            expectResolverFailure(
                .digestMismatch(
                    kind: "integration_approval_overlay",
                    expected: candidate.overlayDigest.rawValue,
                    actual: wrongDigest.rawValue
                )
            ) {
                _ = try CandidateOverlayResolver().resolve(
                    candidate,
                    approval: wrongDigestApproval
                )
            }
        }
    }

    @Test("resolution is whole-Canon even from a subset-loaded base and rejects absent inheritance")
    func wholeCanonProfileInheritanceClosure() throws {
        try ResolverCandidateFixture.withResolvableFixture { fixture in
            let core = try ProfileID(validating: "core")
            let subsetBase = try ResolverCandidateFixture
                .installSecondBaseProfileAndRebind(fixture, selectedProfile: core)
            #expect(subsetBase.selectedProfileIDs.count < subsetBase.profiles.count)
            let candidate = try CandidateOverlayValidator(anchor: fixture.anchor)
                .validate(overlayID: fixture.overlayID, base: subsetBase)
            let resolved = try CandidateOverlayResolver().resolve(
                candidate,
                approval: ResolverCandidateFixture.approval(
                    for: candidate,
                    timestamp: ResolverCandidateFixture.approvalTimestamp
                )
            )
            #expect(
                resolved.resolvedCanonSnapshot.selectedProfileIDs
                    == resolved.resolvedCanonSnapshot.profiles.map(\.id)
            )
            #expect(
                Set(resolved.resolvedCanonSnapshot.selectedProfileIDs)
                    == Set(subsetBase.profiles.map(\.id))
            )
        }

        try ResolverCandidateFixture.withResolvableFixture { fixture in
            try ResolverCandidateFixture.installAbsentProfileInheritance(in: fixture)
            let candidate = try fixture.validate()
            let approval = try ResolverCandidateFixture.approval(
                for: candidate,
                timestamp: ResolverCandidateFixture.approvalTimestamp
            )
            expectResolverFailure(
                .unresolvedReference(kind: "inherited profile", id: "absent-profile")
            ) {
                _ = try CandidateOverlayResolver().resolve(candidate, approval: approval)
            }
        }
    }

    @Test("normalized transition keys and complete inventory entries are unique and exact")
    func transitionEntryClosureIsUniqueAndExact() throws {
        try ResolverCandidateFixture.withResolvableFixture { fixture in
            let candidate = try fixture.validate()
            let approval = try ResolverCandidateFixture.approval(
                for: candidate,
                timestamp: ResolverCandidateFixture.approvalTimestamp
            )
            let resolved = try CandidateOverlayResolver().resolve(
                candidate,
                approval: approval
            )
            let files = try ResolverCandidateFixture.expectedFiles(
                fixture: fixture,
                approvalTimestamp: approval.approvalTimestamp
            )
            let directories = try ResolverCandidateFixture.expectedDirectories()
            let expected = try ResolverCandidateFixture.expectedTransitions(
                candidate: candidate,
                files: files,
                directories: directories
            )
            #expect(resolved.digestTransitions == expected)
            #expect(
                Set(resolved.digestTransitions.map(\.normalizedPluginKey)).count
                    == resolved.digestTransitions.count
            )
        }
    }

    @Test("split source/index ownership and a co-owned directory retain every component")
    func multiComponentAffectedOwnershipClosure() throws {
        try ResolverCandidateFixture.withResolvableFixture { fixture in
            try ResolverCandidateFixture.installResolvableSecondComponent(in: fixture)
            let candidate = try fixture.validate()
            let resolved = try CandidateOverlayResolver().resolve(
                candidate,
                approval: ResolverCandidateFixture.approval(
                    for: candidate,
                    timestamp: ResolverCandidateFixture.approvalTimestamp
                )
            )
            let primary = try ActivationAffectedComponentReference(
                componentKind: "enterprise-routing",
                componentID: "core-authority-v1"
            )
            let secondary = try ActivationAffectedComponentReference(
                componentKind: "enterprise-routing",
                componentID: "secondary-authority-v1"
            )
            let shared = [primary, secondary]
            let profileIndex = try #require(resolved.outputFiles.first {
                $0.targetRelativePath == ResolverCandidateFixture.profilesIndexTarget
            })
            #expect(profileIndex.affectedComponents == shared)
            let sharedDirectory = try #require(resolved.outputDirectories.first {
                $0.targetRelativePath == "standards/specs"
            })
            #expect(sharedDirectory.affectedComponents == shared)
            #expect(
                resolved.digestTransitions.first {
                    $0.targetNamespace == .canon
                        && $0.targetRelativePath == ResolverCandidateFixture.profilesIndexTarget
                }?.affectedComponents == shared
            )
            #expect(
                resolved.digestTransitions.first {
                    $0.targetNamespace == .pluginDerived
                        && $0.targetRelativePath == "standards/specs"
                }?.affectedComponents == shared
            )
            let migration = try #require(resolved.outputFiles.first {
                $0.targetRelativePath == ResolverCandidateFixture.secondaryOptionalTarget
            })
            #expect(migration.affectedComponents == [secondary])
            for output in resolved.outputFiles {
                let expectedOwners = switch output.targetRelativePath {
                case ResolverCandidateFixture.profilesIndexTarget:
                    shared
                case ResolverCandidateFixture.secondaryOptionalTarget:
                    [secondary]
                default:
                    [primary]
                }
                #expect(output.affectedComponents == expectedOwners)
            }
            #expect(resolved.outputDirectories.count == 1)
            #expect(resolved.outputDirectories.allSatisfy {
                $0.affectedComponents == shared
            })
            let ownersByTarget = Dictionary(uniqueKeysWithValues:
                resolved.outputFiles.map { ($0.targetKey, $0.affectedComponents) }
                    + resolved.outputDirectories.map {
                        ($0.targetKey, $0.affectedComponents)
                    })
            #expect(resolved.digestTransitions.allSatisfy {
                ownersByTarget[$0.targetKey] == $0.affectedComponents
            })
        }

        try ResolverCandidateFixture.withResolvableFixture { fixture in
            try ResolverCandidateFixture.installResolvableSecondComponent(in: fixture)
            try ResolverCandidateFixture.removeSecondaryDirectoryOwner(from: fixture)
            expectTypedResolverFailure { _ = try fixture.validate() }
        }
    }

    @Test("declared index transforms preserve every unrelated sentinel in canonical order")
    func indexSentinelPreservation() throws {
        try ResolverCandidateFixture.withResolvableFixture { fixture in
            let core = try ProfileID(validating: "core")
            let subsetBase = try ResolverCandidateFixture
                .installSecondBaseProfileAndRebind(fixture, selectedProfile: core)
            let candidate = try CandidateOverlayValidator(anchor: fixture.anchor)
                .validate(overlayID: fixture.overlayID, base: subsetBase)
            let resolved = try CandidateOverlayResolver().resolve(
                candidate,
                approval: ResolverCandidateFixture.approval(
                    for: candidate,
                    timestamp: ResolverCandidateFixture.approvalTimestamp
                )
            )
            try ResolverCandidateFixture.assertIndexSentinelsPreserved(
                fixture: fixture,
                candidate: candidate,
                resolved: resolved
            )
        }
    }

    @Test("missing, extra, duplicate, and cross-family transform claims fail closed")
    func invalidTransformClosureIsRejected() throws {
        try CandidateOverlayFixture.withValidFixture { fixture in
            try fixture.removeRuleTransform()
            expectTypedResolverFailure { _ = try fixture.validate() }
        }

        try CandidateOverlayFixture.withValidFixture { fixture in
            try ResolverCandidateFixture.appendExtraRuleTransform(to: fixture)
            expectTypedResolverFailure { _ = try fixture.validate() }
        }

        try CandidateOverlayFixture.withValidFixture { fixture in
            try ResolverCandidateFixture.duplicateRuleTransform(in: fixture)
            expectTypedResolverFailure { _ = try fixture.validate() }
        }

        try CandidateOverlayFixture.withValidFixture { fixture in
            try fixture.substituteProfileSourceIntoRulesIndex()
            expectTypedResolverFailure { _ = try fixture.validate() }
        }

        try CandidateOverlayFixture.withValidFixture { fixture in
            try fixture.driftDerivedIndexFromDelta()
            expectTypedResolverFailure { _ = try fixture.validate() }
        }
    }

    @Test("no-op outputs, undeclared publications, existing chmod, and missing parents fail closed")
    func invalidOutputClosureIsRejected() throws {
        try CandidateOverlayFixture.withValidFixture { fixture in
            let candidate = try fixture.validate()
            let approval = try ResolverCandidateFixture.approval(
                for: candidate,
                timestamp: ResolverCandidateFixture.approvalTimestamp
            )
            expectTypedResolverFailure {
                _ = try CandidateOverlayResolver().resolve(candidate, approval: approval)
            }
        }

        try CandidateOverlayFixture.withValidFixture { fixture in
            try ResolverCandidateFixture.addUndeclaredPublication(to: fixture)
            expectTypedResolverFailure { _ = try fixture.validate() }
        }

        try CandidateOverlayFixture.withValidFixture { fixture in
            try ResolverCandidateFixture.changeExistingTargetMode(in: fixture)
            expectTypedResolverFailure { _ = try fixture.validate() }
        }

        try ResolverCandidateFixture.withResolvableFixture { fixture in
            try ResolverCandidateFixture.removeRequiredDirectory(from: fixture)
            expectTypedResolverFailure { _ = try fixture.validate() }
        }
    }

    @Test("projected Canon and resolved plugin inventories close the exact transition delta")
    func completeInventoryAndIdentityClosure() throws {
        try ResolverCandidateFixture.withResolvableFixture { fixture in
            let candidate = try fixture.validate()
            let approval = try ResolverCandidateFixture.approval(
                for: candidate,
                timestamp: ResolverCandidateFixture.approvalTimestamp
            )
            let resolved = try CandidateOverlayResolver().resolve(
                candidate,
                approval: approval
            )
            let expected = try ResolverCandidateFixture.expectedInventories(
                candidate: candidate,
                files: resolved.outputFiles,
                directories: resolved.outputDirectories
            )
            let expectedPublishedDigest = try CanonicalTreeDigest.digest(
                expected.projectedCanon
            )
            let expectedResolvedPluginDigest = try CanonicalTreeDigest.digest(
                expected.resolvedPlugin
            )
            let expectedActivationDigest = try ResolverCandidateFixture
                .expectedResolvedActivationDigest(
                    candidate: candidate,
                    approval: approval,
                    resolved: resolved
                )

            #expect(resolved.baseCanonInventory == candidate.canonEvidence.fullInventory)
            #expect(
                resolved.baseCanonInventoryDigest
                    == candidate.canonEvidence.fullInventoryDigest
            )
            #expect(resolved.basePluginInventory == candidate.basePluginEvidence.inventory)
            #expect(
                resolved.basePluginInventoryDigest
                    == candidate.basePluginEvidence.inventoryDigest
            )
            #expect(
                resolved.candidateTreeCapture.inventory
                    == candidate.candidateTreeCapture.inventory
            )
            #expect(
                resolved.candidateTreeCapture.captureDigest
                    == candidate.candidateTreeCapture.captureDigest
            )
            #expect(resolved.projectedPublishedCanonInventory == expected.projectedCanon)
            #expect(
                resolved.publishedSnapshotContentDigest
                    == expectedPublishedDigest
            )
            #expect(resolved.resolvedPluginInventory == expected.resolvedPlugin)
            #expect(
                resolved.resolvedPluginInventoryDigest
                    == expectedResolvedPluginDigest
            )
            #expect(
                resolved.projectedPublishedCanonInventory.rootMode
                    == candidate.canonEvidence.projectedInventory.rootMode
            )
            #expect(
                resolved.resolvedPluginInventory.rootMode
                    == candidate.basePluginEvidence.inventory.rootMode
            )

            let actualDelta = ResolverCandidateFixture.inventoryDelta(
                before: candidate.basePluginEvidence.inventory,
                after: resolved.resolvedPluginInventory
            )
            let transitionDelta = Set(resolved.digestTransitions.map {
                $0.targetNamespace == .canon
                    ? "standards/canon/" + $0.targetRelativePath
                    : $0.targetRelativePath
            })
            #expect(actualDelta.changedOrAdded == transitionDelta)
            #expect(actualDelta.deleted.isEmpty)
            #expect(CanonValidator().validate(resolved.resolvedCanonSnapshot).isEmpty)
            #expect(resolved.resolvedActivationDigest == expectedActivationDigest)
            #expect(
                try ResolutionFingerprint(resolved)
                    == ResolverCandidateFixture.expectedFingerprint(
                        fixture: fixture,
                        candidate: candidate,
                        approval: approval
                    )
            )
        }
    }

    @Test("production semantic findings prevent a resolved token")
    func resolvedSemanticInvalidityIsRejected() throws {
        try ResolverCandidateFixture.withResolvableFixture { fixture in
            try ResolverCandidateFixture.removeActiveRuleOwnerBinding(from: fixture)
            let candidate = try fixture.validate()
            let approval = try ResolverCandidateFixture.approval(
                for: candidate,
                timestamp: ResolverCandidateFixture.approvalTimestamp
            )
            expectTypedResolverFailure {
                _ = try CandidateOverlayResolver().resolve(candidate, approval: approval)
            }
        }
    }

    @Test("approval timestamp changes only the ADR and ADR-index transitive closure")
    func approvalTimestampCausality() throws {
        try ResolverCandidateFixture.withResolvableFixture { fixture in
            let candidate = try fixture.validate()
            let firstApproval = try ResolverCandidateFixture.approval(
                for: candidate,
                timestamp: ResolverCandidateFixture.approvalTimestamp
            )
            let secondApproval = try ResolverCandidateFixture.approval(
                for: candidate,
                timestamp: ResolverCandidateFixture.date(
                    "2026-07-10T12:34:57.789Z"
                )
            )
            let resolver = CandidateOverlayResolver()
            let first = try resolver.resolve(candidate, approval: firstApproval)
            let second = try resolver.resolve(candidate, approval: secondApproval)

            let expectedOutputKeys = Set([
                "canon\0" + ResolverCandidateFixture.adrMetadataTarget,
                "canon\0" + ResolverCandidateFixture.adrsIndexTarget,
            ])
            #expect(
                ResolverCandidateFixture.changedOutputKeys(first, second)
                    == expectedOutputKeys
            )
            #expect(
                ResolverCandidateFixture.changedTransitionKeys(first, second)
                    == expectedOutputKeys
            )
            #expect(
                ResolverCandidateFixture.changedInventoryPaths(
                    first.projectedPublishedCanonInventory,
                    second.projectedPublishedCanonInventory
                ) == Set([
                    ResolverCandidateFixture.adrMetadataTarget,
                    ResolverCandidateFixture.adrsIndexTarget,
                ])
            )
            #expect(
                ResolverCandidateFixture.changedInventoryPaths(
                    first.resolvedPluginInventory,
                    second.resolvedPluginInventory
                ) == Set([
                    "standards/canon/" + ResolverCandidateFixture.adrMetadataTarget,
                    "standards/canon/" + ResolverCandidateFixture.adrsIndexTarget,
                ])
            )
            #expect(first.outputDirectories == second.outputDirectories)
            #expect(
                ResolverCandidateFixture.unchangedOutputs(
                    first,
                    second,
                    excluding: expectedOutputKeys
                )
            )
            #expect(
                ResolverCandidateFixture.unchangedTransitions(
                    first,
                    second,
                    excluding: expectedOutputKeys
                )
            )
            #expect(first.overlayID == second.overlayID)
            #expect(first.overlayDigest == second.overlayDigest)
            #expect(first.targetCanonVersion == second.targetCanonVersion)
            #expect(first.targetProductVersion == second.targetProductVersion)
            #expect(first.baseSnapshotContentDigest == second.baseSnapshotContentDigest)
            #expect(first.activationTransformIdentity == second.activationTransformIdentity)
            #expect(first.activationTransformDigest == second.activationTransformDigest)
            #expect(first.baseCanonInventory == second.baseCanonInventory)
            #expect(first.baseCanonInventoryDigest == second.baseCanonInventoryDigest)
            #expect(first.basePluginInventory == second.basePluginInventory)
            #expect(first.basePluginInventoryDigest == second.basePluginInventoryDigest)
            #expect(
                ResolverCandidateFixture.candidateCaptureFingerprint(first)
                    == ResolverCandidateFixture.candidateCaptureFingerprint(second)
            )
            #expect(
                ResolverCandidateFixture.approvalFingerprint(firstApproval, includeTimestamp: false)
                    == ResolverCandidateFixture.approvalFingerprint(
                        secondApproval,
                        includeTimestamp: false
                    )
            )
            #expect(firstApproval.approvalTimestamp != secondApproval.approvalTimestamp)
            #expect(
                try ResolverCandidateFixture.snapshotSemanticFingerprint(
                    first.resolvedCanonSnapshot,
                    excludingADRs: true
                )
                    == ResolverCandidateFixture.snapshotSemanticFingerprint(
                        second.resolvedCanonSnapshot,
                        excludingADRs: true
                    )
            )
            #expect(
                first.resolvedCanonSnapshot.adrMarkdownByID
                    == second.resolvedCanonSnapshot.adrMarkdownByID
            )
            #expect(
                first.publishedSnapshotContentDigest
                    != second.publishedSnapshotContentDigest
            )
            #expect(first.resolvedPluginInventoryDigest != second.resolvedPluginInventoryDigest)
            #expect(first.resolvedActivationDigest != second.resolvedActivationDigest)
        }
    }

    @Test("approved new-file mode changes only that output and its identity closure")
    func newFileModeCausality() throws {
        let ordinary = try ResolverCandidateFixture.withResolvableFixture(
            chapterMode: .file
        ) { fixture in
            let candidate = try fixture.validate()
            return try CandidateOverlayResolver().resolve(
                candidate,
                approval: ResolverCandidateFixture.approval(
                    for: candidate,
                    timestamp: ResolverCandidateFixture.approvalTimestamp
                )
            )
        }
        let executable = try ResolverCandidateFixture.withResolvableFixture(
            chapterMode: .executable
        ) { fixture in
            let candidate = try fixture.validate()
            return try CandidateOverlayResolver().resolve(
                candidate,
                approval: ResolverCandidateFixture.approval(
                    for: candidate,
                    timestamp: ResolverCandidateFixture.approvalTimestamp
                )
            )
        }
        let ordinaryChapter = try #require(
            ordinary.outputFiles.first {
                $0.targetRelativePath == ResolverCandidateFixture.chapterTarget
            }
        )
        let executableChapter = try #require(
            executable.outputFiles.first {
                $0.targetRelativePath == ResolverCandidateFixture.chapterTarget
            }
        )
        #expect(ordinaryChapter.bytes == executableChapter.bytes)
        #expect(ordinaryChapter.mode == CandidatePortableMode.file.rawValue)
        #expect(executableChapter.mode == CandidatePortableMode.executable.rawValue)
        let changedOutputKey = "canon\0" + ResolverCandidateFixture.chapterTarget
        #expect(
            ResolverCandidateFixture.changedOutputKeys(ordinary, executable)
                == [changedOutputKey]
        )
        #expect(
            ResolverCandidateFixture.changedTransitionKeys(ordinary, executable)
                == [changedOutputKey]
        )
        #expect(ordinary.outputDirectories == executable.outputDirectories)
        #expect(
            ResolverCandidateFixture.unchangedOutputs(
                ordinary,
                executable,
                excluding: [changedOutputKey]
            )
        )
        #expect(
            ResolverCandidateFixture.changedInventoryPaths(
                ordinary.projectedPublishedCanonInventory,
                executable.projectedPublishedCanonInventory
            ) == [ResolverCandidateFixture.chapterTarget]
        )
        #expect(
            ResolverCandidateFixture.changedInventoryPaths(
                ordinary.resolvedPluginInventory,
                executable.resolvedPluginInventory
            ) == [
                "standards/canon/" + ResolverCandidateFixture.chapterTarget,
                ResolverCandidateFixture.capturedBundlePluginPath,
                ResolverCandidateFixture.capturedManifestPluginPath,
            ]
        )
        let ordinaryTransition = try #require(ordinary.digestTransitions.first {
            $0.targetKey == changedOutputKey
        })
        let executableTransition = try #require(executable.digestTransitions.first {
            $0.targetKey == changedOutputKey
        })
        #expect(ordinaryTransition.beforeEntry == executableTransition.beforeEntry)
        #expect(ordinaryTransition.afterEntry.contentSHA256 == executableTransition.afterEntry.contentSHA256)
        #expect(ordinaryTransition.afterEntry.mode == CandidatePortableMode.file.rawValue)
        #expect(executableTransition.afterEntry.mode == CandidatePortableMode.executable.rawValue)
        #expect(
            try ResolverCandidateFixture.snapshotSemanticFingerprint(
                ordinary.resolvedCanonSnapshot,
                excludingADRs: false
            )
                == ResolverCandidateFixture.snapshotSemanticFingerprint(
                    executable.resolvedCanonSnapshot,
                    excludingADRs: false
                )
        )
        #expect(
            ordinary.publishedSnapshotContentDigest
                != executable.publishedSnapshotContentDigest
        )
        #expect(ordinary.resolvedPluginInventoryDigest != executable.resolvedPluginInventoryDigest)
        #expect(ordinary.resolvedActivationDigest != executable.resolvedActivationDigest)
    }

    @Test("a valid new-directory variation changes only its file and inventory closure")
    func newDirectoryCausality() throws {
        let first = try ResolverCandidateFixture.withResolvableFixture(
            includeOptionalPublication: false
        ) { fixture in
            let candidate = try fixture.validate()
            return try CandidateOverlayResolver().resolve(
                candidate,
                approval: ResolverCandidateFixture.approval(
                    for: candidate,
                    timestamp: ResolverCandidateFixture.approvalTimestamp
                )
            )
        }
        let second = try ResolverCandidateFixture.withResolvableFixture(
            includeOptionalPublication: true
        ) { fixture in
            let candidate = try fixture.validate()
            return try CandidateOverlayResolver().resolve(
                candidate,
                approval: ResolverCandidateFixture.approval(
                    for: candidate,
                    timestamp: ResolverCandidateFixture.approvalTimestamp
                )
            )
        }
        let directoryKey = "plugin_derived\0standards/specs"
        let fileKey = directoryKey + "/EXAMPLES.md"
        #expect(
            ResolverCandidateFixture.changedOutputKeys(first, second)
                == [fileKey]
        )
        #expect(
            ResolverCandidateFixture.changedDirectoryKeys(first, second)
                == [directoryKey]
        )
        #expect(
            ResolverCandidateFixture.changedTransitionKeys(first, second)
                == [directoryKey, fileKey]
        )
        #expect(
            ResolverCandidateFixture.unchangedOutputs(
                first,
                second,
                excluding: [fileKey]
            )
        )
        #expect(
            first.projectedPublishedCanonInventory
                == second.projectedPublishedCanonInventory
        )
        #expect(
            first.publishedSnapshotContentDigest
                == second.publishedSnapshotContentDigest
        )
        #expect(
            ResolverCandidateFixture.changedInventoryPaths(
                first.resolvedPluginInventory,
                second.resolvedPluginInventory
            ) == [
                ResolverCandidateFixture.capturedBundlePluginPath,
                ResolverCandidateFixture.capturedManifestPluginPath,
                "standards/specs",
                "standards/specs/EXAMPLES.md",
            ]
        )
        #expect(
            try ResolverCandidateFixture.snapshotSemanticFingerprint(
                first.resolvedCanonSnapshot,
                excludingADRs: false
            )
                == ResolverCandidateFixture.snapshotSemanticFingerprint(
                    second.resolvedCanonSnapshot,
                    excludingADRs: false
                )
        )
        #expect(first.resolvedPluginInventoryDigest != second.resolvedPluginInventoryDigest)
        #expect(first.resolvedActivationDigest != second.resolvedActivationDigest)
    }

    @Test("captured values replay identically after Canon, candidate, and approval paths change")
    func immutableSequentialAndConcurrentReplay() throws {
        try ResolverCandidateFixture.withResolvableFixture { fixture in
            let candidate = try fixture.validate()
            let approvalSource = fixture.workspace.appendingPathComponent(
                "integration.approval.json"
            )
            let approval = try ResolverCandidateFixture.approvalFromSource(
                for: candidate,
                timestamp: ResolverCandidateFixture.approvalTimestamp,
                source: approvalSource
            )
            let expected = try ResolverCandidateFixture.expectedFingerprint(
                fixture: fixture,
                candidate: candidate,
                approval: approval
            )

            try ResolverCandidateFixture.installCoherentReplacement(
                fixture,
                approvalSource: approvalSource
            )

            let first = try CandidateOverlayResolver().resolve(candidate, approval: approval)
            let second = try CandidateOverlayResolver().resolve(candidate, approval: approval)
            #expect(try ResolutionFingerprint(first) == expected)
            #expect(try ResolutionFingerprint(second) == expected)

            let store = ConcurrentResolutionStore()
            let group = DispatchGroup()
            let queue = DispatchQueue(
                label: "candidate-overlay-resolution-replay",
                attributes: .concurrent
            )
            for _ in 0 ..< 8 {
                group.enter()
                queue.async {
                    defer { group.leave() }
                    do {
                        let result = try CandidateOverlayResolver().resolve(
                            candidate,
                            approval: approval
                        )
                        try store.append(ResolutionFingerprint(result))
                    } catch {
                        store.record(error)
                    }
                }
            }
            group.wait()
            #expect(store.errors.isEmpty)
            #expect(store.results.count == 8)
            #expect(store.results.allSatisfy { $0 == expected })
        }
    }
}

enum ResolverCandidateFixture {
    static let approvalTimestamp = try! date("2026-07-10T12:34:56.789Z")

    static let ruleTarget = "rules/core/minimal.rules.json"
    static let profileTarget = "profiles/minimal.profile.json"
    static let adrMetadataTarget = "adrs/ADR-9999-minimal-test.json"
    static let adrMarkdownTarget = "adrs/ADR-9999-minimal-test.md"
    static let chapterTarget = "chapters/core/chapter-test.chapter.json"
    static let requirementsTarget = "registry/requirements.v1.json"
    static let rulesIndexTarget = "registry/rules.index.json"
    static let profilesIndexTarget = "registry/profiles.index.json"
    static let adrsIndexTarget = "registry/adrs.index.json"
    static let chaptersIndexTarget = "registry/chapters.index.json"
    static let derivedIndexTarget = "registry/derived-artifacts.index.json"
    static let derivedTarget = "skills/brain-execute/SKILL.md"
    static let optionalFixtureTarget = "standards/specs/EXAMPLES.md"
    static let secondaryOptionalTarget = "standards/specs/BROWNFIELD_MIGRATION.md"
    static let capturedBundlePluginPath =
        "standards/canon-candidates/enterprise-v1/components/core-authority-v1.bundle.json"
    static let capturedManifestPluginPath =
        "standards/canon-candidates/enterprise-v1/candidate-overlay.v1.json"

    struct ExpectedFile: Equatable {
        let targetNamespace: CandidateTargetNamespace
        let targetRelativePath: String
        let bytes: Data
        let contentDigest: HashDigest
        let mode: UInt16
        let affectedComponents: [ActivationAffectedComponentReference]

        var targetKey: String {
            targetNamespace.rawValue + "\0" + targetRelativePath
        }
    }

    static func withResolvableFixture<T>(
        chapterMode: CandidatePortableMode = .file,
        includeOptionalPublication: Bool = true,
        _ body: (InstalledCandidateOverlayFixture) throws -> T
    ) throws -> T {
        try CandidateOverlayFixture.withValidFixture { fixture in
            try amendForResolution(
                fixture,
                chapterMode: chapterMode,
                includeOptionalPublication: includeOptionalPublication
            )
            return try body(fixture)
        }
    }

    static func approval(
        for candidate: ValidatedCandidateOverlay,
        timestamp: Date
    ) throws -> CanonActivationApprovalInput {
        try approval(
            overlayID: candidate.overlayID.rawValue,
            overlayDigest: candidate.overlayDigest,
            timestamp: timestamp
        )
    }

    static func approval(
        overlayID: String,
        overlayDigest: HashDigest,
        timestamp: Date
    ) throws -> CanonActivationApprovalInput {
        let sidecarBytes = Data(
            "{\"approval\":\"captured-integration-evidence\",\"schema_version\":1}\n".utf8
        )
        let integration = try ReviewApprovalReference(
            schemaVersion: 1,
            approvalID: "approval-integration",
            principalID: "principal-integration",
            actorID: "actor-integration",
            roleID: "Integration Approver",
            reviewedComponentID: overlayID,
            reviewedComponentDigest: overlayDigest,
            attestationID: "attestation-integration",
            attestationDigest: CanonicalTreeDigest.sha256(Data("integration".utf8))
        )
        return try CanonActivationApprovalInput(
            integrationApproval: integration,
            approvalTimestamp: timestamp,
            approvalSourceArtifactID: "integration-approval-artifact",
            approvalSourceArtifactDigest: CanonicalTreeDigest.sha256(
                Data("signed integration approval".utf8)
            ),
            approvalSidecarRelativePath: "evidence/integration.approval.json",
            approvalSidecarBytes: sidecarBytes,
            approvalSidecarDigest: CanonicalTreeDigest.sha256(sidecarBytes)
        )
    }

    static func approvalFromSource(
        for candidate: ValidatedCandidateOverlay,
        timestamp: Date,
        source: URL
    ) throws -> CanonActivationApprovalInput {
        let projected = try approval(
            for: candidate,
            timestamp: timestamp
        )
        try projected.approvalSidecarBytes.write(to: source, options: .atomic)
        let captured = try Data(contentsOf: source)
        return try CanonActivationApprovalInput(
            integrationApproval: projected.integrationApproval,
            approvalTimestamp: projected.approvalTimestamp,
            approvalSourceArtifactID: projected.approvalSourceArtifactID,
            approvalSourceArtifactDigest: projected.approvalSourceArtifactDigest,
            approvalSidecarRelativePath: projected.approvalSidecarRelativePath,
            approvalSidecarBytes: captured,
            approvalSidecarDigest: CanonicalTreeDigest.sha256(captured)
        )
    }

    static func expectedFiles(
        fixture: InstalledCandidateOverlayFixture,
        approvalTimestamp: Date
    ) throws -> [ExpectedFile] {
        let component = try [ActivationAffectedComponentReference(
            componentKind: "enterprise-routing",
            componentID: "core-authority-v1"
        )]
        let candidate = fixture.candidateRoot
        let expectedRule = try transformedRule(
            data: Data(contentsOf: candidateFile(ruleTarget, in: candidate)),
            targetProductVersion: "1.0.0"
        )
        let expectedADR = try transformedADR(
            data: Data(contentsOf: candidateFile(adrMetadataTarget, in: candidate)),
            approvalTimestamp: approvalTimestamp
        )
        let expectedRequirements = try transformedRequirements(
            data: Data(contentsOf: candidateFile(requirementsTarget, in: candidate))
        )
        var transformedByPath: [String: Data] = [
            ruleTarget: expectedRule,
            adrMetadataTarget: expectedADR,
            requirementsTarget: expectedRequirements,
        ]
        for target in [
            profileTarget,
            adrMarkdownTarget,
            chapterTarget,
            derivedTarget,
        ] {
            transformedByPath[target] = try Data(
                contentsOf: candidateFile(target, in: candidate)
            )
        }
        let manifest = try CanonicalJSON.decode(
            CandidateOverlayManifest.self,
            from: Data(
                contentsOf: candidate.appendingPathComponent("candidate-overlay.v1.json")
            )
        )
        let optionalTarget = try #require(
            manifest.fixtures.first { $0.id == "FIX-CAN-001" }?.targetRelativePath
        )
        transformedByPath[optionalTarget] = try Data(
            contentsOf: candidate.appendingPathComponent(
                "payloads/evidence/fixtures/FIX-CAN-001.json"
            )
        )

        let regularSources: [(String, String)] = [
            (rulesIndexTarget, ruleTarget),
            (profilesIndexTarget, profileTarget),
            (adrsIndexTarget, adrMetadataTarget),
            (chaptersIndexTarget, chapterTarget),
        ]
        for (indexPath, sourcePath) in regularSources {
            let candidateIndex = try Data(
                contentsOf: candidateFile(indexPath, in: candidate)
            )
            transformedByPath[indexPath] = try transformedRecordIndex(
                data: candidateIndex,
                entryID: indexEntryID(for: indexPath),
                recordDigest: CanonicalTreeDigest.sha256(
                    #require(transformedByPath[sourcePath])
                )
            )
        }
        transformedByPath[derivedIndexTarget] = try Data(
            contentsOf: candidateFile(derivedIndexTarget, in: candidate)
        )

        let bundleData = try Data(
            contentsOf: candidate.appendingPathComponent(
                "components/core-authority-v1.bundle.json"
            )
        )
        let bundle = try CanonicalJSON.decode(CandidateComponentBundle.self, from: bundleData)
        let publications = Dictionary(
            uniqueKeysWithValues: bundle.publications.map { ($0.targetRelativePath, $0) }
        )
        let namespaces: [String: CandidateTargetNamespace] = [
            ruleTarget: .canon,
            profileTarget: .canon,
            adrMetadataTarget: .canon,
            adrMarkdownTarget: .canon,
            chapterTarget: .canon,
            requirementsTarget: .canon,
            rulesIndexTarget: .canon,
            profilesIndexTarget: .canon,
            adrsIndexTarget: .canon,
            chaptersIndexTarget: .canon,
            derivedIndexTarget: .canon,
            derivedTarget: .pluginDerived,
            optionalTarget: .pluginDerived,
        ]
        #expect(manifest.targetProductVersion == "1.0.0")
        return try transformedByPath.map { path, bytes in
            let publication = try #require(publications[path])
            return try ExpectedFile(
                targetNamespace: #require(namespaces[path]),
                targetRelativePath: path,
                bytes: bytes,
                contentDigest: CanonicalTreeDigest.sha256(bytes),
                mode: publication.targetMode.rawValue,
                affectedComponents: component
            )
        }.sorted { canonicalLess($0.targetKey, $1.targetKey) }
    }

    static func expectedDirectories(
        path: String = "standards/specs",
        components: [ActivationAffectedComponentReference]? = nil
    ) throws -> [ResolvedCandidateOutputDirectory] {
        let owners = try components ?? [ActivationAffectedComponentReference(
            componentKind: "enterprise-routing",
            componentID: "core-authority-v1"
        )]
        return [ResolvedCandidateOutputDirectory(
            targetNamespace: .pluginDerived,
            targetRelativePath: path,
            mode: CandidatePortableMode.executable.rawValue,
            affectedComponents: owners
        )]
    }

    static func expectedTransitions(
        candidate: ValidatedCandidateOverlay,
        files: [ExpectedFile],
        directories: [ResolvedCandidateOutputDirectory]
    ) throws -> [ActivationDigestTransition] {
        var transitions: [ActivationDigestTransition] = []
        for file in files {
            let base = file.targetNamespace == .canon
                ? candidate.canonEvidence.fullInventory
                : candidate.basePluginEvidence.inventory
            let before = base.entries.first { $0.relativePath == file.targetRelativePath }
            let after = try CanonicalTreeEntry(
                relativePath: file.targetRelativePath,
                kind: .regularFile,
                contentSHA256: file.contentDigest,
                mode: file.mode
            )
            try transitions.append(ActivationDigestTransition(
                targetNamespace: file.targetNamespace,
                targetRelativePath: file.targetRelativePath,
                affectedComponents: file.affectedComponents,
                beforeEntry: before,
                afterEntry: after
            ))
        }
        for directory in directories {
            let base = directory.targetNamespace == .canon
                ? candidate.canonEvidence.fullInventory
                : candidate.basePluginEvidence.inventory
            let before = base.entries.first { $0.relativePath == directory.targetRelativePath }
            let after = try CanonicalTreeEntry(
                relativePath: directory.targetRelativePath,
                kind: .directory,
                contentSHA256: nil,
                mode: directory.mode
            )
            try transitions.append(ActivationDigestTransition(
                targetNamespace: directory.targetNamespace,
                targetRelativePath: directory.targetRelativePath,
                affectedComponents: directory.affectedComponents,
                beforeEntry: before,
                afterEntry: after
            ))
        }
        return transitions.sorted { canonicalLess($0.targetKey, $1.targetKey) }
    }

    static func installAbsentProfileInheritance(
        in fixture: InstalledCandidateOverlayFixture
    ) throws {
        let candidate = fixture.candidateRoot
        let manifestURL = candidate.appendingPathComponent("candidate-overlay.v1.json")
        let bundleURL = candidate.appendingPathComponent(
            "components/core-authority-v1.bundle.json"
        )
        var manifest = try object(at: manifestURL)
        var bundle = try object(at: bundleURL)
        let profileURL = candidateFile(profileTarget, in: candidate)
        var profile = try object(at: profileURL)
        profile["inherits_profile_ids"] = ["absent-profile"]
        let profileData = try canonicalFileData(profile)
        _ = try CanonicalJSON.decode(ProfileRecord.self, from: profileData)
        try write(profileData, to: profileURL)
        let profileDigest = CanonicalTreeDigest.sha256(profileData)
        try updateArtifact("profile-minimal", digest: profileDigest, in: &bundle)
        try updateFirst("profiles", id: "core", in: &manifest) {
            $0["candidate_full_digest"] = profileDigest.rawValue
        }

        let indexURL = candidateFile(profilesIndexTarget, in: candidate)
        let indexData = try transformedRecordIndex(
            data: Data(contentsOf: indexURL),
            entryID: "core",
            recordDigest: profileDigest
        )
        try write(indexData, to: indexURL)
        let indexDigest = CanonicalTreeDigest.sha256(indexData)
        try updateArtifact("profiles-index", digest: indexDigest, in: &bundle)
        try updateIndex(
            id: "profiles-index",
            fullDigest: indexDigest,
            recordDigest: profileDigest,
            in: &manifest
        )
        try writeRebound(bundle: bundle, manifest: &manifest, fixture: fixture)
        try write(canonicalFileData(manifest), to: manifestURL)
        try normalizeCandidateModes(candidate)
    }

    static func installSecondBaseProfileAndRebind(
        _ fixture: InstalledCandidateOverlayFixture,
        selectedProfile: ProfileID
    ) throws -> CanonSnapshot {
        let baseRuleURL = fixture.canonRoot.appendingPathComponent(ruleTarget)
        var baseRule = try object(at: baseRuleURL)
        baseRule["profile_ids"] = ["core", "secondary"]
        let baseRuleData = try canonicalFileData(baseRule)
        let baseRuleRecord = try CanonicalJSON.decode(
            RuleRecord.self,
            from: baseRuleData
        )
        let baseRuleSemanticDigest = try RuleSemanticDigest.digest(baseRuleRecord)
        try write(baseRuleData, to: baseRuleURL)
        let baseRuleDigest = CanonicalTreeDigest.sha256(baseRuleData)
        let baseRulesIndexURL = fixture.canonRoot.appendingPathComponent(rulesIndexTarget)
        let baseRulesIndexData = try transformedRecordIndex(
            data: Data(contentsOf: baseRulesIndexURL),
            entryID: "CAN-MINIMAL-001",
            recordDigest: baseRuleDigest
        )
        try write(baseRulesIndexData, to: baseRulesIndexURL)

        let baseDerivedIndexURL = fixture.canonRoot.appendingPathComponent(
            derivedIndexTarget
        )
        var baseDerivedIndex = try object(at: baseDerivedIndexURL)
        var baseDerivedEntries = try objects(baseDerivedIndex["entries"])
        for index in baseDerivedEntries.indices {
            try replaceSemanticBinding(
                sourceKind: "rule",
                digest: baseRuleSemanticDigest,
                in: &baseDerivedEntries[index]
            )
        }
        let candidateDerivedTemplateURL = candidateFile(
            derivedIndexTarget,
            in: fixture.candidateRoot
        )
        let candidateDerivedTemplate = try object(at: candidateDerivedTemplateURL)
        var derivedSentinel = try #require(
            objects(candidateDerivedTemplate["entries"]).first
        )
        try replaceSemanticBinding(
            sourceKind: "rule",
            digest: baseRuleSemanticDigest,
            in: &derivedSentinel
        )
        derivedSentinel["file_digest"] = CanonicalTreeDigest.sha256(
            Data("unfollowed derived sentinel".utf8)
        ).rawValue
        derivedSentinel["index_key"] = "standards.sentinel"
        derivedSentinel["target_path"] = "skills/sentinel/SKILL.md"
        baseDerivedEntries.append(derivedSentinel)
        baseDerivedEntries.sort {
            canonicalLess(string($0["target_path"]), string($1["target_path"]))
        }
        baseDerivedIndex["entries"] = baseDerivedEntries
        let baseDerivedIndexData = try canonicalFileData(baseDerivedIndex)
        _ = try CanonicalJSON.decode(
            CanonDerivedArtifactIndex.self,
            from: baseDerivedIndexData
        )
        try write(baseDerivedIndexData, to: baseDerivedIndexURL)

        let baseProfileURL = fixture.canonRoot.appendingPathComponent(profileTarget)
        var secondaryProfile = try object(at: baseProfileURL)
        secondaryProfile["description"] = "Unselected profile retained by whole-Canon resolution."
        secondaryProfile["display_name"] = "Secondary Canon"
        secondaryProfile["id"] = "secondary"
        secondaryProfile["rule_ids"] = ["CAN-MINIMAL-001"]
        let secondaryData = try canonicalFileData(secondaryProfile)
        _ = try CanonicalJSON.decode(ProfileRecord.self, from: secondaryData)
        let secondaryPath = "profiles/secondary.profile.json"
        try write(
            secondaryData,
            to: fixture.canonRoot.appendingPathComponent(secondaryPath)
        )

        let baseIndexURL = fixture.canonRoot.appendingPathComponent(profilesIndexTarget)
        var baseIndex = try object(at: baseIndexURL)
        var baseEntries = try objects(baseIndex["entries"])
        baseEntries.append([
            "id": "secondary",
            "record_digest": CanonicalTreeDigest.sha256(secondaryData).rawValue,
            "relative_path": secondaryPath,
        ])
        baseEntries.sort { canonicalLess(string($0["id"]), string($1["id"])) }
        baseIndex["entries"] = baseEntries
        let baseIndexData = try canonicalFileData(baseIndex)
        try write(baseIndexData, to: baseIndexURL)
        let subset = try FileCanonRepository(anchor: fixture.anchor.canonRootAnchor())
            .snapshot(profiles: [selectedProfile])

        let candidate = fixture.candidateRoot
        let manifestURL = candidate.appendingPathComponent("candidate-overlay.v1.json")
        let bundleURL = candidate.appendingPathComponent(
            "components/core-authority-v1.bundle.json"
        )
        var manifest = try object(at: manifestURL)
        var bundle = try object(at: bundleURL)
        manifest["base_snapshot_content_digest"] = subset.snapshotContentDigest.rawValue

        let candidateRuleURL = candidateFile(ruleTarget, in: candidate)
        var candidateRuleObject = try object(at: candidateRuleURL)
        candidateRuleObject["profile_ids"] = ["core", "secondary"]
        let candidateRuleData = try canonicalFileData(candidateRuleObject)
        let candidateRule = try CanonicalJSON.decode(
            RuleRecord.self,
            from: candidateRuleData
        )
        try write(candidateRuleData, to: candidateRuleURL)
        let candidateRuleDigest = CanonicalTreeDigest.sha256(candidateRuleData)
        let candidateRuleSemanticDigest = try RuleSemanticDigest.digest(candidateRule)
        try updateArtifact("rule-minimal", digest: candidateRuleDigest, in: &bundle)
        try updateFirst("rules", id: "CAN-MINIMAL-001", in: &manifest) {
            $0["before_full_digest"] = baseRuleDigest.rawValue
            $0["candidate_full_digest"] = candidateRuleDigest.rawValue
            $0["semantic_digest"] = candidateRuleSemanticDigest.rawValue
        }
        try updatePublication("publish-rule-minimal", in: &bundle) {
            var before = try object($0["before_entry"])
            before["content_sha256"] = baseRuleDigest.rawValue
            $0["before_entry"] = before
        }
        let candidateRulesIndexURL = candidateFile(rulesIndexTarget, in: candidate)
        let candidateRulesIndexData = try transformedRecordIndex(
            data: Data(contentsOf: candidateRulesIndexURL),
            entryID: "CAN-MINIMAL-001",
            recordDigest: candidateRuleDigest
        )
        try write(candidateRulesIndexData, to: candidateRulesIndexURL)
        let candidateRulesIndexDigest = CanonicalTreeDigest.sha256(
            candidateRulesIndexData
        )
        try updateArtifact(
            "rules-index",
            digest: candidateRulesIndexDigest,
            in: &bundle
        )
        try updateIndex(
            id: "rules-index",
            fullDigest: candidateRulesIndexDigest,
            recordDigest: candidateRuleDigest,
            in: &manifest
        )
        try updateFirst("indexes", id: "rules-index", in: &manifest) {
            $0["before_full_digest"] = CanonicalTreeDigest.sha256(
                baseRulesIndexData
            ).rawValue
        }
        try updatePublication("publish-rules-index", in: &bundle) {
            var before = try object($0["before_entry"])
            before["content_sha256"] = CanonicalTreeDigest.sha256(
                baseRulesIndexData
            ).rawValue
            $0["before_entry"] = before
        }

        let candidateIndexURL = candidateFile(profilesIndexTarget, in: candidate)
        var candidateIndex = try object(at: candidateIndexURL)
        var candidateEntries = try objects(candidateIndex["entries"])
        candidateEntries.append([
            "id": "secondary",
            "record_digest": CanonicalTreeDigest.sha256(secondaryData).rawValue,
            "relative_path": secondaryPath,
        ])
        candidateEntries.sort { canonicalLess(string($0["id"]), string($1["id"])) }
        candidateIndex["entries"] = candidateEntries
        let candidateIndexData = try canonicalFileData(candidateIndex)
        try write(candidateIndexData, to: candidateIndexURL)
        let candidateIndexDigest = CanonicalTreeDigest.sha256(candidateIndexData)
        try updateArtifact(
            "profiles-index",
            digest: candidateIndexDigest,
            in: &bundle
        )
        try updateIndex(
            id: "profiles-index",
            fullDigest: candidateIndexDigest,
            recordDigest: CanonicalTreeDigest.sha256(
                Data(contentsOf: candidateFile(profileTarget, in: candidate))
            ),
            in: &manifest
        )
        try updateFirst("indexes", id: "profiles-index", in: &manifest) {
            $0["before_full_digest"] = CanonicalTreeDigest.sha256(baseIndexData).rawValue
        }
        try updatePublication("publish-profiles-index", in: &bundle) {
            var before = try object($0["before_entry"])
            before["content_sha256"] = CanonicalTreeDigest.sha256(baseIndexData).rawValue
            $0["before_entry"] = before
        }

        let deltaURL = candidateFile("derived/delta-001.json", in: candidate)
        var delta = try object(at: deltaURL)
        delta["base_snapshot_content_digest"] = subset.snapshotContentDigest.rawValue
        var deltaEntries = try objects(delta["entries"])
        try replaceSemanticBinding(
            sourceKind: "rule",
            digest: candidateRuleSemanticDigest,
            in: &deltaEntries[0]
        )
        delta["entries"] = deltaEntries
        var deltaPayload = delta
        deltaPayload.removeValue(forKey: "delta_digest")
        delta["delta_digest"] = try CanonicalTreeDigest.sha256(
            canonicalValueData(deltaPayload)
        ).rawValue
        let deltaData = try canonicalFileData(delta)
        try write(deltaData, to: deltaURL)
        let deltaDigest = CanonicalTreeDigest.sha256(deltaData)
        try updateArtifact("delta-test", digest: deltaDigest, in: &bundle)
        try updateFirst(
            "derived_registration_deltas",
            id: "delta-001",
            idField: "delta_id",
            in: &manifest
        ) {
            $0["candidate_delta_digest"] = deltaDigest.rawValue
        }

        let derivedIndexURL = candidateFile(derivedIndexTarget, in: candidate)
        var derivedIndex = try object(at: derivedIndexURL)
        var derivedEntries = try objects(derivedIndex["entries"])
        try replaceSemanticBinding(
            sourceKind: "rule",
            digest: candidateRuleSemanticDigest,
            in: &derivedEntries[0]
        )
        derivedEntries.append(derivedSentinel)
        derivedEntries.sort {
            canonicalLess(string($0["target_path"]), string($1["target_path"]))
        }
        derivedIndex["entries"] = derivedEntries
        let derivedIndexData = try canonicalFileData(derivedIndex)
        try write(derivedIndexData, to: derivedIndexURL)
        let derivedIndexDigest = CanonicalTreeDigest.sha256(derivedIndexData)
        let derivedRecordDigest = try CanonicalTreeDigest.sha256(
            canonicalValueData(derivedEntries[0])
        )
        try updateArtifact(
            "derived-artifacts-index",
            digest: derivedIndexDigest,
            in: &bundle
        )
        try updateIndex(
            id: "derived-artifacts-index",
            fullDigest: derivedIndexDigest,
            recordDigest: derivedRecordDigest,
            in: &manifest
        )
        try updateFirst("indexes", id: "derived-artifacts-index", in: &manifest) {
            $0["before_full_digest"] = CanonicalTreeDigest.sha256(
                baseDerivedIndexData
            ).rawValue
        }
        try updatePublication("publish-derived-artifacts-index", in: &bundle) {
            var before = try object($0["before_entry"])
            before["content_sha256"] = CanonicalTreeDigest.sha256(
                baseDerivedIndexData
            ).rawValue
            $0["before_entry"] = before
        }
        try writeRebound(bundle: bundle, manifest: &manifest, fixture: fixture)
        try write(canonicalFileData(manifest), to: manifestURL)
        try normalizeCandidateModes(candidate)
        return subset
    }

    static func installResolvableSecondComponent(
        in fixture: InstalledCandidateOverlayFixture
    ) throws {
        let secondaryID = "secondary-authority-v1"
        let candidate = fixture.candidateRoot
        let manifestURL = candidate.appendingPathComponent("candidate-overlay.v1.json")
        let primaryBundleURL = candidate.appendingPathComponent(
            "components/core-authority-v1.bundle.json"
        )
        var manifest = try object(at: manifestURL)
        var primaryBundle = try object(at: primaryBundleURL)

        var primaryArtifacts = try objects(primaryBundle["artifacts"])
        let profileArtifactObject = try #require(
            primaryArtifacts.first { $0["artifact_id"] as? String == "profiles-index" }
        )
        let migrationArtifactObject = try #require(
            primaryArtifacts.first { $0["artifact_id"] as? String == "migration-test" }
        )
        primaryArtifacts.removeAll {
            let id = $0["artifact_id"] as? String
            return id == "profiles-index" || id == "migration-test"
        }
        primaryBundle["artifacts"] = primaryArtifacts

        var primaryPublications = try objects(primaryBundle["publications"])
        let profilePublicationObject = try #require(
            primaryPublications.first {
                $0["publication_id"] as? String == "publish-profiles-index"
            }
        )
        primaryPublications.removeAll {
            $0["publication_id"] as? String == "publish-profiles-index"
        }
        primaryBundle["publications"] = primaryPublications

        let profileArtifact = try CanonicalJSON.decode(
            CandidateBundleArtifact.self,
            from: canonicalValueData(profileArtifactObject)
        )
        let migrationArtifact = try CanonicalJSON.decode(
            CandidateBundleArtifact.self,
            from: canonicalValueData(migrationArtifactObject)
        )
        let profilePublication = try CanonicalJSON.decode(
            CandidateBundlePublication.self,
            from: canonicalValueData(profilePublicationObject)
        )
        let migrationPublication = try CandidateBundlePublication(
            publicationID: "publish-migration-resolver",
            artifactID: migrationArtifact.artifactID,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetRelativePath: secondaryOptionalTarget,
            targetMode: .file,
            beforeEntry: nil
        )
        let secondaryDirectory = try CandidateBundleTargetDirectory(
            directoryID: "secondary-specs-parent",
            targetNamespace: .pluginDerived,
            targetRelativePath: "standards/specs",
            mode: .executable,
            publicationIDs: [migrationPublication.publicationID]
        )
        let secondaryBundle = try CandidateComponentBundle(
            schemaVersion: 1,
            schemaIdentity: .v1,
            schemaDigest: ComponentBundleSchemaIdentity.v1.schemaDigest,
            componentID: secondaryID,
            componentKind: "enterprise-routing",
            accountableOwnerRoleID: "Canon Maintainer",
            bundleRelativePath: "components/\(secondaryID).bundle.json",
            artifacts: [profileArtifact, migrationArtifact].sorted {
                canonicalLess($0.artifactID, $1.artifactID)
            },
            publications: [profilePublication, migrationPublication].sorted {
                canonicalLess($0.publicationID, $1.publicationID)
            },
            targetDirectories: [secondaryDirectory]
        )
        let secondaryData = try canonicalFileData(secondaryBundle)
        try write(
            secondaryData,
            to: candidate.appendingPathComponent(secondaryBundle.bundleRelativePath)
        )
        let secondaryDigest = try ComponentBundleSchemaIdentity.v1.componentDigest(
            for: secondaryData
        )
        let reviewed = try reviewedComponent(
            componentKind: secondaryBundle.componentKind,
            componentDigest: secondaryDigest,
            componentID: secondaryID,
            identitySuffix: "secondary"
        )
        var reviewedComponents = try objects(manifest["reviewed_components"])
        try reviewedComponents.append(jsonObject(reviewed))
        reviewedComponents.sort {
            canonicalLess(string($0["component_id"]), string($1["component_id"]))
        }
        manifest["reviewed_components"] = reviewedComponents
        try updateFirst("indexes", id: "profiles-index", in: &manifest) {
            $0["reviewed_component_id"] = secondaryID
        }
        try updateFirst("migrations", id: "MIG-CAN-001", in: &manifest) {
            $0["reviewed_component_id"] = secondaryID
            $0["bundle_publication_id"] = migrationPublication.publicationID
            $0["target_relative_path"] = secondaryOptionalTarget
        }
        try canonicalizeArrays(bundle: &primaryBundle, manifest: &manifest)
        try writeRebound(
            bundle: primaryBundle,
            manifest: &manifest,
            fixture: fixture
        )
        try write(canonicalFileData(manifest), to: manifestURL)
        try normalizeCandidateModes(candidate)
    }

    static func removeSecondaryDirectoryOwner(
        from fixture: InstalledCandidateOverlayFixture
    ) throws {
        let secondaryID = "secondary-authority-v1"
        let bundleURL = fixture.candidateRoot.appendingPathComponent(
            "components/\(secondaryID).bundle.json"
        )
        let manifestURL = fixture.candidateRoot.appendingPathComponent(
            "candidate-overlay.v1.json"
        )
        var bundle = try object(at: bundleURL)
        bundle["target_directories"] = []
        let data = try canonicalFileData(bundle)
        try write(data, to: bundleURL)
        let digest = try ComponentBundleSchemaIdentity.v1.componentDigest(for: data)
        var manifest = try object(at: manifestURL)
        var reviewed = try objects(manifest["reviewed_components"])
        let index = try #require(
            reviewed.firstIndex { $0["component_id"] as? String == secondaryID }
        )
        reviewed[index]["component_digest"] = digest.rawValue
        for key in ["accountable_owner_approval", "independent_reviewer_approval"] {
            var approval = try object(reviewed[index][key])
            approval["reviewed_component_digest"] = digest.rawValue
            reviewed[index][key] = approval
        }
        manifest["reviewed_components"] = reviewed
        try write(canonicalFileData(manifest), to: manifestURL)
        try normalizeCandidateModes(fixture.candidateRoot)
    }

    static func reviewedComponent(
        componentKind: String,
        componentDigest: HashDigest,
        componentID: String,
        identitySuffix: String
    ) throws -> ReviewedComponentApproval {
        let owner = try ReviewApprovalReference(
            schemaVersion: 1,
            approvalID: "approval-owner-\(identitySuffix)",
            principalID: "principal-owner-\(identitySuffix)",
            actorID: "actor-owner-\(identitySuffix)",
            roleID: "Canon Maintainer",
            reviewedComponentID: componentID,
            reviewedComponentDigest: componentDigest,
            attestationID: "attestation-owner-\(identitySuffix)",
            attestationDigest: CanonicalTreeDigest.sha256(
                Data("owner-\(identitySuffix)".utf8)
            )
        )
        let reviewer = try ReviewApprovalReference(
            schemaVersion: 1,
            approvalID: "approval-reviewer-\(identitySuffix)",
            principalID: "principal-reviewer-\(identitySuffix)",
            actorID: "actor-reviewer-\(identitySuffix)",
            roleID: "Independent Reviewer",
            reviewedComponentID: componentID,
            reviewedComponentDigest: componentDigest,
            attestationID: "attestation-reviewer-\(identitySuffix)",
            attestationDigest: CanonicalTreeDigest.sha256(
                Data("reviewer-\(identitySuffix)".utf8)
            )
        )
        return try ReviewedComponentApproval(
            componentID: componentID,
            componentKind: componentKind,
            bundleRelativePath: "components/\(componentID).bundle.json",
            bundleSchemaIdentity: .v1,
            bundleSchemaDigest: ComponentBundleSchemaIdentity.v1.schemaDigest,
            componentDigest: componentDigest,
            accountableOwnerRoleID: "Canon Maintainer",
            accountableOwnerApproval: owner,
            independentReviewerApproval: reviewer
        )
    }

    static func amendForResolution(
        _ fixture: InstalledCandidateOverlayFixture,
        chapterMode: CandidatePortableMode,
        includeOptionalPublication: Bool
    ) throws {
        let candidate = fixture.candidateRoot
        let manifestURL = candidate.appendingPathComponent("candidate-overlay.v1.json")
        let bundleURL = candidate.appendingPathComponent(
            "components/core-authority-v1.bundle.json"
        )
        var manifest = try object(at: manifestURL)
        var bundle = try object(at: bundleURL)
        manifest["target_product_version"] = "1.0.0"

        let ruleURL = candidateFile(ruleTarget, in: candidate)
        var ruleObject = try object(at: ruleURL)
        ruleObject["effective_in"] = "1.0.0"
        let ruleData = try canonicalFileData(ruleObject)
        try write(ruleData, to: ruleURL)
        let rule = try CanonicalJSON.decode(RuleRecord.self, from: ruleData)
        let ruleDigest = CanonicalTreeDigest.sha256(ruleData)
        try updateArtifact("rule-minimal", digest: ruleDigest, in: &bundle)
        try updateFirst("rules", id: rule.id.rawValue, in: &manifest) { binding in
            binding["candidate_full_digest"] = ruleDigest.rawValue
            binding["semantic_digest"] = try RuleSemanticDigest.digest(rule).rawValue
        }

        let profileURL = candidateFile(profileTarget, in: candidate)
        var profileObject = try object(at: profileURL)
        profileObject["description"] = "Resolved profile captured entirely before approval."
        let profileData = try canonicalFileData(profileObject)
        try write(profileData, to: profileURL)
        let profileDigest = CanonicalTreeDigest.sha256(profileData)
        try updateArtifact("profile-minimal", digest: profileDigest, in: &bundle)
        try updateFirst("profiles", id: "core", in: &manifest) { binding in
            binding["candidate_full_digest"] = profileDigest.rawValue
        }

        let markdownURL = candidateFile(adrMarkdownTarget, in: candidate)
        var markdownData = try Data(contentsOf: markdownURL)
        markdownData.append(Data("\nCaptured resolver evidence is immutable.\n".utf8))
        try write(markdownData, to: markdownURL)
        let markdownDigest = CanonicalTreeDigest.sha256(markdownData)
        let metadataURL = candidateFile(adrMetadataTarget, in: candidate)
        var metadataObject = try object(at: metadataURL)
        metadataObject["markdown_digest"] = markdownDigest.rawValue
        let metadataData = try canonicalFileData(metadataObject)
        try write(metadataData, to: metadataURL)
        let metadata = try CanonicalJSON.decode(ADRMetadata.self, from: metadataData)
        let markdown = try #require(String(data: markdownData, encoding: .utf8))
        let metadataDigest = CanonicalTreeDigest.sha256(metadataData)
        let adrSemanticDigest = try ADRSemanticDigest.digest(
            metadata: metadata,
            markdown: markdown
        )
        try updateArtifact("adr-9999-markdown", digest: markdownDigest, in: &bundle)
        try updateArtifact("adr-9999-metadata", digest: metadataDigest, in: &bundle)
        try updateFirst("adrs", id: metadata.id.rawValue, in: &manifest) { binding in
            binding["candidate_metadata_full_digest"] = metadataDigest.rawValue
            binding["candidate_markdown_full_digest"] = markdownDigest.rawValue
            binding["semantic_digest"] = adrSemanticDigest.rawValue
        }

        let deltaURL = candidateFile("derived/delta-001.json", in: candidate)
        var deltaObject = try object(at: deltaURL)
        var deltaEntries = try objects(deltaObject["entries"])
        try replaceSemanticBinding(
            sourceKind: "adr",
            digest: adrSemanticDigest,
            in: &deltaEntries[0]
        )
        deltaObject["entries"] = deltaEntries
        var deltaDigestPayload = deltaObject
        deltaDigestPayload.removeValue(forKey: "delta_digest")
        deltaObject["delta_digest"] = try CanonicalTreeDigest.sha256(
            canonicalValueData(deltaDigestPayload)
        ).rawValue
        let deltaData = try canonicalFileData(deltaObject)
        try write(deltaData, to: deltaURL)
        let deltaDigest = CanonicalTreeDigest.sha256(deltaData)
        try updateArtifact("delta-test", digest: deltaDigest, in: &bundle)
        try updateFirst(
            "derived_registration_deltas",
            id: "delta-001",
            idField: "delta_id",
            in: &manifest
        ) {
            $0["candidate_delta_digest"] = deltaDigest.rawValue
        }

        let derivedIndexURL = candidateFile(derivedIndexTarget, in: candidate)
        var derivedIndexObject = try object(at: derivedIndexURL)
        var derivedEntries = try objects(derivedIndexObject["entries"])
        try replaceSemanticBinding(
            sourceKind: "adr",
            digest: adrSemanticDigest,
            in: &derivedEntries[0]
        )
        derivedIndexObject["entries"] = derivedEntries
        let derivedIndexData = try canonicalFileData(derivedIndexObject)
        try write(derivedIndexData, to: derivedIndexURL)
        let derivedIndexDigest = CanonicalTreeDigest.sha256(derivedIndexData)
        let derivedRecordDigest = try CanonicalTreeDigest.sha256(
            canonicalValueData(derivedEntries[0])
        )
        try updateArtifact(
            "derived-artifacts-index",
            digest: derivedIndexDigest,
            in: &bundle
        )
        try updateIndex(
            id: "derived-artifacts-index",
            fullDigest: derivedIndexDigest,
            recordDigest: derivedRecordDigest,
            in: &manifest
        )

        let rulesIndexURL = candidateFile(rulesIndexTarget, in: candidate)
        let rulesIndexData = try transformedRecordIndex(
            data: Data(contentsOf: rulesIndexURL),
            entryID: rule.id.rawValue,
            recordDigest: ruleDigest
        )
        try write(rulesIndexData, to: rulesIndexURL)
        let rulesIndexDigest = CanonicalTreeDigest.sha256(rulesIndexData)
        try updateArtifact("rules-index", digest: rulesIndexDigest, in: &bundle)
        try updateIndex(
            id: "rules-index",
            fullDigest: rulesIndexDigest,
            recordDigest: ruleDigest,
            in: &manifest
        )

        try addRegularIndex(
            id: "profiles-index",
            entryID: "core",
            sourceKind: "profile_record",
            sourcePath: profileTarget,
            recordDigest: profileDigest,
            targetPath: profilesIndexTarget,
            fixture: fixture,
            bundle: &bundle,
            manifest: &manifest
        )
        try addRegularIndex(
            id: "adrs-index",
            entryID: metadata.id.rawValue,
            sourceKind: "adr_metadata",
            sourcePath: adrMetadataTarget,
            recordDigest: metadataDigest,
            targetPath: adrsIndexTarget,
            fixture: fixture,
            bundle: &bundle,
            manifest: &manifest
        )
        let chapterURL = candidateFile(chapterTarget, in: candidate)
        var chapterObject = try object(at: chapterURL)
        chapterObject["check_ids"] = ["CHK-CAN-MINIMAL-001"]
        chapterObject["positive_fixture_ids"] = ["FIX-CAN-MINIMAL-001-PASS"]
        chapterObject["negative_fixture_ids"] = ["FIX-CAN-MINIMAL-001-FAIL-001"]
        let chapterData = try canonicalFileData(chapterObject)
        try write(chapterData, to: chapterURL)
        let chapterDigest = CanonicalTreeDigest.sha256(chapterData)
        try updateArtifact("chapter-test", digest: chapterDigest, in: &bundle)
        try updateFirst("chapters", id: "chapter-test", in: &manifest) {
            $0["candidate_file_digest"] = chapterDigest.rawValue
        }
        try addRegularIndex(
            id: "chapters-index",
            entryID: "chapter-test",
            sourceKind: "chapter_metadata",
            sourcePath: chapterTarget,
            recordDigest: chapterDigest,
            targetPath: chaptersIndexTarget,
            fixture: fixture,
            bundle: &bundle,
            manifest: &manifest
        )

        try updatePublication("publish-chapter-test", in: &bundle) {
            $0["target_mode"] = Int(chapterMode.rawValue)
        }
        if includeOptionalPublication {
            try addOptionalFixturePublication(bundle: &bundle, manifest: &manifest)
        }
        try canonicalizeArrays(bundle: &bundle, manifest: &manifest)
        try writeRebound(bundle: bundle, manifest: &manifest, fixture: fixture)
        try write(canonicalFileData(manifest), to: manifestURL)
        try normalizeCandidateModes(candidate)
    }

    static func addRegularIndex(
        id: String,
        entryID: String,
        sourceKind: String,
        sourcePath: String,
        recordDigest: HashDigest,
        targetPath: String,
        fixture: InstalledCandidateOverlayFixture,
        bundle: inout [String: Any],
        manifest: inout [String: Any]
    ) throws {
        let baseURL = fixture.canonRoot.appendingPathComponent(targetPath)
        let candidateURL = candidateFile(targetPath, in: fixture.candidateRoot)
        var indexObject = try object(at: baseURL)
        var entries = try objects(indexObject["entries"])
        if let position = entries.firstIndex(where: { $0["id"] as? String == entryID }) {
            entries[position]["record_digest"] = recordDigest.rawValue
            entries[position]["relative_path"] = sourcePath
        } else {
            entries.append([
                "id": entryID,
                "record_digest": recordDigest.rawValue,
                "relative_path": sourcePath,
            ])
        }
        entries.sort { canonicalLess(string($0["id"]), string($1["id"])) }
        indexObject["entries"] = entries
        let data = try canonicalFileData(indexObject)
        try write(data, to: candidateURL)
        let digest = CanonicalTreeDigest.sha256(data)
        var artifacts = try objects(bundle["artifacts"])
        artifacts.append([
            "artifact_id": id,
            "candidate_file_digest": digest.rawValue,
            "candidate_relative_path": candidateRelativePath(targetPath),
            "family": "index",
            "logical_id": id,
        ])
        bundle["artifacts"] = artifacts

        var publications = try objects(bundle["publications"])
        try publications.append([
            "artifact_id": id,
            "before_entry": beforeEntry(at: baseURL),
            "publication_id": "publish-\(id)",
            "publication_kind": "resolver_transformed",
            "target_mode": Int(CandidatePortableMode.file.rawValue),
            "target_namespace": "canon",
            "target_relative_path": targetPath,
        ])
        bundle["publications"] = publications

        var indexes = try objects(manifest["indexes"])
        try indexes.append([
            "before_full_digest": CanonicalTreeDigest.sha256(
                Data(contentsOf: baseURL)
            ).rawValue,
            "bundle_artifact_id": id,
            "bundle_publication_id": "publish-\(id)",
            "candidate_full_digest": digest.rawValue,
            "entries": [[
                "candidate_record_digest": recordDigest.rawValue,
                "id": entryID,
            ]],
            "id": id,
            "reviewed_component_id": "core-authority-v1",
            "target_relative_path": targetPath,
        ])
        manifest["indexes"] = indexes

        var transforms = try object(manifest["activation_transform_set"])
        var indexTransforms = try objects(transforms["index_entries"])
        indexTransforms.append([
            "entry_id": entryID,
            "index_id": id,
            "source_id": entryID,
            "source_kind": sourceKind,
            "source_relative_path": sourcePath,
        ])
        transforms["index_entries"] = indexTransforms
        manifest["activation_transform_set"] = transforms
    }

    static func addOptionalFixturePublication(
        bundle: inout [String: Any],
        manifest: inout [String: Any]
    ) throws {
        let directoryPath = "standards/specs"
        let targetPath = optionalFixtureTarget
        var publications = try objects(bundle["publications"])
        publications.append([
            "artifact_id": "fixture-test",
            "publication_id": "publish-fixture-resolver",
            "publication_kind": "exact_copy",
            "target_mode": Int(CandidatePortableMode.file.rawValue),
            "target_namespace": "plugin_derived",
            "target_relative_path": targetPath,
        ])
        bundle["publications"] = publications
        var directories = try objects(bundle["target_directories"])
        directories.append([
            "directory_id": "resolver-specs-parent",
            "mode": Int(CandidatePortableMode.executable.rawValue),
            "publication_ids": ["publish-fixture-resolver"],
            "target_namespace": "plugin_derived",
            "target_relative_path": directoryPath,
        ])
        bundle["target_directories"] = directories
        try updateFirst("fixtures", id: "FIX-CAN-001", in: &manifest) { binding in
            binding["bundle_publication_id"] = "publish-fixture-resolver"
            binding["target_relative_path"] = targetPath
        }
    }

    static func appendExtraRuleTransform(
        to fixture: InstalledCandidateOverlayFixture
    ) throws {
        let url = fixture.candidateRoot.appendingPathComponent("candidate-overlay.v1.json")
        var manifest = try object(at: url)
        var transformSet = try object(manifest["activation_transform_set"])
        var rules = try objects(transformSet["rules"])
        rules.append([
            "effective_in_source": "target_product_version",
            "id": "CAN-EXTRA-001",
            "lifecycle_source": "constant_active",
        ])
        transformSet["rules"] = rules
        manifest["activation_transform_set"] = transformSet
        try write(canonicalFileData(manifest), to: url)
    }

    static func duplicateRuleTransform(
        in fixture: InstalledCandidateOverlayFixture
    ) throws {
        let url = fixture.candidateRoot.appendingPathComponent("candidate-overlay.v1.json")
        var manifest = try object(at: url)
        var transformSet = try object(manifest["activation_transform_set"])
        var rules = try objects(transformSet["rules"])
        try rules.append(#require(rules.first))
        transformSet["rules"] = rules
        manifest["activation_transform_set"] = transformSet
        try write(canonicalFileData(manifest), to: url)
    }

    static func addUndeclaredPublication(
        to fixture: InstalledCandidateOverlayFixture
    ) throws {
        let manifestURL = fixture.candidateRoot.appendingPathComponent(
            "candidate-overlay.v1.json"
        )
        let bundleURL = fixture.candidateRoot.appendingPathComponent(
            "components/core-authority-v1.bundle.json"
        )
        var manifest = try object(at: manifestURL)
        var bundle = try object(at: bundleURL)
        var publications = try objects(bundle["publications"])
        publications.append([
            "artifact_id": "check-test",
            "publication_id": "publish-undeclared-check",
            "publication_kind": "exact_copy",
            "target_mode": Int(CandidatePortableMode.file.rawValue),
            "target_namespace": "plugin_derived",
            "target_relative_path": "standards/specs/EXAMPLES_PLUGIN.md",
        ])
        bundle["publications"] = publications
        var directories = try objects(bundle["target_directories"])
        directories.append([
            "directory_id": "undeclared-specs-parent",
            "mode": Int(CandidatePortableMode.executable.rawValue),
            "publication_ids": ["publish-undeclared-check"],
            "target_namespace": "plugin_derived",
            "target_relative_path": "standards/specs",
        ])
        bundle["target_directories"] = directories
        try canonicalizeArrays(bundle: &bundle, manifest: &manifest)
        try writeRebound(bundle: bundle, manifest: &manifest, fixture: fixture)
        try write(canonicalFileData(manifest), to: manifestURL)
        try normalizeCandidateModes(fixture.candidateRoot)
    }

    static func changeExistingTargetMode(
        in fixture: InstalledCandidateOverlayFixture
    ) throws {
        let bundleURL = fixture.candidateRoot.appendingPathComponent(
            "components/core-authority-v1.bundle.json"
        )
        var bundle = try object(at: bundleURL)
        try updatePublication("publish-skill-test", in: &bundle) {
            $0["target_mode"] = Int(CandidatePortableMode.executable.rawValue)
        }
        try write(canonicalFileData(bundle), to: bundleURL)
    }

    static func removeRequiredDirectory(
        from fixture: InstalledCandidateOverlayFixture
    ) throws {
        let manifestURL = fixture.candidateRoot.appendingPathComponent(
            "candidate-overlay.v1.json"
        )
        let bundleURL = fixture.candidateRoot.appendingPathComponent(
            "components/core-authority-v1.bundle.json"
        )
        var manifest = try object(at: manifestURL)
        var bundle = try object(at: bundleURL)
        bundle["target_directories"] = []
        try writeRebound(bundle: bundle, manifest: &manifest, fixture: fixture)
        try write(canonicalFileData(manifest), to: manifestURL)
        try normalizeCandidateModes(fixture.candidateRoot)
    }

    static func transformedRule(
        data: Data,
        targetProductVersion: String
    ) throws -> Data {
        var value = try object(data)
        value["effective_in"] = targetProductVersion
        value["lifecycle"] = RuleLifecycle.active.rawValue
        let result = try canonicalFileData(value)
        _ = try CanonicalJSON.decode(RuleRecord.self, from: result)
        return result
    }

    static func transformedADR(
        data: Data,
        approvalTimestamp: Date
    ) throws -> Data {
        var value = try object(data)
        value["accepted_at"] = try dateString(approvalTimestamp)
        value["status"] = ADRStatus.accepted.rawValue
        let result = try canonicalFileData(value)
        _ = try CanonicalJSON.decode(ADRMetadata.self, from: result)
        return result
    }

    static func transformedRequirements(data: Data) throws -> Data {
        var value = try object(data)
        var requirements = try objects(value["requirements"])
        let index = try #require(
            requirements.firstIndex { $0["id"] as? String == "REQ-CANON" }
        )
        requirements[index]["status"] = RequirementStatus.completed.rawValue
        value["requirements"] = requirements
        let result = try canonicalFileData(value)
        _ = try CanonicalJSON.decode(RequirementRegistry.self, from: result)
        return result
    }

    static func transformedRecordIndex(
        data: Data,
        entryID: String,
        recordDigest: HashDigest
    ) throws -> Data {
        var value = try object(data)
        var entries = try objects(value["entries"])
        let index = try #require(entries.firstIndex { $0["id"] as? String == entryID })
        entries[index]["record_digest"] = recordDigest.rawValue
        value["entries"] = entries
        return try canonicalFileData(value)
    }

    static func assertIndexSentinelsPreserved(
        fixture _: InstalledCandidateOverlayFixture,
        candidate: ValidatedCandidateOverlay,
        resolved: ResolvedCandidateActivation
    ) throws {
        #expect(candidate.manifest.activationTransformSet.indexEntries.count >= 5)
        let outputByPath = Dictionary(
            uniqueKeysWithValues: resolved.outputFiles.compactMap { output in
                output.targetNamespace == .canon
                    ? (output.targetRelativePath, output)
                    : nil
            }
        )
        let transforms = Dictionary(
            uniqueKeysWithValues: candidate.manifest.activationTransformSet.indexEntries.map {
                ($0.indexID + "\0" + $0.entryID, $0)
            }
        )
        var derivedEntriesByKey: [String: DerivedRegistrationEntry] = [:]
        for binding in candidate.manifest.derivedRegistrationDeltas {
            let bundle = try #require(candidate.componentBundles[binding.reviewedComponentID])
            let artifact = try #require(
                bundle.artifacts.first { $0.artifactID == binding.bundleArtifactID }
            )
            let captured = try #require(
                candidate.candidateTreeCapture.filesByRelativePath[
                    artifact.candidateRelativePath
                ]
            )
            let delta = try CanonicalJSON.decode(
                DerivedRegistrationDelta.self,
                from: captured.bytes
            )
            for entry in delta.entries {
                #expect(derivedEntriesByKey.updateValue(entry, forKey: entry.indexKey) == nil)
            }
        }

        for binding in candidate.manifest.indexes where [
            profilesIndexTarget,
            derivedIndexTarget,
        ].contains(binding.targetRelativePath) {
            let artifact = try #require(
                candidate.componentBundles[binding.reviewedComponentID]?.artifacts.first {
                    $0.artifactID == binding.bundleArtifactID
                }
            )
            let captured = try #require(
                candidate.candidateTreeCapture.filesByRelativePath[
                    artifact.candidateRelativePath
                ]
            )
            let actual = try #require(outputByPath[binding.targetRelativePath])
            let sourceObject = try object(captured.bytes)
            let sourceEntries = try objects(sourceObject["entries"])
            var expectedObject = sourceObject
            var expectedEntries = sourceEntries
            let declaredIDs = Set(binding.entries.map(\.id))

            if binding.targetRelativePath == derivedIndexTarget {
                for declared in binding.entries {
                    let transform = try #require(
                        transforms[binding.id + "\0" + declared.id]
                    )
                    let entry = try #require(derivedEntriesByKey[transform.sourceID])
                    let position = try #require(
                        expectedEntries.firstIndex {
                            $0["index_key"] as? String == declared.id
                        }
                    )
                    expectedEntries[position] = try object(
                        JSONSerialization.jsonObject(
                            with: CanonicalJSON.encode(entry)
                        )
                    )
                }
                expectedEntries.sort {
                    canonicalLess(string($0["target_path"]), string($1["target_path"]))
                }
                #expect(
                    expectedEntries.map { string($0["target_path"]) }
                        == expectedEntries.map { string($0["target_path"]) }
                        .sorted(by: canonicalLess)
                )
            } else {
                for declared in binding.entries {
                    let transform = try #require(
                        transforms[binding.id + "\0" + declared.id]
                    )
                    let source = try #require(outputByPath[transform.sourceRelativePath])
                    let position = try #require(
                        expectedEntries.firstIndex { $0["id"] as? String == declared.id }
                    )
                    expectedEntries[position]["record_digest"] = source.contentDigest.rawValue
                }
                #expect(
                    expectedEntries.map { string($0["id"]) }
                        == expectedEntries.map { string($0["id"]) }
                        .sorted(by: canonicalLess)
                )
            }
            expectedObject["entries"] = expectedEntries
            let expectedBytes = try canonicalFileData(expectedObject)
            #expect(actual.bytes == expectedBytes)

            let idKey = binding.targetRelativePath == derivedIndexTarget
                ? "index_key"
                : "id"
            let sourceSentinels = sourceEntries.filter {
                !declaredIDs.contains(string($0[idKey]))
            }
            let actualEntries = try objects(object(actual.bytes)["entries"])
            let actualSentinels = actualEntries.filter {
                !declaredIDs.contains(string($0[idKey]))
            }
            #expect(!sourceSentinels.isEmpty)
            #expect(
                try sourceSentinels.map(canonicalValueData)
                    == actualSentinels.map(canonicalValueData)
            )

            var rebuiltObject = try object(actual.bytes)
            rebuiltObject["entries"] = actualEntries.filter {
                declaredIDs.contains(string($0[idKey]))
            }
            #expect(try canonicalFileData(rebuiltObject) != actual.bytes)
        }
    }

    static func writeRebound(
        bundle: [String: Any],
        manifest: inout [String: Any],
        fixture: InstalledCandidateOverlayFixture
    ) throws {
        let bundleURL = fixture.candidateRoot.appendingPathComponent(
            "components/core-authority-v1.bundle.json"
        )
        let bundleData = try canonicalFileData(bundle)
        try write(bundleData, to: bundleURL)
        let digest = try ComponentBundleSchemaIdentity.v1.componentDigest(for: bundleData)
        var reviewed = try objects(manifest["reviewed_components"])
        let index = try #require(
            reviewed.firstIndex { $0["component_id"] as? String == "core-authority-v1" }
        )
        reviewed[index]["component_digest"] = digest.rawValue
        for key in ["accountable_owner_approval", "independent_reviewer_approval"] {
            var approval = try object(reviewed[index][key])
            approval["reviewed_component_digest"] = digest.rawValue
            reviewed[index][key] = approval
        }
        manifest["reviewed_components"] = reviewed
    }

    static func updateArtifact(
        _ id: String,
        digest: HashDigest,
        in bundle: inout [String: Any]
    ) throws {
        var artifacts = try objects(bundle["artifacts"])
        let index = try #require(artifacts.firstIndex { $0["artifact_id"] as? String == id })
        artifacts[index]["candidate_file_digest"] = digest.rawValue
        bundle["artifacts"] = artifacts
    }

    static func updatePublication(
        _ id: String,
        in bundle: inout [String: Any],
        mutation: (inout [String: Any]) throws -> Void
    ) throws {
        var publications = try objects(bundle["publications"])
        let index = try #require(
            publications.firstIndex { $0["publication_id"] as? String == id }
        )
        try mutation(&publications[index])
        bundle["publications"] = publications
    }

    static func updateFirst(
        _ key: String,
        id: String,
        idField: String = "id",
        in object: inout [String: Any],
        mutation: (inout [String: Any]) throws -> Void
    ) throws {
        var values = try objects(object[key])
        let index = try #require(values.firstIndex { $0[idField] as? String == id })
        try mutation(&values[index])
        object[key] = values
    }

    static func updateIndex(
        id: String,
        fullDigest: HashDigest,
        recordDigest: HashDigest,
        in manifest: inout [String: Any]
    ) throws {
        try updateFirst("indexes", id: id, in: &manifest) { binding in
            binding["candidate_full_digest"] = fullDigest.rawValue
            var entries = try objects(binding["entries"])
            entries[0]["candidate_record_digest"] = recordDigest.rawValue
            binding["entries"] = entries
        }
    }

    static func replaceSemanticBinding(
        sourceKind: String,
        digest: HashDigest,
        in entry: inout [String: Any]
    ) throws {
        var bindings = try objects(entry["source_semantic_bindings"])
        let index = try #require(
            bindings.firstIndex { $0["source_kind"] as? String == sourceKind }
        )
        bindings[index]["digest"] = digest.rawValue
        entry["source_semantic_bindings"] = bindings
    }

    static func canonicalizeArrays(
        bundle: inout [String: Any],
        manifest: inout [String: Any]
    ) throws {
        for (key, field) in [
            ("artifacts", "artifact_id"),
            ("publications", "publication_id"),
            ("target_directories", "directory_id"),
        ] {
            var values = try objects(bundle[key])
            values.sort { canonicalLess(string($0[field]), string($1[field])) }
            bundle[key] = values
        }
        var indexes = try objects(manifest["indexes"])
        indexes.sort { canonicalLess(string($0["id"]), string($1["id"])) }
        manifest["indexes"] = indexes
        var transformSet = try object(manifest["activation_transform_set"])
        var indexEntries = try objects(transformSet["index_entries"])
        indexEntries.sort {
            canonicalLess(
                string($0["index_id"]) + "\0" + string($0["entry_id"]),
                string($1["index_id"]) + "\0" + string($1["entry_id"])
            )
        }
        transformSet["index_entries"] = indexEntries
        manifest["activation_transform_set"] = transformSet
    }

    static func beforeEntry(at url: URL) throws -> [String: Any] {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let mode = try #require(attributes[.posixPermissions] as? NSNumber)
        return try [
            "content_sha256": CanonicalTreeDigest.sha256(Data(contentsOf: url)).rawValue,
            "kind": "regular_file",
            "mode": mode.intValue,
        ]
    }

    static func candidateFile(_ target: String, in candidate: URL) -> URL {
        let prefix = target.hasPrefix("skills/") || target.hasPrefix("standards/")
            ? "payloads/plugin-derived/"
            : "payloads/canon/"
        return candidate.appendingPathComponent(prefix + target)
    }

    static func candidateRelativePath(_ target: String) -> String {
        "payloads/canon/" + target
    }

    static func indexEntryID(for indexPath: String) -> String {
        switch indexPath {
        case rulesIndexTarget: "CAN-MINIMAL-001"
        case profilesIndexTarget: "core"
        case adrsIndexTarget: "ADR-9999"
        case chaptersIndexTarget: "chapter-test"
        default: ""
        }
    }

    static func date(_ value: String) throws -> Date {
        try CanonicalJSON.decode(Date.self, from: Data("\"\(value)\"".utf8))
    }

    static func dateString(_ value: Date) throws -> String {
        try CanonicalJSON.decode(String.self, from: CanonicalJSON.encode(value))
    }

    static func object(at url: URL) throws -> [String: Any] {
        try object(Data(contentsOf: url))
    }

    static func object(_ data: Data) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    static func object(_ value: Any?) throws -> [String: Any] {
        try #require(value as? [String: Any])
    }

    static func objects(_ value: Any?) throws -> [[String: Any]] {
        try #require(value as? [[String: Any]])
    }

    static func jsonObject(_ value: some Encodable) throws -> [String: Any] {
        try object(JSONSerialization.jsonObject(with: CanonicalJSON.encode(value)))
    }

    static func canonicalFileData(_ value: Any) throws -> Data {
        var data = try canonicalValueData(value)
        data.append(0x0A)
        return data
    }

    static func canonicalFileData(_ value: some Encodable) throws -> Data {
        var data = try CanonicalJSON.encode(value)
        data.append(0x0A)
        return data
    }

    static func canonicalValueData(_ value: Any) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: value,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
    }

    static func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
        try CandidateOverlayFixture.setMode(0o644, at: url)
    }

    static func normalizeCandidateModes(_ candidate: URL) throws {
        try CandidateOverlayFixture.setMode(0o755, at: candidate)
        let enumerator = try #require(FileManager.default.enumerator(
            at: candidate,
            includingPropertiesForKeys: [.isDirectoryKey]
        ))
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            try CandidateOverlayFixture.setMode(values.isDirectory == true ? 0o755 : 0o644, at: url)
        }
    }

    struct ExpectedInventories {
        let projectedCanon: CanonicalTreeInventory
        let resolvedPlugin: CanonicalTreeInventory
    }

    struct InventoryDelta {
        let changedOrAdded: Set<String>
        let deleted: Set<String>
    }

    static func expectedInventories(
        candidate: ValidatedCandidateOverlay,
        files: [ResolvedCandidateOutputFile],
        directories: [ResolvedCandidateOutputDirectory]
    ) throws -> ExpectedInventories {
        var canonEntries = Dictionary(
            uniqueKeysWithValues: candidate.canonEvidence.fullInventory.entries.map {
                ($0.relativePath, $0)
            }
        )
        for directory in directories where directory.targetNamespace == .canon {
            canonEntries[directory.targetRelativePath] = try CanonicalTreeEntry(
                relativePath: directory.targetRelativePath,
                kind: .directory,
                contentSHA256: nil,
                mode: directory.mode
            )
        }
        for file in files where file.targetNamespace == .canon {
            canonEntries[file.targetRelativePath] = try CanonicalTreeEntry(
                relativePath: file.targetRelativePath,
                kind: .regularFile,
                contentSHA256: file.contentDigest,
                mode: file.mode
            )
        }
        let fullCanon = try CanonicalTreeInventory(
            policy: candidate.canonEvidence.fullInventory.policy,
            rootMode: candidate.canonEvidence.fullInventory.rootMode,
            entries: Array(canonEntries.values)
        )
        let projectedCanon = try CanonSnapshotContentPolicy.project(fullCanon)

        var pluginEntries = Dictionary(
            uniqueKeysWithValues: candidate.basePluginEvidence.inventory.entries.map {
                ($0.relativePath, $0)
            }
        )
        for directory in directories {
            let path = directory.targetNamespace == .canon
                ? "standards/canon/" + directory.targetRelativePath
                : directory.targetRelativePath
            pluginEntries[path] = try CanonicalTreeEntry(
                relativePath: path,
                kind: .directory,
                contentSHA256: nil,
                mode: directory.mode
            )
        }
        for file in files {
            let path = file.targetNamespace == .canon
                ? "standards/canon/" + file.targetRelativePath
                : file.targetRelativePath
            pluginEntries[path] = try CanonicalTreeEntry(
                relativePath: path,
                kind: .regularFile,
                contentSHA256: file.contentDigest,
                mode: file.mode
            )
        }
        let resolvedPlugin = try CanonicalTreeInventory(
            policy: candidate.basePluginEvidence.inventory.policy,
            rootMode: candidate.basePluginEvidence.inventory.rootMode,
            entries: Array(pluginEntries.values)
        )
        return ExpectedInventories(
            projectedCanon: projectedCanon,
            resolvedPlugin: resolvedPlugin
        )
    }

    fileprivate static func expectedFingerprint(
        fixture: InstalledCandidateOverlayFixture,
        candidate: ValidatedCandidateOverlay,
        approval: CanonActivationApprovalInput
    ) throws -> ResolutionFingerprint {
        let expectedFileValues = try expectedFiles(
            fixture: fixture,
            approvalTimestamp: approval.approvalTimestamp
        )
        let files = expectedFileValues.map {
            ResolvedCandidateOutputFile(
                targetNamespace: $0.targetNamespace,
                targetRelativePath: $0.targetRelativePath,
                bytes: $0.bytes,
                contentDigest: $0.contentDigest,
                mode: $0.mode,
                affectedComponents: $0.affectedComponents
            )
        }
        let optionalTarget = try #require(
            candidate.manifest.fixtures.first {
                $0.id == "FIX-CAN-001"
            }?.targetRelativePath
        )
        let directoryPath = optionalTarget.split(separator: "/").dropLast()
            .joined(separator: "/")
        let directories = try expectedDirectories(path: directoryPath)
        let transitions = try expectedTransitions(
            candidate: candidate,
            files: expectedFileValues,
            directories: directories
        )
        let inventories = try expectedInventories(
            candidate: candidate,
            files: files,
            directories: directories
        )
        let publishedDigest = try CanonicalTreeDigest.digest(inventories.projectedCanon)
        let pluginDigest = try CanonicalTreeDigest.digest(inventories.resolvedPlugin)
        let snapshot = try expectedResolvedSnapshot(
            fixture: fixture,
            files: files,
            directories: directories
        )
        #expect(snapshot.snapshotContentDigest == publishedDigest)
        #expect(CanonValidator().validate(snapshot).isEmpty)
        let activationDigest = try expectedResolvedActivationDigest(
            candidate: candidate,
            approval: approval,
            outputFiles: files,
            outputDirectories: directories,
            digestTransitions: transitions,
            projectedPublishedCanonInventory: inventories.projectedCanon,
            publishedSnapshotContentDigest: publishedDigest,
            resolvedPluginInventory: inventories.resolvedPlugin,
            resolvedPluginInventoryDigest: pluginDigest
        )
        return try ResolutionFingerprint(
            overlayID: candidate.overlayID.rawValue,
            overlayDigest: candidate.overlayDigest,
            targetCanonVersion: candidate.manifest.targetCanonVersion,
            targetProductVersion: candidate.manifest.targetProductVersion,
            baseSnapshotContentDigest: candidate.manifest.baseSnapshotContentDigest,
            approval: approvalFingerprint(approval, includeTimestamp: true),
            activationTransformIdentity: candidate.transformDescriptor.identity,
            activationTransformDigest: candidate.transformDescriptor.digest,
            outputFiles: files,
            outputDirectories: directories,
            digestTransitions: transitions,
            baseCanonInventory: candidate.canonEvidence.fullInventory,
            baseCanonInventoryDigest: candidate.canonEvidence.fullInventoryDigest,
            basePluginInventory: candidate.basePluginEvidence.inventory,
            basePluginInventoryDigest: candidate.basePluginEvidence.inventoryDigest,
            candidateTreeCapture: CandidateCaptureFingerprint(
                candidate.candidateTreeCapture
            ),
            projectedPublishedCanonInventory: inventories.projectedCanon,
            publishedSnapshotContentDigest: publishedDigest,
            resolvedPluginInventory: inventories.resolvedPlugin,
            resolvedPluginInventoryDigest: pluginDigest,
            resolvedCanonSnapshot: SnapshotFingerprint(snapshot),
            resolvedActivationDigest: activationDigest
        )
    }

    static func expectedResolvedSnapshot(
        fixture: InstalledCandidateOverlayFixture,
        files: [ResolvedCandidateOutputFile],
        directories: [ResolvedCandidateOutputDirectory]
    ) throws -> CanonSnapshot {
        let root = fixture.workspace.appendingPathComponent(
            "independently-expected-resolved-canon"
        )
        try FileManager.default.copyItem(at: fixture.canonRoot, to: root)
        defer { try? FileManager.default.removeItem(at: root) }
        for directory in directories where directory.targetNamespace == .canon {
            let url = root.appendingPathComponent(directory.targetRelativePath)
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true
            )
            try CandidateOverlayFixture.setMode(Int(directory.mode), at: url)
        }
        for file in files where file.targetNamespace == .canon {
            let url = root.appendingPathComponent(file.targetRelativePath)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try file.bytes.write(to: url, options: .atomic)
            try CandidateOverlayFixture.setMode(Int(file.mode), at: url)
        }
        return try FileCanonRepository(root: root).snapshot(profiles: [])
    }

    static func inventoryDelta(
        before: CanonicalTreeInventory,
        after: CanonicalTreeInventory
    ) -> InventoryDelta {
        let beforeByPath = Dictionary(
            uniqueKeysWithValues: before.entries.map { ($0.relativePath, $0) }
        )
        let afterByPath = Dictionary(
            uniqueKeysWithValues: after.entries.map { ($0.relativePath, $0) }
        )
        let changedOrAdded = Set(afterByPath.compactMap { path, entry in
            beforeByPath[path] == entry ? nil : path
        })
        let deleted = Set(beforeByPath.keys.filter { afterByPath[$0] == nil })
        return InventoryDelta(changedOrAdded: changedOrAdded, deleted: deleted)
    }

    static func expectedResolvedActivationDigest(
        candidate: ValidatedCandidateOverlay,
        approval: CanonActivationApprovalInput,
        resolved: ResolvedCandidateActivation
    ) throws -> HashDigest {
        try expectedResolvedActivationDigest(
            candidate: candidate,
            approval: approval,
            outputFiles: resolved.outputFiles,
            outputDirectories: resolved.outputDirectories,
            digestTransitions: resolved.digestTransitions,
            projectedPublishedCanonInventory: resolved.projectedPublishedCanonInventory,
            publishedSnapshotContentDigest: resolved.publishedSnapshotContentDigest,
            resolvedPluginInventory: resolved.resolvedPluginInventory,
            resolvedPluginInventoryDigest: resolved.resolvedPluginInventoryDigest
        )
    }

    static func expectedResolvedActivationDigest(
        candidate: ValidatedCandidateOverlay,
        approval: CanonActivationApprovalInput,
        outputFiles: [ResolvedCandidateOutputFile],
        outputDirectories: [ResolvedCandidateOutputDirectory],
        digestTransitions: [ActivationDigestTransition],
        projectedPublishedCanonInventory: CanonicalTreeInventory,
        publishedSnapshotContentDigest: HashDigest,
        resolvedPluginInventory: CanonicalTreeInventory,
        resolvedPluginInventoryDigest: HashDigest
    ) throws -> HashDigest {
        let candidateFiles = candidate.candidateTreeCapture.filesByRelativePath.map {
            path, file in
            ExpectedCandidateFileDigestWire(
                relativePath: path,
                contentDigest: CanonicalTreeDigest.sha256(file.bytes),
                mode: file.mode
            )
        }.sorted { canonicalLess($0.relativePath, $1.relativePath) }
        let outputFileWires = outputFiles.map {
            ExpectedOutputFileDigestWire(
                targetNamespace: $0.targetNamespace,
                targetRelativePath: $0.targetRelativePath,
                contentDigest: CanonicalTreeDigest.sha256($0.bytes),
                mode: $0.mode,
                affectedComponents: $0.affectedComponents
            )
        }
        let outputDirectoryWires = outputDirectories.map {
            ExpectedOutputDirectoryDigestWire(
                targetNamespace: $0.targetNamespace,
                targetRelativePath: $0.targetRelativePath,
                mode: $0.mode,
                affectedComponents: $0.affectedComponents
            )
        }
        let payload = ExpectedResolvedActivationDigestPayload(
            schemaVersion: 1,
            activationTransformIdentity: candidate.transformDescriptor.identity,
            activationTransformDigest: candidate.transformDescriptor.digest,
            activationTransformSet: candidate.manifest.activationTransformSet,
            overlayID: candidate.overlayID.rawValue,
            overlayDigest: candidate.overlayDigest,
            targetCanonVersion: candidate.manifest.targetCanonVersion,
            targetProductVersion: candidate.manifest.targetProductVersion,
            baseSnapshotContentDigest: candidate.manifest.baseSnapshotContentDigest,
            baseCanonInventory: candidate.canonEvidence.fullInventory,
            baseCanonInventoryDigest: candidate.canonEvidence.fullInventoryDigest,
            basePluginInventory: candidate.basePluginEvidence.inventory,
            basePluginInventoryDigest: candidate.basePluginEvidence.inventoryDigest,
            candidateTreeInventory: candidate.candidateTreeCapture.inventory,
            candidateTreeCaptureDigest: candidate.candidateTreeCapture.captureDigest,
            candidateFiles: candidateFiles,
            approval: ExpectedApprovalDigestWire(
                integrationApproval: approval.integrationApproval,
                approvalTimestamp: approval.approvalTimestamp,
                approvalSourceArtifactID: approval.approvalSourceArtifactID,
                approvalSourceArtifactDigest: approval.approvalSourceArtifactDigest,
                approvalSidecarRelativePath: approval.approvalSidecarRelativePath,
                approvalSidecarBytesBase64: approval.approvalSidecarBytes.base64EncodedString(),
                approvalSidecarDigest: approval.approvalSidecarDigest
            ),
            outputFiles: outputFileWires,
            outputDirectories: outputDirectoryWires,
            digestTransitions: digestTransitions,
            projectedPublishedCanonInventory: projectedPublishedCanonInventory,
            publishedSnapshotContentDigest: publishedSnapshotContentDigest,
            resolvedPluginInventory: resolvedPluginInventory,
            resolvedPluginInventoryDigest: resolvedPluginInventoryDigest
        )
        var preimage = Data("ifl.candidate-overlay.resolved-activation/v1\0".utf8)
        try preimage.append(CanonicalJSON.encode(payload))
        return CanonicalTreeDigest.sha256(preimage)
    }

    static func removeActiveRuleOwnerBinding(
        from fixture: InstalledCandidateOverlayFixture
    ) throws {
        let manifestURL = fixture.candidateRoot.appendingPathComponent(
            "candidate-overlay.v1.json"
        )
        let bundleURL = fixture.candidateRoot.appendingPathComponent(
            "components/core-authority-v1.bundle.json"
        )
        let requirementsURL = candidateFile(requirementsTarget, in: fixture.candidateRoot)
        var manifest = try object(at: manifestURL)
        var bundle = try object(at: bundleURL)
        var registry = try object(at: requirementsURL)
        var traceability = try objects(registry["traceability"])
        let traceIndex = try #require(
            traceability.firstIndex { $0["requirement_id"] as? String == "REQ-CANON" }
        )
        traceability[traceIndex]["rule_bindings"] = []
        registry["traceability"] = traceability
        let registryData = try canonicalFileData(registry)
        _ = try CanonicalJSON.decode(RequirementRegistry.self, from: registryData)
        try write(registryData, to: requirementsURL)
        let registryDigest = CanonicalTreeDigest.sha256(registryData)
        let traceDigest = try CanonicalTreeDigest.sha256(
            canonicalValueData(traceability[traceIndex])
        )
        try updateArtifact("requirements", digest: registryDigest, in: &bundle)
        var requirementBinding = try object(manifest["requirement_registry"])
        requirementBinding["candidate_full_digest"] = registryDigest.rawValue
        var records = try objects(requirementBinding["records"])
        let recordIndex = try #require(
            records.firstIndex { $0["id"] as? String == "REQ-CANON" }
        )
        records[recordIndex]["candidate_traceability_record_digest"] = traceDigest.rawValue
        requirementBinding["records"] = records
        manifest["requirement_registry"] = requirementBinding
        try writeRebound(bundle: bundle, manifest: &manifest, fixture: fixture)
        try write(canonicalFileData(manifest), to: manifestURL)
        try normalizeCandidateModes(fixture.candidateRoot)
    }

    static func changedOutputKeys(
        _ lhs: ResolvedCandidateActivation,
        _ rhs: ResolvedCandidateActivation
    ) -> Set<String> {
        let left = Dictionary(uniqueKeysWithValues: lhs.outputFiles.map {
            ($0.targetKey, $0)
        })
        let right = Dictionary(uniqueKeysWithValues: rhs.outputFiles.map {
            ($0.targetKey, $0)
        })
        return changedKeys(left, right)
    }

    static func changedDirectoryKeys(
        _ lhs: ResolvedCandidateActivation,
        _ rhs: ResolvedCandidateActivation
    ) -> Set<String> {
        changedKeys(
            Dictionary(uniqueKeysWithValues: lhs.outputDirectories.map {
                ($0.targetKey, $0)
            }),
            Dictionary(uniqueKeysWithValues: rhs.outputDirectories.map {
                ($0.targetKey, $0)
            })
        )
    }

    static func changedTransitionKeys(
        _ lhs: ResolvedCandidateActivation,
        _ rhs: ResolvedCandidateActivation
    ) -> Set<String> {
        changedKeys(
            Dictionary(uniqueKeysWithValues: lhs.digestTransitions.map {
                ($0.targetKey, $0)
            }),
            Dictionary(uniqueKeysWithValues: rhs.digestTransitions.map {
                ($0.targetKey, $0)
            })
        )
    }

    static func unchangedOutputs(
        _ lhs: ResolvedCandidateActivation,
        _ rhs: ResolvedCandidateActivation,
        excluding keys: Set<String>
    ) -> Bool {
        Dictionary(uniqueKeysWithValues: lhs.outputFiles
            .filter { !keys.contains($0.targetKey) }
            .map { ($0.targetKey, $0) })
            == Dictionary(uniqueKeysWithValues: rhs.outputFiles
                .filter { !keys.contains($0.targetKey) }
                .map { ($0.targetKey, $0) })
    }

    static func unchangedTransitions(
        _ lhs: ResolvedCandidateActivation,
        _ rhs: ResolvedCandidateActivation,
        excluding keys: Set<String>
    ) -> Bool {
        Dictionary(uniqueKeysWithValues: lhs.digestTransitions
            .filter { !keys.contains($0.targetKey) }
            .map { ($0.targetKey, $0) })
            == Dictionary(uniqueKeysWithValues: rhs.digestTransitions
                .filter { !keys.contains($0.targetKey) }
                .map { ($0.targetKey, $0) })
    }

    static func changedInventoryPaths(
        _ lhs: CanonicalTreeInventory,
        _ rhs: CanonicalTreeInventory
    ) -> Set<String> {
        let left = Dictionary(uniqueKeysWithValues: lhs.entries.map {
            ($0.relativePath, $0)
        })
        let right = Dictionary(uniqueKeysWithValues: rhs.entries.map {
            ($0.relativePath, $0)
        })
        return changedKeys(left, right)
    }

    fileprivate static func candidateCaptureFingerprint(
        _ resolved: ResolvedCandidateActivation
    ) -> CandidateCaptureFingerprint {
        CandidateCaptureFingerprint(resolved.candidateTreeCapture)
    }

    fileprivate static func approvalFingerprint(
        _ approval: CanonActivationApprovalInput,
        includeTimestamp: Bool
    ) -> ApprovalFingerprint {
        ApprovalFingerprint(
            integrationApproval: approval.integrationApproval,
            approvalTimestamp: includeTimestamp ? approval.approvalTimestamp : nil,
            approvalSourceArtifactID: approval.approvalSourceArtifactID,
            approvalSourceArtifactDigest: approval.approvalSourceArtifactDigest,
            approvalSidecarRelativePath: approval.approvalSidecarRelativePath,
            approvalSidecarBytes: approval.approvalSidecarBytes,
            approvalSidecarDigest: approval.approvalSidecarDigest
        )
    }

    fileprivate static func snapshotSemanticFingerprint(
        _ snapshot: CanonSnapshot,
        excludingADRs: Bool
    ) throws -> SnapshotSemanticFingerprint {
        try SnapshotSemanticFingerprint(snapshot, excludingADRs: excludingADRs)
    }

    static func installCoherentReplacement(
        _ fixture: InstalledCandidateOverlayFixture,
        approvalSource: URL
    ) throws {
        let fileManager = FileManager.default
        try fileManager.removeItem(at: approvalSource)
        try withResolvableFixture(
            chapterMode: .executable
        ) { alternate in
            try replaceDirectoryContents(
                at: fixture.canonRoot,
                with: alternate.canonRoot,
                fileManager: fileManager
            )
            try replaceDirectoryContents(
                at: fixture.candidateRoot,
                with: alternate.candidateRoot,
                fileManager: fileManager
            )
        }
        let alternateApproval = Data(
            "{\"approval\":\"coherent-alternate-evidence\",\"schema_version\":1}\n".utf8
        )
        try alternateApproval.write(to: approvalSource, options: .atomic)
        _ = try FileCanonRepository(root: fixture.canonRoot).snapshot(profiles: [])
        let alternateBase = try FileCanonRepository(anchor: fixture.anchor.canonRootAnchor())
            .snapshot(profiles: [])
        _ = try CandidateOverlayValidator(anchor: fixture.anchor).validate(
            overlayID: fixture.overlayID,
            base: alternateBase
        )
    }

    private static func replaceDirectoryContents(
        at destination: URL,
        with source: URL,
        fileManager: FileManager
    ) throws {
        for item in try fileManager.contentsOfDirectory(
            at: destination,
            includingPropertiesForKeys: nil
        ) {
            try fileManager.removeItem(at: item)
        }
        for item in try fileManager.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: nil
        ) {
            try fileManager.copyItem(
                at: item,
                to: destination.appendingPathComponent(item.lastPathComponent)
            )
        }
        let attributes = try fileManager.attributesOfItem(atPath: source.path)
        let mode = try #require(attributes[.posixPermissions] as? NSNumber)
        try CandidateOverlayFixture.setMode(mode.intValue, at: destination)
    }

    private static func changedKeys<Value: Equatable>(
        _ lhs: [String: Value],
        _ rhs: [String: Value]
    ) -> Set<String> {
        Set(lhs.keys).union(rhs.keys).filter { lhs[$0] != rhs[$0] }
    }

    static func string(_ value: Any?) -> String {
        value as? String ?? ""
    }

    static func canonicalLess(_ lhs: String, _ rhs: String) -> Bool {
        lhs.utf8.lexicographicallyPrecedes(rhs.utf8)
    }
}

private func expectTypedResolverFailure(operation: () throws -> Void) {
    do {
        try operation()
        Issue.record("Expected typed candidate resolution failure")
    } catch is ContractError {
        return
    } catch is CanonDescriptorFailure {
        return
    } catch {
        Issue.record("Unexpected untyped candidate resolution error: \(error)")
    }
}

private func expectResolverFailure(
    _ expected: ContractError,
    operation: () throws -> Void
) {
    do {
        try operation()
        Issue.record("Expected resolver failure: \(expected)")
    } catch let actual as ContractError {
        #expect(actual.description == expected.description)
    } catch {
        Issue.record("Unexpected untyped candidate resolution error: \(error)")
    }
}

private extension ActivationDigestTransition {
    var targetKey: String {
        targetNamespace.rawValue + "\0" + targetRelativePath
    }

    var normalizedPluginKey: String {
        targetNamespace == .canon
            ? "standards/canon/" + targetRelativePath
            : targetRelativePath
    }
}

private struct CandidateFileFingerprint: Equatable {
    let relativePath: String
    let bytes: Data
    let mode: UInt16
    let contentDigest: HashDigest
}

private struct CandidateCaptureFingerprint: Equatable {
    let inventory: CanonicalTreeInventory
    let captureDigest: HashDigest
    let files: [CandidateFileFingerprint]

    init(_ capture: CandidateTreeCapture) {
        inventory = capture.inventory
        captureDigest = capture.captureDigest
        files = capture.filesByRelativePath.map { path, file in
            CandidateFileFingerprint(
                relativePath: path,
                bytes: file.bytes,
                mode: file.mode,
                contentDigest: file.contentDigest
            )
        }.sorted {
            ResolverCandidateFixture.canonicalLess($0.relativePath, $1.relativePath)
        }
    }
}

private struct ApprovalFingerprint: Equatable {
    let integrationApproval: ReviewApprovalReference
    let approvalTimestamp: Date?
    let approvalSourceArtifactID: String
    let approvalSourceArtifactDigest: HashDigest
    let approvalSidecarRelativePath: String
    let approvalSidecarBytes: Data
    let approvalSidecarDigest: HashDigest
}

private struct SnapshotSemanticFingerprint: Equatable {
    let canonVersion: Int
    let rules: Data
    let profiles: Data
    let selectedProfileIDs: Data
    let adrs: Data
    let adrMarkdown: Data
    let chapters: Data
    let requirementRegistry: Data
    let derivedArtifacts: Data

    init(_ snapshot: CanonSnapshot, excludingADRs: Bool) throws {
        canonVersion = snapshot.canonVersion
        rules = try CanonicalJSON.encode(snapshot.rules)
        profiles = try CanonicalJSON.encode(snapshot.profiles)
        selectedProfileIDs = try CanonicalJSON.encode(snapshot.selectedProfileIDs)
        adrs = excludingADRs ? Data() : try CanonicalJSON.encode(snapshot.adrs)
        let markdown = snapshot.adrMarkdownByID.map { id, value in
            SnapshotADRMarkdownWire(id: id, markdown: value)
        }.sorted {
            ResolverCandidateFixture.canonicalLess($0.id.rawValue, $1.id.rawValue)
        }
        adrMarkdown = excludingADRs ? Data() : try CanonicalJSON.encode(markdown)
        chapters = try CanonicalJSON.encode(snapshot.chapters)
        requirementRegistry = try CanonicalJSON.encode(snapshot.requirementRegistry)
        derivedArtifacts = try CanonicalJSON.encode(snapshot.derivedArtifacts)
    }
}

private struct SnapshotFingerprint: Equatable {
    let semantic: SnapshotSemanticFingerprint
    let snapshotContentDigest: HashDigest

    init(_ snapshot: CanonSnapshot) throws {
        semantic = try SnapshotSemanticFingerprint(snapshot, excludingADRs: false)
        snapshotContentDigest = snapshot.snapshotContentDigest
    }
}

private struct SnapshotADRMarkdownWire: Encodable {
    let id: ADRIdentifier
    let markdown: String

    private enum CodingKeys: String, CodingKey {
        case id
        case markdown
    }
}

private struct ResolutionFingerprint: Equatable {
    let overlayID: String
    let overlayDigest: HashDigest
    let targetCanonVersion: Int
    let targetProductVersion: String
    let baseSnapshotContentDigest: HashDigest
    let approval: ApprovalFingerprint
    let activationTransformIdentity: String
    let activationTransformDigest: HashDigest
    let outputFiles: [ResolvedCandidateOutputFile]
    let outputDirectories: [ResolvedCandidateOutputDirectory]
    let digestTransitions: [ActivationDigestTransition]
    let baseCanonInventory: CanonicalTreeInventory
    let baseCanonInventoryDigest: HashDigest
    let basePluginInventory: CanonicalTreeInventory
    let basePluginInventoryDigest: HashDigest
    let candidateTreeCapture: CandidateCaptureFingerprint
    let projectedPublishedCanonInventory: CanonicalTreeInventory
    let publishedSnapshotContentDigest: HashDigest
    let resolvedPluginInventory: CanonicalTreeInventory
    let resolvedPluginInventoryDigest: HashDigest
    let resolvedCanonSnapshot: SnapshotFingerprint
    let resolvedActivationDigest: HashDigest

    init(
        overlayID: String,
        overlayDigest: HashDigest,
        targetCanonVersion: Int,
        targetProductVersion: String,
        baseSnapshotContentDigest: HashDigest,
        approval: ApprovalFingerprint,
        activationTransformIdentity: String,
        activationTransformDigest: HashDigest,
        outputFiles: [ResolvedCandidateOutputFile],
        outputDirectories: [ResolvedCandidateOutputDirectory],
        digestTransitions: [ActivationDigestTransition],
        baseCanonInventory: CanonicalTreeInventory,
        baseCanonInventoryDigest: HashDigest,
        basePluginInventory: CanonicalTreeInventory,
        basePluginInventoryDigest: HashDigest,
        candidateTreeCapture: CandidateCaptureFingerprint,
        projectedPublishedCanonInventory: CanonicalTreeInventory,
        publishedSnapshotContentDigest: HashDigest,
        resolvedPluginInventory: CanonicalTreeInventory,
        resolvedPluginInventoryDigest: HashDigest,
        resolvedCanonSnapshot: SnapshotFingerprint,
        resolvedActivationDigest: HashDigest
    ) {
        self.overlayID = overlayID
        self.overlayDigest = overlayDigest
        self.targetCanonVersion = targetCanonVersion
        self.targetProductVersion = targetProductVersion
        self.baseSnapshotContentDigest = baseSnapshotContentDigest
        self.approval = approval
        self.activationTransformIdentity = activationTransformIdentity
        self.activationTransformDigest = activationTransformDigest
        self.outputFiles = outputFiles
        self.outputDirectories = outputDirectories
        self.digestTransitions = digestTransitions
        self.baseCanonInventory = baseCanonInventory
        self.baseCanonInventoryDigest = baseCanonInventoryDigest
        self.basePluginInventory = basePluginInventory
        self.basePluginInventoryDigest = basePluginInventoryDigest
        self.candidateTreeCapture = candidateTreeCapture
        self.projectedPublishedCanonInventory = projectedPublishedCanonInventory
        self.publishedSnapshotContentDigest = publishedSnapshotContentDigest
        self.resolvedPluginInventory = resolvedPluginInventory
        self.resolvedPluginInventoryDigest = resolvedPluginInventoryDigest
        self.resolvedCanonSnapshot = resolvedCanonSnapshot
        self.resolvedActivationDigest = resolvedActivationDigest
    }

    init(_ resolved: ResolvedCandidateActivation) throws {
        overlayID = resolved.overlayID
        overlayDigest = resolved.overlayDigest
        targetCanonVersion = resolved.targetCanonVersion
        targetProductVersion = resolved.targetProductVersion
        baseSnapshotContentDigest = resolved.baseSnapshotContentDigest
        approval = ResolverCandidateFixture.approvalFingerprint(
            resolved.approvalInput,
            includeTimestamp: true
        )
        activationTransformIdentity = resolved.activationTransformIdentity
        activationTransformDigest = resolved.activationTransformDigest
        outputFiles = resolved.outputFiles
        outputDirectories = resolved.outputDirectories
        digestTransitions = resolved.digestTransitions
        baseCanonInventory = resolved.baseCanonInventory
        baseCanonInventoryDigest = resolved.baseCanonInventoryDigest
        basePluginInventory = resolved.basePluginInventory
        basePluginInventoryDigest = resolved.basePluginInventoryDigest
        candidateTreeCapture = CandidateCaptureFingerprint(resolved.candidateTreeCapture)
        projectedPublishedCanonInventory = resolved.projectedPublishedCanonInventory
        publishedSnapshotContentDigest = resolved.publishedSnapshotContentDigest
        resolvedPluginInventory = resolved.resolvedPluginInventory
        resolvedPluginInventoryDigest = resolved.resolvedPluginInventoryDigest
        resolvedCanonSnapshot = try SnapshotFingerprint(resolved.resolvedCanonSnapshot)
        resolvedActivationDigest = resolved.resolvedActivationDigest
    }
}

private final class ConcurrentResolutionStore: @unchecked Sendable {
    private let lock = NSLock()
    private var storedResults: [ResolutionFingerprint] = []
    private var storedErrors: [String] = []

    var results: [ResolutionFingerprint] {
        lock.withLock { storedResults }
    }

    var errors: [String] {
        lock.withLock { storedErrors }
    }

    func append(_ result: ResolutionFingerprint) {
        lock.withLock { storedResults.append(result) }
    }

    func record(_ error: any Error) {
        lock.withLock { storedErrors.append(String(describing: error)) }
    }
}

private struct ExpectedCandidateFileDigestWire: Encodable {
    let relativePath: String
    let contentDigest: HashDigest
    let mode: UInt16

    private enum CodingKeys: String, CodingKey {
        case relativePath = "relative_path"
        case contentDigest = "content_digest"
        case mode
    }
}

private struct ExpectedApprovalDigestWire: Encodable {
    let integrationApproval: ReviewApprovalReference
    let approvalTimestamp: Date
    let approvalSourceArtifactID: String
    let approvalSourceArtifactDigest: HashDigest
    let approvalSidecarRelativePath: String
    let approvalSidecarBytesBase64: String
    let approvalSidecarDigest: HashDigest

    private enum CodingKeys: String, CodingKey {
        case integrationApproval = "integration_approval"
        case approvalTimestamp = "approval_timestamp"
        case approvalSourceArtifactID = "approval_source_artifact_id"
        case approvalSourceArtifactDigest = "approval_source_artifact_digest"
        case approvalSidecarRelativePath = "approval_sidecar_relative_path"
        case approvalSidecarBytesBase64 = "approval_sidecar_bytes_base64"
        case approvalSidecarDigest = "approval_sidecar_digest"
    }
}

private struct ExpectedOutputFileDigestWire: Encodable {
    let targetNamespace: CandidateTargetNamespace
    let targetRelativePath: String
    let contentDigest: HashDigest
    let mode: UInt16
    let affectedComponents: [ActivationAffectedComponentReference]

    private enum CodingKeys: String, CodingKey {
        case targetNamespace = "target_namespace"
        case targetRelativePath = "target_relative_path"
        case contentDigest = "content_digest"
        case mode
        case affectedComponents = "affected_components"
    }
}

private struct ExpectedOutputDirectoryDigestWire: Encodable {
    let targetNamespace: CandidateTargetNamespace
    let targetRelativePath: String
    let mode: UInt16
    let affectedComponents: [ActivationAffectedComponentReference]

    private enum CodingKeys: String, CodingKey {
        case targetNamespace = "target_namespace"
        case targetRelativePath = "target_relative_path"
        case mode
        case affectedComponents = "affected_components"
    }
}

private struct ExpectedResolvedActivationDigestPayload: Encodable {
    let schemaVersion: Int
    let activationTransformIdentity: String
    let activationTransformDigest: HashDigest
    let activationTransformSet: ActivationTransformSet
    let overlayID: String
    let overlayDigest: HashDigest
    let targetCanonVersion: Int
    let targetProductVersion: String
    let baseSnapshotContentDigest: HashDigest
    let baseCanonInventory: CanonicalTreeInventory
    let baseCanonInventoryDigest: HashDigest
    let basePluginInventory: CanonicalTreeInventory
    let basePluginInventoryDigest: HashDigest
    let candidateTreeInventory: CanonicalTreeInventory
    let candidateTreeCaptureDigest: HashDigest
    let candidateFiles: [ExpectedCandidateFileDigestWire]
    let approval: ExpectedApprovalDigestWire
    let outputFiles: [ExpectedOutputFileDigestWire]
    let outputDirectories: [ExpectedOutputDirectoryDigestWire]
    let digestTransitions: [ActivationDigestTransition]
    let projectedPublishedCanonInventory: CanonicalTreeInventory
    let publishedSnapshotContentDigest: HashDigest
    let resolvedPluginInventory: CanonicalTreeInventory
    let resolvedPluginInventoryDigest: HashDigest

    private enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case activationTransformIdentity = "activation_transform_identity"
        case activationTransformDigest = "activation_transform_digest"
        case activationTransformSet = "activation_transform_set"
        case overlayID = "overlay_id"
        case overlayDigest = "overlay_digest"
        case targetCanonVersion = "target_canon_version"
        case targetProductVersion = "target_product_version"
        case baseSnapshotContentDigest = "base_snapshot_content_digest"
        case baseCanonInventory = "base_canon_inventory"
        case baseCanonInventoryDigest = "base_canon_inventory_digest"
        case basePluginInventory = "base_plugin_inventory"
        case basePluginInventoryDigest = "base_plugin_inventory_digest"
        case candidateTreeInventory = "candidate_tree_inventory"
        case candidateTreeCaptureDigest = "candidate_tree_capture_digest"
        case candidateFiles = "candidate_files"
        case approval
        case outputFiles = "output_files"
        case outputDirectories = "output_directories"
        case digestTransitions = "digest_transitions"
        case projectedPublishedCanonInventory = "projected_published_canon_inventory"
        case publishedSnapshotContentDigest = "published_snapshot_content_digest"
        case resolvedPluginInventory = "resolved_plugin_inventory"
        case resolvedPluginInventoryDigest = "resolved_plugin_inventory_digest"
    }
}
