import Foundation
import IFLContracts

package enum CandidateOverlayValidationEvent: Equatable {
    case didCaptureInitialPluginEvidence
    case didCaptureCandidateFile(String)
    case willRescanPlugin
}

package typealias CandidateOverlayValidationEventHandler = @Sendable (
    CandidateOverlayValidationEvent
) throws -> Void

package enum CandidateOverlayAuthority {
    package static func allows(
        componentFamily: CandidatePublicationComponentFamily,
        artifactKind: DerivedArtifactKind,
        targetPath: PluginDerivedTargetPath,
        publicationKind: CandidatePublicationKind,
        mode: CandidatePortableMode
    ) -> Bool {
        CandidatePublicationAuthorityMap.v1.allows(
            componentFamily: componentFamily,
            artifactKind: artifactKind,
            targetPath: targetPath,
            publicationKind: publicationKind,
            mode: mode
        )
    }
}

package struct CandidateOverlayValidator {
    private let anchor: RetainedPluginRootAnchor
    private let eventHandler: CandidateOverlayValidationEventHandler

    package init(anchor: RetainedPluginRootAnchor) {
        self.anchor = anchor
        eventHandler = { _ in }
    }

    package init(
        anchor: RetainedPluginRootAnchor,
        eventHandler: @escaping CandidateOverlayValidationEventHandler
    ) {
        self.anchor = anchor
        self.eventHandler = eventHandler
    }

    package func validate(
        overlayID: CandidateOverlayID,
        base: CanonSnapshot
    ) throws -> ValidatedCandidateOverlay {
        let canonEvidence = try requireCanonEvidence(base)
        let initialPluginEvidence = try anchor.captureBaseEvidence()
        try eventHandler(.didCaptureInitialPluginEvidence)
        try validateCanonEvidence(canonEvidence, base: base)

        let candidateAnchor = try anchor.candidateRootAnchor(overlayID: overlayID)
        let capture = try CandidateTreeCapture.capture(
            anchor: candidateAnchor,
            eventHandler: eventHandler
        )
        try validateStorageModes(capture)
        try validateRetainedObjectBindings(
            initialPluginEvidence: initialPluginEvidence,
            canonEvidence: canonEvidence,
            candidateCapture: capture,
            overlayID: overlayID
        )

        guard let manifestFile = capture.filesByRelativePath["candidate-overlay.v1.json"] else {
            throw ContractError.unresolvedReference(
                kind: "canon file",
                id: "candidate-overlay.v1.json"
            )
        }
        let overlayDigest = try CandidateOverlayManifest.overlayDigest(
            forCanonicalFileData: manifestFile.bytes
        )
        let manifest = try CanonicalJSON.decode(
            CandidateOverlayManifest.self,
            from: manifestFile.bytes
        )
        guard manifest.overlayID == overlayID.rawValue else {
            throw invalid("manifest overlay_id does not equal the retained candidate directory")
        }
        guard manifest.targetCanonVersion == base.canonVersion else {
            throw ContractError.invalidCanonVersion(String(manifest.targetCanonVersion))
        }
        guard manifest.baseSnapshotContentDigest == base.snapshotContentDigest else {
            throw ContractError.digestMismatch(
                kind: "candidate overlay base snapshot",
                expected: base.snapshotContentDigest.rawValue,
                actual: manifest.baseSnapshotContentDigest.rawValue
            )
        }

        let bundles = try decodeAndJoinBundles(manifest: manifest, capture: capture)
        try validatePhysicalClosure(capture: capture, manifest: manifest, bundles: bundles)
        let claims = try manifestClaims(manifest)
        try validateBundleBijection(
            claims: claims,
            bundles: bundles,
            capture: capture
        )
        try validateSemanticClosure(
            manifest: manifest,
            claims: claims,
            bundles: bundles,
            capture: capture,
            base: base
        )
        try validateTargetPreconditions(
            manifest: manifest,
            bundles: bundles,
            basePluginInventory: initialPluginEvidence.inventory,
            canonInventory: canonEvidence.fullInventory,
            capture: capture
        )

        let projectedCanon = try subtreeInventory(
            of: initialPluginEvidence.inventory,
            at: "standards/canon"
        )
        guard projectedCanon == canonEvidence.fullInventory else {
            throw invalid("retained plugin Canon projection differs from the anchored snapshot")
        }
        let projectedCandidate = try subtreeInventory(
            of: initialPluginEvidence.inventory,
            at: "standards/canon-candidates/\(overlayID.rawValue)"
        )
        guard projectedCandidate == capture.inventory else {
            throw invalid("retained plugin candidate projection differs from exact capture")
        }

        try eventHandler(.willRescanPlugin)
        let finalPluginEvidence = try anchor.captureBaseEvidence()
        guard finalPluginEvidence.inventory == initialPluginEvidence.inventory,
              finalPluginEvidence.inventoryDigest == initialPluginEvidence.inventoryDigest
        else {
            throw ContractError.digestMismatch(
                kind: "candidate overlay full plugin rescan",
                expected: initialPluginEvidence.inventoryDigest.rawValue,
                actual: finalPluginEvidence.inventoryDigest.rawValue
            )
        }
        guard finalPluginEvidence.snapshotsByRelativePath
            == initialPluginEvidence.snapshotsByRelativePath
        else {
            let changedPath = firstChangedObjectPath(
                before: initialPluginEvidence.snapshotsByRelativePath,
                after: finalPluginEvidence.snapshotsByRelativePath
            )
            throw CanonDescriptorFailure.integrityViolation(
                "retained plugin object metadata changed at \(changedPath)"
            )
        }

        return ValidatedCandidateOverlay(
            overlayID: overlayID,
            overlayDigest: overlayDigest,
            manifest: manifest,
            componentBundles: bundles,
            candidateTreeCapture: capture,
            basePluginEvidence: initialPluginEvidence,
            canonEvidence: canonEvidence,
            transformDescriptor: .v1
        )
    }

    private func requireCanonEvidence(_ base: CanonSnapshot) throws -> CanonSnapshotEvidence {
        guard let evidence = base.candidateOverlayEvidence,
              anchor.owns(evidence)
        else {
            throw invalid(
                "candidate validation requires Canon evidence from the same retained plugin authority"
            )
        }
        return evidence
    }

    private func validateCanonEvidence(
        _ evidence: CanonSnapshotEvidence,
        base: CanonSnapshot
    ) throws {
        let fullDigest = try CanonicalTreeDigest.digest(evidence.fullInventory)
        let projected = try CanonSnapshotContentPolicy.project(evidence.fullInventory)
        let projectedDigest = try CanonicalTreeDigest.digest(projected)
        guard fullDigest == evidence.fullInventoryDigest,
              projected == evidence.projectedInventory,
              projectedDigest == evidence.projectedDigest,
              projectedDigest == base.snapshotContentDigest
        else {
            throw invalid("Canon snapshot evidence is incomplete or internally inconsistent")
        }
        let inventoryFiles = Set(
            evidence.fullInventory.entries.lazy
                .filter { $0.kind == .regularFile }
                .map(\.relativePath)
        )
        guard Set(evidence.fileBytesByRelativePath.keys).isSubset(of: inventoryFiles) else {
            throw invalid("Canon typed file evidence is outside the full inventory")
        }
        let inventoryPaths = Set(evidence.fullInventory.entries.map(\.relativePath)).union([""])
        guard Set(evidence.snapshotsByRelativePath.keys) == inventoryPaths,
              evidence.snapshotsByRelativePath[""]?.device == evidence.canonDevice,
              evidence.snapshotsByRelativePath[""]?.inode == evidence.canonInode
        else {
            throw invalid("Canon snapshot object identities are incomplete")
        }
        for (path, bytes) in evidence.fileBytesByRelativePath {
            guard evidence.fullInventory.entries.first(where: {
                $0.relativePath == path
            })?.contentSHA256 == CanonicalTreeDigest.sha256(bytes) else {
                throw invalid("Canon typed file evidence digest differs at \(path)")
            }
        }
    }

    private func validateRetainedObjectBindings(
        initialPluginEvidence: BasePluginSnapshotEvidence,
        canonEvidence: CanonSnapshotEvidence,
        candidateCapture: CandidateTreeCapture,
        overlayID: CandidateOverlayID
    ) throws {
        let canonSnapshots = try subtreeSnapshots(
            initialPluginEvidence.snapshotsByRelativePath,
            at: "standards/canon"
        )
        guard canonSnapshots == canonEvidence.snapshotsByRelativePath else {
            let changedPath = firstChangedObjectPath(
                before: canonEvidence.snapshotsByRelativePath,
                after: canonSnapshots
            )
            throw CanonDescriptorFailure.integrityViolation(
                "retained Canon object metadata changed at \(changedPath)"
            )
        }
        let candidateSnapshots = try subtreeSnapshots(
            initialPluginEvidence.snapshotsByRelativePath,
            at: "standards/canon-candidates/\(overlayID.rawValue)"
        )
        guard candidateSnapshots == candidateCapture.snapshotsByRelativePath else {
            let changedPath = firstChangedObjectPath(
                before: candidateCapture.snapshotsByRelativePath,
                after: candidateSnapshots
            )
            throw CanonDescriptorFailure.integrityViolation(
                "retained candidate object metadata changed at \(changedPath)"
            )
        }
    }

    private func validateStorageModes(_ capture: CandidateTreeCapture) throws {
        guard capture.inventory.rootMode == CandidatePortableMode.executable.rawValue else {
            throw invalid("candidate root storage mode must be 0755")
        }
        for entry in capture.inventory.entries {
            let expected = entry.kind == .directory
                ? CandidatePortableMode.executable.rawValue
                : CandidatePortableMode.file.rawValue
            guard entry.mode == expected else {
                throw invalid("candidate storage mode is invalid at \(entry.relativePath)")
            }
        }
    }

    private func decodeAndJoinBundles(
        manifest: CandidateOverlayManifest,
        capture: CandidateTreeCapture
    ) throws -> [String: CandidateComponentBundle] {
        var bundles: [String: CandidateComponentBundle] = [:]
        for reviewed in manifest.reviewedComponents {
            let file = try requireAcceptedFile(reviewed.bundleRelativePath, in: capture)
            guard file.mode == CandidatePortableMode.file.rawValue else {
                throw invalid("component bundle storage mode must be 0644")
            }
            let bundle = try reviewed.bundleSchemaIdentity.decodeBundle(from: file.bytes)
            let componentDigest = try reviewed.bundleSchemaIdentity.componentDigest(
                for: file.bytes
            )
            guard componentDigest == reviewed.componentDigest else {
                throw ContractError.digestMismatch(
                    kind: "reviewed candidate component",
                    expected: reviewed.componentDigest.rawValue,
                    actual: componentDigest.rawValue
                )
            }
            guard bundle.componentID == reviewed.componentID,
                  bundle.componentKind == reviewed.componentKind,
                  bundle.accountableOwnerRoleID == reviewed.accountableOwnerRoleID,
                  bundle.bundleRelativePath == reviewed.bundleRelativePath,
                  bundle.schemaIdentity == reviewed.bundleSchemaIdentity,
                  bundle.schemaDigest == reviewed.bundleSchemaDigest
            else {
                throw invalid("reviewed component does not exactly join its captured bundle")
            }
            guard bundles.updateValue(bundle, forKey: bundle.componentID) == nil else {
                throw ContractError.duplicateIdentifier(
                    kind: "candidate component bundle",
                    id: bundle.componentID
                )
            }
        }
        return bundles
    }

    private func validatePhysicalClosure(
        capture: CandidateTreeCapture,
        manifest: CandidateOverlayManifest,
        bundles: [String: CandidateComponentBundle]
    ) throws {
        var artifactOwnerBySourcePath: [String: String] = [:]
        for bundle in bundles.values.sorted(by: {
            $0.componentID.utf8.lexicographicallyPrecedes($1.componentID.utf8)
        }) {
            for artifact in bundle.artifacts {
                if artifactOwnerBySourcePath.updateValue(
                    bundle.componentID,
                    forKey: artifact.candidateRelativePath
                ) != nil {
                    throw invalid(
                        "candidate source path is claimed by multiple components: "
                            + artifact.candidateRelativePath
                    )
                }
            }
        }

        var expectedFiles: Set = ["candidate-overlay.v1.json"]
        for reviewed in manifest.reviewedComponents {
            expectedFiles.insert(reviewed.bundleRelativePath)
        }
        for bundle in bundles.values {
            for artifact in bundle.artifacts {
                expectedFiles.insert(artifact.candidateRelativePath)
            }
        }

        var expectedDirectories: Set<String> = []
        for file in expectedFiles {
            let components = file.split(separator: "/").map(String.init)
            guard components.count >= 1 else { throw invalid("empty candidate path") }
            for end in 1 ..< components.count {
                expectedDirectories.insert(components[..<end].joined(separator: "/"))
            }
        }

        let actualFiles = Set(
            capture.inventory.entries.lazy
                .filter { $0.kind == .regularFile }
                .map(\.relativePath)
        )
        let actualDirectories = Set(
            capture.inventory.entries.lazy
                .filter { $0.kind == .directory }
                .map(\.relativePath)
        )
        let missingFiles = expectedFiles.subtracting(actualFiles).sorted {
            $0.utf8.lexicographicallyPrecedes($1.utf8)
        }
        if let missingFile = missingFiles.first {
            throw CanonDescriptorFailure.integrityViolation(
                "accepted candidate source is missing: \(missingFile)"
            )
        }
        guard actualFiles == expectedFiles,
              actualDirectories == expectedDirectories
        else {
            throw invalid("candidate physical tree is not the exact manifest/bundle/payload closure")
        }
    }

    private func validateBundleBijection(
        claims: [ArtifactClaim],
        bundles: [String: CandidateComponentBundle],
        capture: CandidateTreeCapture
    ) throws {
        let claimsByKey = Dictionary(
            uniqueKeysWithValues: claims.map { ($0.key, $0) }
        )
        var observedArtifacts: Set<ArtifactClaimKey> = []
        var observedPublications: Set<PublicationClaimKey> = []

        for bundle in bundles.values {
            for artifact in bundle.artifacts {
                let key = ArtifactClaimKey(
                    componentID: bundle.componentID,
                    artifactID: artifact.artifactID
                )
                guard let claim = claimsByKey[key] else {
                    throw ContractError.unresolvedReference(
                        kind: "manifest bundle artifact",
                        id: bundle.componentID + ":" + artifact.artifactID
                    )
                }
                guard artifact.family == claim.family,
                      artifact.logicalID == claim.logicalID,
                      artifact.candidateFileDigest == claim.digest
                else {
                    throw invalid("bundle artifact does not equal its manifest claim")
                }
                let file = try requireFile(artifact.candidateRelativePath, in: capture)
                guard file.contentDigest == artifact.candidateFileDigest else {
                    throw ContractError.digestMismatch(
                        kind: "candidate artifact",
                        expected: artifact.candidateFileDigest.rawValue,
                        actual: file.contentDigest.rawValue
                    )
                }
                observedArtifacts.insert(key)
            }

            for publication in bundle.publications {
                let key = PublicationClaimKey(
                    componentID: bundle.componentID,
                    publicationID: publication.publicationID
                )
                let matching = claims.compactMap { claim -> PublicationClaim? in
                    guard claim.key.componentID == bundle.componentID,
                          claim.publication?.publicationID == publication.publicationID
                    else { return nil }
                    return claim.publication
                }
                guard matching.count == 1, let claim = matching.first,
                      claim.artifactID == publication.artifactID,
                      claim.namespace == publication.targetNamespace,
                      claim.targetPath == publication.targetRelativePath
                else {
                    throw invalid("bundle publication does not equal one manifest output claim")
                }
                observedPublications.insert(key)
            }
        }

        let expectedArtifacts = Set(claims.map(\.key))
        let expectedPublications = Set(claims.compactMap { claim in
            claim.publication.map {
                PublicationClaimKey(
                    componentID: claim.key.componentID,
                    publicationID: $0.publicationID
                )
            }
        })
        guard observedArtifacts == expectedArtifacts,
              observedPublications == expectedPublications
        else {
            throw invalid("manifest, bundle, and physical claims are not bijective")
        }
    }

    private func validateSemanticClosure(
        manifest: CandidateOverlayManifest,
        claims: [ArtifactClaim],
        bundles: [String: CandidateComponentBundle],
        capture: CandidateTreeCapture,
        base: CanonSnapshot
    ) throws {
        for binding in manifest.rules {
            let file = try file(for: binding.reviewedComponentID, artifactID: binding.bundleArtifactID, bundles: bundles, capture: capture)
            let rule = try decodeCanonicalFile(RuleRecord.self, file: file, kind: "candidate rule")
            guard rule.id == binding.id,
                  rule.lifecycle == .proposed,
                  rule.effectiveIn == manifest.targetProductVersion,
                  try RuleSemanticDigest.digest(rule) == binding.semanticDigest
            else {
                throw invalid("candidate Rule prestate or semantic digest is invalid")
            }
        }

        for binding in manifest.profiles {
            let file = try file(for: binding.reviewedComponentID, artifactID: binding.bundleArtifactID, bundles: bundles, capture: capture)
            let profile = try decodeCanonicalFile(ProfileRecord.self, file: file, kind: "candidate profile")
            guard profile.id == binding.id,
                  profile.ruleIDs == binding.orderedRuleIDs
            else {
                throw invalid("candidate Profile binding does not match its typed payload")
            }
        }

        for binding in manifest.adrs {
            let metadataFile = try file(for: binding.reviewedComponentID, artifactID: binding.metadataBundleArtifactID, bundles: bundles, capture: capture)
            let markdownFile = try file(for: binding.reviewedComponentID, artifactID: binding.markdownBundleArtifactID, bundles: bundles, capture: capture)
            let metadata = try decodeCanonicalFile(ADRMetadata.self, file: metadataFile, kind: "candidate ADR metadata")
            guard let markdown = String(data: markdownFile.bytes, encoding: .utf8),
                  metadata.id == binding.id,
                  metadata.status == .inReview,
                  metadata.acceptedAt == nil,
                  try ADRSemanticDigest.digest(metadata: metadata, markdown: markdown)
                  == binding.semanticDigest
            else {
                throw invalid("candidate ADR prestate or semantic digest is invalid")
            }
        }

        for binding in manifest.chapters {
            let file = try file(for: binding.reviewedComponentID, artifactID: binding.bundleArtifactID, bundles: bundles, capture: capture)
            let chapter = try decodeCanonicalFile(ChapterMetadata.self, file: file, kind: "candidate chapter")
            guard chapter.id == binding.id else {
                throw invalid("candidate Chapter ID does not match its binding")
            }
        }

        let requirementFile = try file(
            for: manifest.requirementRegistry.reviewedComponentID,
            artifactID: manifest.requirementRegistry.bundleArtifactID,
            bundles: bundles,
            capture: capture
        )
        let registry = try decodeCanonicalFile(
            RequirementRegistry.self,
            file: requirementFile,
            kind: "candidate requirement registry"
        )
        try validateRequirementClosure(
            binding: manifest.requirementRegistry,
            candidate: registry,
            base: base.requirementRegistry
        )

        for binding in manifest.indexes {
            let file = try file(for: binding.reviewedComponentID, artifactID: binding.bundleArtifactID, bundles: bundles, capture: capture)
            try validateIndexClosure(
                binding: binding,
                file: file,
                baseEvidence: requireCanonEvidence(base),
                manifest: manifest,
                bundles: bundles,
                capture: capture
            )
        }

        for binding in manifest.derivedRegistrationDeltas {
            let file = try file(for: binding.reviewedComponentID, artifactID: binding.bundleArtifactID, bundles: bundles, capture: capture)
            let delta = try decodeCanonicalFile(
                DerivedRegistrationDelta.self,
                file: file,
                kind: "candidate derived delta"
            )
            guard delta.deltaID == binding.deltaID,
                  delta.baseSnapshotContentDigest == base.snapshotContentDigest,
                  Set(delta.entries.map(\.indexKey)) == Set(binding.targets.map(\.indexKey))
            else {
                throw invalid("candidate derived delta is not closed over its manifest targets")
            }
            for target in binding.targets {
                guard let entry = delta.entries.first(where: { $0.indexKey == target.indexKey }),
                      entry.targetPath == target.targetRelativePath,
                      entry.fileDigest == target.candidateFileDigest
                else {
                    throw invalid("derived target does not match its decoded delta entry")
                }
            }
            for entry in delta.entries {
                for source in entry.sourceSemanticBindings {
                    let actual = try candidateSemanticDigest(
                        source,
                        manifest: manifest,
                        bundles: bundles,
                        capture: capture,
                        requirementRegistry: registry
                    )
                    guard actual == source.digest else {
                        throw ContractError.digestMismatch(
                            kind: "candidate derived semantic source",
                            expected: source.digest.rawValue,
                            actual: actual.rawValue
                        )
                    }
                }
            }
        }

        for claim in claims where [.check, .fixture, .migration].contains(claim.family) {
            let file = try file(for: claim.key.componentID, artifactID: claim.key.artifactID, bundles: bundles, capture: capture)
            try validateCanonicalJSONObject(file.bytes, kind: claim.family.rawValue)
        }
    }

    private func candidateSemanticDigest(
        _ source: SourceSemanticBinding,
        manifest: CandidateOverlayManifest,
        bundles: [String: CandidateComponentBundle],
        capture: CandidateTreeCapture,
        requirementRegistry: RequirementRegistry
    ) throws -> HashDigest {
        switch source.sourceKind {
        case "rule":
            guard let binding = manifest.rules.first(where: {
                $0.id.rawValue == source.sourceID
            }) else {
                throw ContractError.unresolvedReference(
                    kind: "candidate semantic rule",
                    id: source.sourceID
                )
            }
            let captured = try file(for: binding.reviewedComponentID, artifactID: binding.bundleArtifactID, bundles: bundles, capture: capture)
            return try RuleSemanticDigest.digest(
                decodeCanonicalFile(RuleRecord.self, file: captured, kind: "candidate rule")
            )
        case "profile":
            guard let binding = manifest.profiles.first(where: {
                $0.id.rawValue == source.sourceID
            }) else {
                throw ContractError.unresolvedReference(
                    kind: "candidate semantic profile",
                    id: source.sourceID
                )
            }
            let captured = try file(for: binding.reviewedComponentID, artifactID: binding.bundleArtifactID, bundles: bundles, capture: capture)
            return try ProfileSemanticDigest.digest(
                decodeCanonicalFile(ProfileRecord.self, file: captured, kind: "candidate profile")
            )
        case "adr":
            guard let binding = manifest.adrs.first(where: {
                $0.id.rawValue == source.sourceID
            }) else {
                throw ContractError.unresolvedReference(
                    kind: "candidate semantic ADR",
                    id: source.sourceID
                )
            }
            let metadataFile = try file(for: binding.reviewedComponentID, artifactID: binding.metadataBundleArtifactID, bundles: bundles, capture: capture)
            let markdownFile = try file(for: binding.reviewedComponentID, artifactID: binding.markdownBundleArtifactID, bundles: bundles, capture: capture)
            let metadata = try decodeCanonicalFile(ADRMetadata.self, file: metadataFile, kind: "candidate ADR metadata")
            guard let markdown = String(data: markdownFile.bytes, encoding: .utf8) else {
                throw invalid("candidate ADR Markdown is not UTF-8")
            }
            return try ADRSemanticDigest.digest(metadata: metadata, markdown: markdown)
        case "requirement":
            guard let requirement = requirementRegistry.requirements.first(where: {
                $0.id.rawValue == source.sourceID
            }) else {
                throw ContractError.unresolvedReference(
                    kind: "candidate semantic Requirement",
                    id: source.sourceID
                )
            }
            return try CanonicalTreeDigest.sha256(CanonicalJSON.encode(requirement))
        case "chapter":
            guard let binding = manifest.chapters.first(where: {
                $0.id == source.sourceID
            }) else {
                throw ContractError.unresolvedReference(
                    kind: "candidate semantic Chapter",
                    id: source.sourceID
                )
            }
            let captured = try file(for: binding.reviewedComponentID, artifactID: binding.bundleArtifactID, bundles: bundles, capture: capture)
            let chapter = try decodeCanonicalFile(ChapterMetadata.self, file: captured, kind: "candidate chapter")
            return try CanonicalTreeDigest.sha256(CanonicalJSON.encode(chapter))
        default:
            throw invalid("candidate derived source kind is not closed")
        }
    }

    private func validateRequirementClosure(
        binding: RequirementRegistryOverlayBinding,
        candidate: RequirementRegistry,
        base: RequirementRegistry
    ) throws {
        let declaredIDs = Set(binding.records.map(\.id))
        let baseRequirements = Dictionary(uniqueKeysWithValues: base.requirements.map { ($0.id, $0) })
        let candidateRequirements = Dictionary(uniqueKeysWithValues: candidate.requirements.map { ($0.id, $0) })
        let baseTraceability = Dictionary(uniqueKeysWithValues: base.traceability.map { ($0.requirementID, $0) })
        let candidateTraceability = Dictionary(uniqueKeysWithValues: candidate.traceability.map { ($0.requirementID, $0) })

        for record in binding.records {
            let baseRequirement = baseRequirements[record.id]
            let baseTrace = baseTraceability[record.id]
            let candidateRequirement = candidateRequirements[record.id]
            let candidateTrace = candidateTraceability[record.id]
            try validateRecordDigest(
                baseRequirement,
                expected: record.beforeRequirementRecordDigest,
                kind: "before requirement record"
            )
            try validateRecordDigest(
                baseTrace,
                expected: record.beforeTraceabilityRecordDigest,
                kind: "before traceability record"
            )
            try validateRequiredRecordDigest(
                candidateRequirement,
                expected: record.candidateRequirementRecordDigest,
                kind: "candidate requirement record"
            )
            try validateRequiredRecordDigest(
                candidateTrace,
                expected: record.candidateTraceabilityRecordDigest,
                kind: "candidate traceability record"
            )
        }

        for (id, value) in candidateRequirements where !declaredIDs.contains(id) {
            guard baseRequirements[id] == value else {
                throw invalid("undeclared Requirement row changed: \(id.rawValue)")
            }
        }
        for (id, value) in candidateTraceability where !declaredIDs.contains(id) {
            guard baseTraceability[id] == value else {
                throw invalid("undeclared traceability row changed: \(id.rawValue)")
            }
        }
        guard Set(candidateRequirements.keys) == Set(baseRequirements.keys),
              Set(candidateTraceability.keys) == Set(baseTraceability.keys)
        else {
            throw invalid("candidate requirement registry has undeclared row additions or omissions")
        }
    }

    private func validateIndexClosure(
        binding: IndexOverlayBinding,
        file indexFile: CandidateCapturedFile,
        baseEvidence: CanonSnapshotEvidence,
        manifest: CandidateOverlayManifest,
        bundles: [String: CandidateComponentBundle],
        capture: CandidateTreeCapture
    ) throws {
        let declared = Set(binding.entries.map(\.id))
        guard let baseBytes = baseEvidence.fileBytesByRelativePath[binding.targetRelativePath] else {
            throw invalid("base Canon index bytes are absent from retained evidence")
        }
        if binding.targetRelativePath == "registry/derived-artifacts.index.json" {
            let candidate = try decodeCanonicalFile(
                CanonDerivedArtifactIndex.self,
                file: indexFile,
                kind: "candidate derived index"
            )
            let base = try CanonicalJSON.decode(CanonDerivedArtifactIndex.self, from: baseBytes)
            guard candidate.schemaVersion == base.schemaVersion,
                  candidate.id == base.id
            else {
                throw invalid("candidate index top-level fields differ from base")
            }
            let candidateByID = Dictionary(uniqueKeysWithValues: candidate.entries.map { ($0.indexKey, $0) })
            let baseByID = Dictionary(uniqueKeysWithValues: base.entries.map { ($0.indexKey, $0) })
            for declaredEntry in binding.entries {
                guard let value = candidateByID[declaredEntry.id],
                      try CanonicalTreeDigest.sha256(CanonicalJSON.encode(value))
                      == declaredEntry.candidateRecordDigest
                else {
                    throw invalid("candidate derived index entry digest is invalid")
                }

                let indexTransforms = manifest.activationTransformSet.indexEntries.filter {
                    $0.indexID == binding.id && $0.entryID == declaredEntry.id
                }
                let matchingDeltas: [(
                    binding: DerivedRegistrationOverlayBinding,
                    target: DerivedTargetBinding
                )] = manifest.derivedRegistrationDeltas.compactMap { deltaBinding in
                    guard let target = deltaBinding.targets.first(where: {
                        $0.indexKey == declaredEntry.id
                    }) else { return nil }
                    return (deltaBinding, target)
                }
                guard indexTransforms.count == 1,
                      let indexTransform = indexTransforms.first,
                      indexTransform.sourceKind == .derivedRegistrationEntry,
                      indexTransform.sourceID == value.indexKey,
                      indexTransform.sourceRelativePath == value.targetPath,
                      matchingDeltas.count == 1,
                      let deltaJoin = matchingDeltas.first
                else {
                    throw invalid(
                        "candidate derived index entry differs from decoded delta or transform"
                    )
                }

                let deltaFile = try file(
                    for: deltaJoin.binding.reviewedComponentID,
                    artifactID: deltaJoin.binding.bundleArtifactID,
                    bundles: bundles,
                    capture: capture
                )
                let delta = try decodeCanonicalFile(
                    DerivedRegistrationDelta.self,
                    file: deltaFile,
                    kind: "candidate derived delta"
                )
                let decodedEntries = delta.entries.filter { $0.indexKey == declaredEntry.id }
                let publicationTransforms = manifest.activationTransformSet
                    .derivedPublications.filter {
                        $0.deltaID == deltaJoin.binding.deltaID
                            && $0.indexKey == declaredEntry.id
                    }
                guard delta.deltaID == deltaJoin.binding.deltaID,
                      deltaFile.contentDigest == deltaJoin.binding.candidateDeltaDigest,
                      decodedEntries.count == 1,
                      decodedEntries.first == value,
                      deltaJoin.target.targetRelativePath == value.targetPath,
                      deltaJoin.target.candidateFileDigest == value.fileDigest,
                      publicationTransforms.count == 1,
                      let publicationTransform = publicationTransforms.first,
                      publicationTransform.bundleArtifactID
                      == deltaJoin.target.bundleArtifactID,
                      publicationTransform.bundlePublicationID
                      == deltaJoin.target.bundlePublicationID
                else {
                    throw invalid(
                        "candidate derived index entry differs from decoded delta or transform"
                    )
                }
            }
            try requireOnlyDeclaredChanges(
                base: baseByID,
                candidate: candidateByID,
                declared: declared,
                kind: "derived index"
            )
        } else {
            let candidate = try decodeCanonicalFile(
                CanonRecordIndex.self,
                file: indexFile,
                kind: "candidate record index"
            )
            let base = try CanonicalJSON.decode(CanonRecordIndex.self, from: baseBytes)
            guard candidate.schemaVersion == base.schemaVersion,
                  candidate.id == base.id
            else {
                throw invalid("candidate index top-level fields differ from base")
            }
            let candidateByID = Dictionary(uniqueKeysWithValues: candidate.entries.map { ($0.id, $0) })
            let baseByID = Dictionary(uniqueKeysWithValues: base.entries.map { ($0.id, $0) })
            for declaredEntry in binding.entries {
                let transforms = manifest.activationTransformSet.indexEntries.filter {
                    $0.indexID == binding.id && $0.entryID == declaredEntry.id
                }
                guard transforms.count == 1,
                      let transform = transforms.first,
                      let value = candidateByID[declaredEntry.id],
                      let source = regularIndexSource(
                          binding: binding,
                          transform: transform,
                          manifest: manifest
                      ),
                      value.id == source.id,
                      value.relativePath.rawValue == source.relativePath,
                      value.recordDigest == source.digest,
                      value.recordDigest == declaredEntry.candidateRecordDigest,
                      transform.sourceID == source.id,
                      transform.sourceRelativePath == source.relativePath
                else {
                    throw invalid(
                        "candidate regular index entry does not join its activation source"
                    )
                }
            }
            try requireOnlyDeclaredChanges(
                base: baseByID,
                candidate: candidateByID,
                declared: declared,
                kind: "record index"
            )
        }
    }

    private func regularIndexSource(
        binding: IndexOverlayBinding,
        transform: IndexEntryActivationTransform,
        manifest: CandidateOverlayManifest
    ) -> RegularIndexSource? {
        switch binding.targetRelativePath {
        case "registry/rules.index.json":
            guard transform.sourceKind == .ruleRecord,
                  let source = manifest.rules.first(where: {
                      $0.id.rawValue == transform.sourceID
                  })
            else { return nil }
            return RegularIndexSource(
                id: source.id.rawValue,
                relativePath: source.targetRelativePath,
                digest: source.candidateFullDigest
            )
        case "registry/profiles.index.json":
            guard transform.sourceKind == .profileRecord,
                  let source = manifest.profiles.first(where: {
                      $0.id.rawValue == transform.sourceID
                  })
            else { return nil }
            return RegularIndexSource(
                id: source.id.rawValue,
                relativePath: source.targetRelativePath,
                digest: source.candidateFullDigest
            )
        case "registry/adrs.index.json":
            guard transform.sourceKind == .adrMetadata,
                  let source = manifest.adrs.first(where: {
                      $0.id.rawValue == transform.sourceID
                  })
            else { return nil }
            return RegularIndexSource(
                id: source.id.rawValue,
                relativePath: source.metadataTargetRelativePath,
                digest: source.candidateMetadataFullDigest
            )
        case "registry/chapters.index.json":
            guard transform.sourceKind == .chapterMetadata,
                  let source = manifest.chapters.first(where: {
                      $0.id == transform.sourceID
                  })
            else { return nil }
            return RegularIndexSource(
                id: source.id,
                relativePath: source.targetRelativePath,
                digest: source.candidateFileDigest
            )
        default:
            return nil
        }
    }

    private func validateTargetPreconditions(
        manifest: CandidateOverlayManifest,
        bundles: [String: CandidateComponentBundle],
        basePluginInventory: CanonicalTreeInventory,
        canonInventory: CanonicalTreeInventory,
        capture: CandidateTreeCapture
    ) throws {
        try validatePublicationNamespaceClosure(bundles: bundles)

        let orderedBundles = bundles.values.sorted {
            $0.componentID.utf8.lexicographicallyPrecedes($1.componentID.utf8)
        }
        var directoryClaims: [String: CandidatePortableMode] = [:]
        var localDirectoryClaims: [String: [String: CandidatePortableMode]] = [:]
        for bundle in orderedBundles {
            var localClaims: [String: CandidatePortableMode] = [:]
            for directory in bundle.targetDirectories {
                let key = directory.targetNamespace.rawValue + "\0" + directory.targetRelativePath
                if let previous = directoryClaims[key], previous != directory.mode {
                    throw invalid("conflicting target directory claims")
                }
                if let previous = localClaims[key], previous != directory.mode {
                    throw invalid("conflicting component-local target directory claims")
                }
                directoryClaims[key] = directory.mode
                localClaims[key] = directory.mode
                let inventory = directory.targetNamespace == .canon
                    ? canonInventory
                    : basePluginInventory
                guard inventory.entries.first(where: {
                    $0.relativePath == directory.targetRelativePath
                }) == nil else {
                    throw invalid("target directory claims may name only absent parents")
                }
            }
            localDirectoryClaims[bundle.componentID] = localClaims
        }

        for bundle in orderedBundles {
            let componentFamily = CandidatePublicationComponentFamily(
                rawValue: bundle.componentKind
            )
            for publication in bundle.publications {
                let inventory = publication.targetNamespace == .canon
                    ? canonInventory
                    : basePluginInventory
                let existing = inventory.entries.first {
                    $0.relativePath == publication.targetRelativePath
                }
                if let existing {
                    guard existing.kind == .regularFile,
                          let digest = existing.contentSHA256,
                          let before = publication.beforeEntry,
                          before.kind == .regularFile,
                          before.contentSHA256 == digest,
                          before.mode.rawValue == existing.mode,
                          publication.targetMode.rawValue == existing.mode
                    else {
                        throw invalid("existing target precondition differs from retained evidence")
                    }
                } else {
                    guard publication.beforeEntry == nil else {
                        throw invalid("an absent target cannot declare a before entry")
                    }
                    try requireMissingParentClaims(
                        componentID: bundle.componentID,
                        publication: publication,
                        inventory: inventory,
                        directoryClaims: localDirectoryClaims[bundle.componentID] ?? [:]
                    )
                }

                if publication.targetNamespace == .pluginDerived {
                    guard let componentFamily else {
                        throw invalid("plugin-derived component_kind is not a closed authority family")
                    }
                    let targetPath = try PluginDerivedTargetPath(
                        validating: publication.targetRelativePath
                    )
                    guard let artifact = bundle.artifacts.first(where: {
                        $0.artifactID == publication.artifactID
                    }) else {
                        throw invalid("publication references a missing bundle artifact")
                    }
                    if artifact.family == .derivedTarget {
                        let entry = try derivedEntry(
                            componentID: bundle.componentID,
                            artifact: artifact,
                            manifest: manifest,
                            bundles: bundles,
                            capture: capture
                        )
                        guard CandidateOverlayAuthority.allows(
                            componentFamily: componentFamily,
                            artifactKind: entry.artifactKind,
                            targetPath: targetPath,
                            publicationKind: publication.publicationKind,
                            mode: publication.targetMode
                        ) else {
                            throw invalid("plugin-derived publication lacks one exact authority row")
                        }
                    } else {
                        let artifactKind: DerivedArtifactKind? = switch artifact.family {
                        case .check:
                            .checklist
                        case .fixture:
                            .example
                        case .migration:
                            .migrationGuide
                        default:
                            nil
                        }
                        guard let artifactKind,
                              CandidateOverlayAuthority.allows(
                                  componentFamily: componentFamily,
                                  artifactKind: artifactKind,
                                  targetPath: targetPath,
                                  publicationKind: publication.publicationKind,
                                  mode: publication.targetMode
                              )
                        else {
                            throw invalid("optional plugin publication lacks one exact authority row")
                        }
                    }
                }
            }
        }

        try validateManifestBeforeDigests(
            manifest: manifest,
            canonInventory: canonInventory
        )
    }

    private func validatePublicationNamespaceClosure(
        bundles: [String: CandidateComponentBundle]
    ) throws {
        let fileClaims = Set(bundles.values.flatMap { bundle in
            bundle.publications.map {
                PublicationNamespacePath(
                    namespace: $0.targetNamespace.rawValue,
                    path: $0.targetRelativePath
                )
            }
        })
        let directoryClaims = Set(bundles.values.flatMap { bundle in
            bundle.targetDirectories.map {
                PublicationNamespacePath(
                    namespace: $0.targetNamespace.rawValue,
                    path: $0.targetRelativePath
                )
            }
        })
        let orderedFiles = fileClaims.sorted(by: PublicationNamespacePath.canonicalLess)
        for file in orderedFiles {
            let descendantPrefix = file.path + "/"
            let conflictsWithDirectory = directoryClaims.contains(file)
                || directoryClaims.contains(where: {
                    $0.namespace == file.namespace
                        && $0.path.hasPrefix(descendantPrefix)
                })
            let conflictsWithFileDescendant = fileClaims.contains(where: {
                $0.namespace == file.namespace
                    && $0.path.hasPrefix(descendantPrefix)
            })
            guard !conflictsWithDirectory, !conflictsWithFileDescendant else {
                throw invalid(
                    "publication namespace has a file/directory conflict at "
                        + file.namespace + ":" + file.path
                )
            }
        }
    }

    private func validateManifestBeforeDigests(
        manifest: CandidateOverlayManifest,
        canonInventory: CanonicalTreeInventory
    ) throws {
        func digest(at path: String) -> HashDigest? {
            canonInventory.entries.first { $0.relativePath == path }?.contentSHA256
        }
        for rule in manifest.rules {
            guard rule.beforeFullDigest == digest(at: rule.targetRelativePath) else {
                throw invalid("Rule before_full_digest differs from retained Canon")
            }
        }
        for adr in manifest.adrs {
            guard adr.beforeMetadataFullDigest == digest(at: adr.metadataTargetRelativePath) else {
                throw invalid("ADR before_metadata_full_digest differs from retained Canon")
            }
        }
        let requirements = manifest.requirementRegistry
        guard requirements.beforeFullDigest == digest(at: requirements.targetRelativePath) else {
            throw invalid("Requirement registry before_full_digest differs from retained Canon")
        }
        for index in manifest.indexes {
            guard index.beforeFullDigest == digest(at: index.targetRelativePath) else {
                throw invalid("index before_full_digest differs from retained Canon")
            }
        }
    }

    private func derivedEntry(
        componentID: String,
        artifact: CandidateBundleArtifact,
        manifest: CandidateOverlayManifest,
        bundles: [String: CandidateComponentBundle],
        capture: CandidateTreeCapture
    ) throws -> DerivedRegistrationEntry {
        let matches: [(
            binding: DerivedRegistrationOverlayBinding,
            target: DerivedTargetBinding
        )] = manifest.derivedRegistrationDeltas.compactMap { binding in
            guard binding.reviewedComponentID == componentID,
                  let target = binding.targets.first(where: {
                      $0.bundleArtifactID == artifact.artifactID
                  }) else { return nil }
            return (binding, target)
        }
        guard matches.count == 1, let match = matches.first,
              let bundle = bundles[componentID],
              let deltaArtifact = bundle.artifacts.first(where: {
                  $0.artifactID == match.binding.bundleArtifactID
              })
        else {
            throw invalid("derived target has no unique component-local delta binding")
        }
        let file = try requireFile(
            deltaArtifact.candidateRelativePath,
            in: capture
        )
        let delta = try decodeCanonicalFile(
            DerivedRegistrationDelta.self,
            file: file,
            kind: "candidate derived delta"
        )
        let entries = delta.entries.filter { $0.indexKey == match.target.indexKey }
        guard delta.deltaID == match.binding.deltaID,
              file.contentDigest == match.binding.candidateDeltaDigest,
              match.target.candidateFileDigest == artifact.candidateFileDigest,
              entries.count == 1,
              let entry = entries.first
        else {
            throw invalid("derived target is absent from its decoded delta")
        }
        return entry
    }

    private func requireMissingParentClaims(
        componentID: String,
        publication: CandidateBundlePublication,
        inventory: CanonicalTreeInventory,
        directoryClaims: [String: CandidatePortableMode]
    ) throws {
        let components = publication.targetRelativePath.split(separator: "/").map(String.init)
        guard components.count > 1 else { return }
        for end in 1 ..< components.count {
            let parent = components[..<end].joined(separator: "/")
            if let entry = inventory.entries.first(where: { $0.relativePath == parent }) {
                guard entry.kind == .directory else {
                    throw invalid("publication parent is not a directory")
                }
            } else {
                let key = publication.targetNamespace.rawValue + "\0" + parent
                guard directoryClaims[key] == .executable else {
                    throw invalid(
                        "component \(componentID) lacks a local directory claim for "
                            + publication.targetNamespace.rawValue + ":" + parent
                    )
                }
            }
        }
    }

    private func subtreeInventory(
        of inventory: CanonicalTreeInventory,
        at rootPath: String
    ) throws -> CanonicalTreeInventory {
        guard let root = inventory.entries.first(where: {
            $0.relativePath == rootPath && $0.kind == .directory
        }) else {
            throw invalid("retained plugin subtree root is missing: \(rootPath)")
        }
        let prefix = rootPath + "/"
        let entries = try inventory.entries.compactMap { entry -> CanonicalTreeEntry? in
            guard entry.relativePath.hasPrefix(prefix) else { return nil }
            return try CanonicalTreeEntry(
                relativePath: String(entry.relativePath.dropFirst(prefix.count)),
                kind: entry.kind,
                contentSHA256: entry.contentSHA256,
                mode: entry.mode
            )
        }
        return try CanonicalTreeInventory(
            policy: CanonicalTreePolicy(excludedRoots: []),
            rootMode: root.mode,
            entries: entries
        )
    }

    private func subtreeSnapshots(
        _ snapshots: [String: CanonFileSnapshot],
        at rootPath: String
    ) throws -> [String: CanonFileSnapshot] {
        guard let root = snapshots[rootPath] else {
            throw invalid("retained object subtree is missing: \(rootPath)")
        }
        let prefix = rootPath + "/"
        var projected: [String: CanonFileSnapshot] = ["": root]
        for (path, snapshot) in snapshots where path.hasPrefix(prefix) {
            let relativePath = String(path.dropFirst(prefix.count))
            guard projected.updateValue(snapshot, forKey: relativePath) == nil else {
                throw invalid("retained object subtree has a duplicate path")
            }
        }
        return projected
    }

    private func file(
        for componentID: String,
        artifactID: String,
        bundles: [String: CandidateComponentBundle],
        capture: CandidateTreeCapture
    ) throws -> CandidateCapturedFile {
        guard let bundle = bundles[componentID],
              let artifact = bundle.artifacts.first(where: { $0.artifactID == artifactID })
        else {
            throw ContractError.unresolvedReference(
                kind: "candidate bundle artifact",
                id: componentID + ":" + artifactID
            )
        }
        return try requireFile(artifact.candidateRelativePath, in: capture)
    }

    private func requireFile(
        _ relativePath: String,
        in capture: CandidateTreeCapture
    ) throws -> CandidateCapturedFile {
        guard let file = capture.filesByRelativePath[relativePath] else {
            throw ContractError.unresolvedReference(
                kind: "candidate captured file",
                id: relativePath
            )
        }
        return file
    }

    private func requireAcceptedFile(
        _ relativePath: String,
        in capture: CandidateTreeCapture
    ) throws -> CandidateCapturedFile {
        guard let file = capture.filesByRelativePath[relativePath] else {
            throw CanonDescriptorFailure.integrityViolation(
                "accepted candidate source is missing: \(relativePath)"
            )
        }
        return file
    }

    private func decodeCanonicalFile<Value: Codable>(
        _ type: Value.Type,
        file: CandidateCapturedFile,
        kind: String
    ) throws -> Value {
        let value = try CanonicalJSON.decode(type, from: file.bytes)
        var canonical = try CanonicalJSON.encode(value)
        canonical.append(0x0A)
        guard canonical == file.bytes else {
            throw invalid("\(kind) must use canonical JSON bytes plus one LF")
        }
        return value
    }

    private func validateCanonicalJSONObject(_ bytes: Data, kind: String) throws {
        let value = try JSONSerialization.jsonObject(with: bytes)
        var canonical = try JSONSerialization.data(
            withJSONObject: value,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        canonical.append(0x0A)
        guard canonical == bytes else {
            throw invalid("\(kind) evidence payload must use canonical JSON bytes")
        }
    }

    private func validateRecordDigest(
        _ value: (some Encodable)?,
        expected: HashDigest?,
        kind: String
    ) throws {
        switch (value, expected) {
        case (nil, nil):
            return
        case let (.some(value), .some(expected)):
            let actual = try CanonicalTreeDigest.sha256(CanonicalJSON.encode(value))
            guard actual == expected else {
                throw ContractError.digestMismatch(
                    kind: kind,
                    expected: expected.rawValue,
                    actual: actual.rawValue
                )
            }
        default:
            throw invalid("\(kind) presence does not match its before precondition")
        }
    }

    private func validateRequiredRecordDigest(
        _ value: (some Encodable)?,
        expected: HashDigest,
        kind: String
    ) throws {
        guard let value else {
            throw ContractError.unresolvedReference(kind: kind, id: expected.rawValue)
        }
        let actual = try CanonicalTreeDigest.sha256(CanonicalJSON.encode(value))
        guard actual == expected else {
            throw ContractError.digestMismatch(
                kind: kind,
                expected: expected.rawValue,
                actual: actual.rawValue
            )
        }
    }

    private func requireOnlyDeclaredChanges<Key: Hashable, Value: Equatable>(
        base: [Key: Value],
        candidate: [Key: Value],
        declared: Set<Key>,
        kind: String
    ) throws {
        let keys = Set(base.keys).union(candidate.keys)
        for key in keys where base[key] != candidate[key] && !declared.contains(key) {
            throw invalid("\(kind) contains an undeclared entry change")
        }
        for key in declared where candidate[key] == nil {
            throw invalid("\(kind) omits a declared candidate entry")
        }
    }

    private func manifestClaims(_ manifest: CandidateOverlayManifest) throws -> [ArtifactClaim] {
        var claims: [ArtifactClaim] = []
        func add(
            componentID: String,
            artifactID: String,
            family: CandidateArtifactFamily,
            logicalID: String,
            digest: HashDigest,
            publicationID: String? = nil,
            namespace: CandidateTargetNamespace? = nil,
            targetPath: String? = nil
        ) {
            let publication = publicationID.map {
                PublicationClaim(
                    publicationID: $0,
                    artifactID: artifactID,
                    namespace: namespace!,
                    targetPath: targetPath!
                )
            }
            claims.append(ArtifactClaim(
                key: ArtifactClaimKey(componentID: componentID, artifactID: artifactID),
                family: family,
                logicalID: logicalID,
                digest: digest,
                publication: publication
            ))
        }
        for value in manifest.rules {
            add(componentID: value.reviewedComponentID, artifactID: value.bundleArtifactID, family: .rule, logicalID: value.id.rawValue, digest: value.candidateFullDigest, publicationID: value.bundlePublicationID, namespace: .canon, targetPath: value.targetRelativePath)
        }
        for value in manifest.profiles {
            add(componentID: value.reviewedComponentID, artifactID: value.bundleArtifactID, family: .profile, logicalID: value.id.rawValue, digest: value.candidateFullDigest, publicationID: value.bundlePublicationID, namespace: .canon, targetPath: value.targetRelativePath)
        }
        for value in manifest.adrs {
            add(componentID: value.reviewedComponentID, artifactID: value.metadataBundleArtifactID, family: .adrMetadata, logicalID: value.id.rawValue, digest: value.candidateMetadataFullDigest, publicationID: value.metadataBundlePublicationID, namespace: .canon, targetPath: value.metadataTargetRelativePath)
            add(componentID: value.reviewedComponentID, artifactID: value.markdownBundleArtifactID, family: .adrMarkdown, logicalID: value.id.rawValue, digest: value.candidateMarkdownFullDigest, publicationID: value.markdownBundlePublicationID, namespace: .canon, targetPath: value.markdownTargetRelativePath)
        }
        for value in manifest.chapters {
            add(componentID: value.reviewedComponentID, artifactID: value.bundleArtifactID, family: .chapter, logicalID: value.id, digest: value.candidateFileDigest, publicationID: value.bundlePublicationID, namespace: .canon, targetPath: value.targetRelativePath)
        }
        let requirements = manifest.requirementRegistry
        add(componentID: requirements.reviewedComponentID, artifactID: requirements.bundleArtifactID, family: .requirementRegistry, logicalID: "requirements-v1", digest: requirements.candidateFullDigest, publicationID: requirements.bundlePublicationID, namespace: .canon, targetPath: requirements.targetRelativePath)
        for (family, values) in [
            (CandidateArtifactFamily.check, manifest.checks),
            (.fixture, manifest.fixtures),
            (.migration, manifest.migrations),
        ] {
            for value in values {
                add(componentID: value.reviewedComponentID, artifactID: value.bundleArtifactID, family: family, logicalID: value.id, digest: value.candidateFileDigest, publicationID: value.bundlePublicationID, namespace: value.bundlePublicationID == nil ? nil : .pluginDerived, targetPath: value.targetRelativePath)
            }
        }
        for value in manifest.indexes {
            add(componentID: value.reviewedComponentID, artifactID: value.bundleArtifactID, family: .index, logicalID: value.id, digest: value.candidateFullDigest, publicationID: value.bundlePublicationID, namespace: .canon, targetPath: value.targetRelativePath)
        }
        for delta in manifest.derivedRegistrationDeltas {
            add(componentID: delta.reviewedComponentID, artifactID: delta.bundleArtifactID, family: .derivedDelta, logicalID: delta.deltaID, digest: delta.candidateDeltaDigest)
            for target in delta.targets {
                add(componentID: delta.reviewedComponentID, artifactID: target.bundleArtifactID, family: .derivedTarget, logicalID: target.indexKey, digest: target.candidateFileDigest, publicationID: target.bundlePublicationID, namespace: .pluginDerived, targetPath: target.targetRelativePath)
            }
        }
        let artifactKeys = claims.map(\.key)
        guard Set(artifactKeys).count == artifactKeys.count else {
            throw invalid("manifest has duplicate component/artifact claims")
        }
        let publicationKeys = claims.compactMap { claim in
            claim.publication.map {
                PublicationClaimKey(
                    componentID: claim.key.componentID,
                    publicationID: $0.publicationID
                )
            }
        }
        guard Set(publicationKeys).count == publicationKeys.count else {
            throw invalid("manifest has duplicate component/publication claims")
        }
        return claims
    }

    private func firstChangedObjectPath(
        before: [String: CanonFileSnapshot],
        after: [String: CanonFileSnapshot]
    ) -> String {
        let paths = Set(before.keys).union(after.keys).sorted {
            $0.utf8.lexicographicallyPrecedes($1.utf8)
        }
        let changed = paths.filter { before[$0] != after[$0] }
        return changed.first {
            before[$0]?.isRegularFile == true || after[$0]?.isRegularFile == true
        } ?? changed.first ?? ""
    }

    private func invalid(_ reason: String) -> ContractError {
        ContractError.invalidContract(
            kind: "candidate_overlay_validation",
            reason: reason
        )
    }
}

private struct ArtifactClaimKey: Hashable {
    let componentID: String
    let artifactID: String
}

private struct PublicationClaimKey: Hashable {
    let componentID: String
    let publicationID: String
}

private struct PublicationClaim {
    let publicationID: String
    let artifactID: String
    let namespace: CandidateTargetNamespace
    let targetPath: String
}

private struct ArtifactClaim {
    let key: ArtifactClaimKey
    let family: CandidateArtifactFamily
    let logicalID: String
    let digest: HashDigest
    let publication: PublicationClaim?
}

private struct RegularIndexSource {
    let id: String
    let relativePath: String
    let digest: HashDigest
}

private struct PublicationNamespacePath: Hashable {
    let namespace: String
    let path: String

    static func canonicalLess(
        _ lhs: PublicationNamespacePath,
        _ rhs: PublicationNamespacePath
    ) -> Bool {
        let lhsKey = lhs.namespace + "\0" + lhs.path
        let rhsKey = rhs.namespace + "\0" + rhs.path
        return lhsKey.utf8.lexicographicallyPrecedes(rhsKey.utf8)
    }
}
