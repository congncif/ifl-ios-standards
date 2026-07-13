import Foundation
import IFLContracts

package struct CandidateActivationTransformResult {
    package let outputFiles: [ResolvedCandidateOutputFile]
    package let outputDirectories: [ResolvedCandidateOutputDirectory]
    package let digestTransitions: [ActivationDigestTransition]
}

package enum CandidateActivationTransform {
    package static func apply(
        candidate: ValidatedCandidateOverlay,
        approval: CanonActivationApprovalInput
    ) throws -> CandidateActivationTransformResult {
        var builder = try CandidateActivationTransformBuilder(
            candidate: candidate,
            approval: approval
        )
        return try builder.build()
    }
}

private struct CandidateActivationTransformBuilder {
    private struct ComponentContext {
        let bundle: CandidateComponentBundle
        let affectedComponent: ActivationAffectedComponentReference
        let artifactsByID: [String: CandidateBundleArtifact]
        let publicationsByID: [String: CandidateBundlePublication]
    }

    private struct PendingOutputFile {
        let output: ResolvedCandidateOutputFile
        let publication: CandidateBundlePublication
    }

    private let candidate: ValidatedCandidateOverlay
    private let approval: CanonActivationApprovalInput
    private let componentsByID: [String: ComponentContext]
    private var outputFilesByKey: [String: PendingOutputFile] = [:]
    private var resolvedCanonBytesByPath: [String: Data] = [:]
    private var derivedEntriesByIndexKey: [String: DerivedRegistrationEntry] = [:]
    private var usedArtifacts: Set<String> = []
    private var usedPublications: Set<String> = []

    init(
        candidate: ValidatedCandidateOverlay,
        approval: CanonActivationApprovalInput
    ) throws {
        self.candidate = candidate
        self.approval = approval
        var contexts: [String: ComponentContext] = [:]
        for (componentID, bundle) in candidate.componentBundles {
            guard let reviewed = candidate.manifest.reviewedComponents.first(where: {
                $0.componentID == componentID
            }),
                reviewed.componentKind == bundle.componentKind
            else {
                throw ContractError.invalidContract(
                    kind: "candidate_overlay_resolution",
                    reason: "captured component bundle differs from its reviewed component"
                )
            }
            let reference = try ActivationAffectedComponentReference(
                componentKind: reviewed.componentKind,
                componentID: componentID
            )
            let context = ComponentContext(
                bundle: bundle,
                affectedComponent: reference,
                artifactsByID: Dictionary(
                    uniqueKeysWithValues: bundle.artifacts.map { ($0.artifactID, $0) }
                ),
                publicationsByID: Dictionary(
                    uniqueKeysWithValues: bundle.publications.map {
                        ($0.publicationID, $0)
                    }
                )
            )
            guard contexts.updateValue(context, forKey: componentID) == nil else {
                throw ContractError.duplicateIdentifier(
                    kind: "resolved component bundle",
                    id: componentID
                )
            }
        }
        componentsByID = contexts
    }

    mutating func build() throws -> CandidateActivationTransformResult {
        try validateTransformClosure()
        try transformRules()
        try copyProfiles()
        try transformADRs()
        try copyChapters()
        try transformRequirementRegistry()
        try consumeOptionalArtifacts(candidate.manifest.checks)
        try consumeOptionalArtifacts(candidate.manifest.fixtures)
        try consumeOptionalArtifacts(candidate.manifest.migrations)
        try transformDerivedPublications()
        try transformIndexes()
        try validatePhysicalClaimClosure()

        let directories = try resolvedDirectories()
        let files = outputFilesByKey.values.map(\.output).sorted {
            Self.canonicalLess($0.targetKey, $1.targetKey)
        }
        let transitions = try buildTransitions(
            files: files,
            directories: directories
        )
        return CandidateActivationTransformResult(
            outputFiles: files,
            outputDirectories: directories,
            digestTransitions: transitions
        )
    }

    private func validateTransformClosure() throws {
        let manifest = candidate.manifest
        let transforms = manifest.activationTransformSet
        guard Set(transforms.rules.map(\.id)) == Set(manifest.rules.map(\.id)),
              Set(transforms.adrs.map(\.id)) == Set(manifest.adrs.map(\.id)),
              Set(transforms.requirements.map(\.id))
              == Set(manifest.requirementRegistry.records.map(\.id)),
              Set(transforms.indexEntries.map { $0.indexID + "\0" + $0.entryID })
              == Set(manifest.indexes.flatMap { index in
                  index.entries.map { index.id + "\0" + $0.id }
              }),
              Set(transforms.derivedPublications.map {
                  $0.deltaID + "\0" + $0.indexKey
              })
              == Set(manifest.derivedRegistrationDeltas.flatMap { delta in
                  delta.targets.map { delta.deltaID + "\0" + $0.indexKey }
              })
        else {
            throw invalid("activation transforms do not bijectively cover manifest bindings")
        }
    }

    private mutating func transformRules() throws {
        let transforms = Dictionary(
            uniqueKeysWithValues: candidate.manifest.activationTransformSet.rules.map {
                ($0.id, $0)
            }
        )
        for binding in candidate.manifest.rules {
            let transform = try require(transforms[binding.id], "Rule transform", binding.id.rawValue)
            let source = try artifactBytes(
                componentID: binding.reviewedComponentID,
                artifactID: binding.bundleArtifactID
            )
            let rule = try decodeCanonicalFile(RuleRecord.self, data: source)
            guard rule.id == binding.id,
                  rule.lifecycle == .proposed,
                  rule.effectiveIn == candidate.manifest.targetProductVersion,
                  transform.lifecycleSource == .constantActive,
                  transform.effectiveInSource == .targetProductVersion
            else {
                throw invalid("Rule transform source does not match its captured proposed record")
            }
            var object = try Self.object(source)
            object["effective_in"] = candidate.manifest.targetProductVersion
            object["lifecycle"] = RuleLifecycle.active.rawValue
            let output = try Self.canonicalFileData(object)
            _ = try decodeCanonicalFile(RuleRecord.self, data: output)
            try appendOutput(
                componentID: binding.reviewedComponentID,
                artifactID: binding.bundleArtifactID,
                publicationID: binding.bundlePublicationID,
                namespace: .canon,
                path: binding.targetRelativePath,
                bytes: output
            )
        }
    }

    private mutating func copyProfiles() throws {
        for binding in candidate.manifest.profiles {
            let bytes = try artifactBytes(
                componentID: binding.reviewedComponentID,
                artifactID: binding.bundleArtifactID
            )
            let profile = try decodeCanonicalFile(ProfileRecord.self, data: bytes)
            guard profile.id == binding.id,
                  profile.ruleIDs == binding.orderedRuleIDs
            else {
                throw invalid("Profile copy does not match its captured binding")
            }
            try appendOutput(
                componentID: binding.reviewedComponentID,
                artifactID: binding.bundleArtifactID,
                publicationID: binding.bundlePublicationID,
                namespace: .canon,
                path: binding.targetRelativePath,
                bytes: bytes
            )
        }
    }

    private mutating func transformADRs() throws {
        let transforms = Dictionary(
            uniqueKeysWithValues: candidate.manifest.activationTransformSet.adrs.map {
                ($0.id, $0)
            }
        )
        for binding in candidate.manifest.adrs {
            let transform = try require(transforms[binding.id], "ADR transform", binding.id.rawValue)
            let metadataSource = try artifactBytes(
                componentID: binding.reviewedComponentID,
                artifactID: binding.metadataBundleArtifactID
            )
            let metadata = try decodeCanonicalFile(ADRMetadata.self, data: metadataSource)
            guard metadata.id == binding.id,
                  metadata.status == .inReview,
                  metadata.acceptedAt == nil,
                  transform.statusSource == .constantAccepted,
                  transform.acceptedAtSource == .integrationApprovalTimestamp
            else {
                throw invalid("ADR transform source does not match its captured in-review metadata")
            }
            var object = try Self.object(metadataSource)
            object["accepted_at"] = try Self.canonicalDateString(approval.approvalTimestamp)
            object["status"] = ADRStatus.accepted.rawValue
            let metadataOutput = try Self.canonicalFileData(object)
            _ = try decodeCanonicalFile(ADRMetadata.self, data: metadataOutput)
            try appendOutput(
                componentID: binding.reviewedComponentID,
                artifactID: binding.metadataBundleArtifactID,
                publicationID: binding.metadataBundlePublicationID,
                namespace: .canon,
                path: binding.metadataTargetRelativePath,
                bytes: metadataOutput
            )

            let markdown = try artifactBytes(
                componentID: binding.reviewedComponentID,
                artifactID: binding.markdownBundleArtifactID
            )
            guard String(data: markdown, encoding: .utf8) != nil else {
                throw invalid("ADR Markdown is not UTF-8")
            }
            try appendOutput(
                componentID: binding.reviewedComponentID,
                artifactID: binding.markdownBundleArtifactID,
                publicationID: binding.markdownBundlePublicationID,
                namespace: .canon,
                path: binding.markdownTargetRelativePath,
                bytes: markdown
            )
        }
    }

    private mutating func copyChapters() throws {
        for binding in candidate.manifest.chapters {
            let bytes = try artifactBytes(
                componentID: binding.reviewedComponentID,
                artifactID: binding.bundleArtifactID
            )
            let chapter = try decodeCanonicalFile(ChapterMetadata.self, data: bytes)
            guard chapter.id == binding.id else {
                throw invalid("Chapter copy does not match its captured binding")
            }
            try appendOutput(
                componentID: binding.reviewedComponentID,
                artifactID: binding.bundleArtifactID,
                publicationID: binding.bundlePublicationID,
                namespace: .canon,
                path: binding.targetRelativePath,
                bytes: bytes
            )
        }
    }

    private mutating func transformRequirementRegistry() throws {
        let binding = candidate.manifest.requirementRegistry
        let transforms = Dictionary(
            uniqueKeysWithValues: candidate.manifest.activationTransformSet.requirements.map {
                ($0.id, $0)
            }
        )
        let source = try artifactBytes(
            componentID: binding.reviewedComponentID,
            artifactID: binding.bundleArtifactID
        )
        _ = try decodeCanonicalFile(RequirementRegistry.self, data: source)
        var object = try Self.object(source)
        var requirements = try Self.objects(object["requirements"])
        for recordBinding in binding.records {
            let transform = try require(
                transforms[recordBinding.id],
                "Requirement transform",
                recordBinding.id.rawValue
            )
            let index = try require(
                requirements.firstIndex {
                    $0["id"] as? String == recordBinding.id.rawValue
                },
                "Requirement record",
                recordBinding.id.rawValue
            )
            requirements[index]["status"] = transform.targetStatus.rawValue
        }
        object["requirements"] = requirements
        let output = try Self.canonicalFileData(object)
        _ = try decodeCanonicalFile(RequirementRegistry.self, data: output)
        try appendOutput(
            componentID: binding.reviewedComponentID,
            artifactID: binding.bundleArtifactID,
            publicationID: binding.bundlePublicationID,
            namespace: .canon,
            path: binding.targetRelativePath,
            bytes: output
        )
    }

    private mutating func consumeOptionalArtifacts(
        _ bindings: [OptionalPublicationArtifactBinding]
    ) throws {
        for binding in bindings {
            let bytes = try artifactBytes(
                componentID: binding.reviewedComponentID,
                artifactID: binding.bundleArtifactID
            )
            if let publicationID = binding.bundlePublicationID,
               let path = binding.targetRelativePath
            {
                try appendOutput(
                    componentID: binding.reviewedComponentID,
                    artifactID: binding.bundleArtifactID,
                    publicationID: publicationID,
                    namespace: .pluginDerived,
                    path: path,
                    bytes: bytes
                )
            }
        }
    }

    private mutating func transformDerivedPublications() throws {
        let transforms = Dictionary(
            uniqueKeysWithValues:
            candidate.manifest.activationTransformSet.derivedPublications.map {
                ($0.deltaID + "\0" + $0.indexKey, $0)
            }
        )
        for deltaBinding in candidate.manifest.derivedRegistrationDeltas {
            let deltaBytes = try artifactBytes(
                componentID: deltaBinding.reviewedComponentID,
                artifactID: deltaBinding.bundleArtifactID
            )
            let delta = try decodeCanonicalFile(
                DerivedRegistrationDelta.self,
                data: deltaBytes
            )
            guard delta.deltaID == deltaBinding.deltaID,
                  delta.baseSnapshotContentDigest
                  == candidate.manifest.baseSnapshotContentDigest
            else {
                throw invalid("Derived delta does not match its captured binding")
            }
            let entriesByKey = Dictionary(
                uniqueKeysWithValues: delta.entries.map { ($0.indexKey, $0) }
            )
            for target in deltaBinding.targets {
                let key = deltaBinding.deltaID + "\0" + target.indexKey
                let transform = try require(transforms[key], "Derived transform", key)
                guard transform.bundleArtifactID == target.bundleArtifactID,
                      transform.bundlePublicationID == target.bundlePublicationID
                else {
                    throw invalid("Derived transform is cross-bound to another publication")
                }
                let entry = try require(
                    entriesByKey[target.indexKey],
                    "Derived registration entry",
                    target.indexKey
                )
                guard entry.targetPath == target.targetRelativePath,
                      derivedEntriesByIndexKey.updateValue(
                          entry,
                          forKey: target.indexKey
                      ) == nil
                else {
                    throw invalid("Derived target is duplicated or mismatched")
                }
                let output = try artifactBytes(
                    componentID: deltaBinding.reviewedComponentID,
                    artifactID: target.bundleArtifactID
                )
                guard CanonicalTreeDigest.sha256(output) == entry.fileDigest else {
                    throw invalid("Derived target bytes differ from the captured delta entry")
                }
                try appendOutput(
                    componentID: deltaBinding.reviewedComponentID,
                    artifactID: target.bundleArtifactID,
                    publicationID: target.bundlePublicationID,
                    namespace: .pluginDerived,
                    path: target.targetRelativePath,
                    bytes: output
                )
            }
        }
    }

    private mutating func transformIndexes() throws {
        let transforms = Dictionary(
            uniqueKeysWithValues: candidate.manifest.activationTransformSet.indexEntries.map {
                ($0.indexID + "\0" + $0.entryID, $0)
            }
        )
        for binding in candidate.manifest.indexes {
            let source = try artifactBytes(
                componentID: binding.reviewedComponentID,
                artifactID: binding.bundleArtifactID
            )
            let output: Data = if binding.targetRelativePath == "registry/derived-artifacts.index.json" {
                try transformDerivedIndex(
                    source,
                    binding: binding,
                    transforms: transforms
                )
            } else {
                try transformRecordIndex(
                    source,
                    binding: binding,
                    transforms: transforms
                )
            }
            let sourceComponents = try binding.entries.map { entry -> String in
                let transform = try require(
                    transforms[binding.id + "\0" + entry.id],
                    "Index transform",
                    binding.id + ":" + entry.id
                )
                return try sourceComponentID(for: transform)
            }
            try appendOutput(
                componentID: binding.reviewedComponentID,
                additionalComponentIDs: sourceComponents,
                artifactID: binding.bundleArtifactID,
                publicationID: binding.bundlePublicationID,
                namespace: .canon,
                path: binding.targetRelativePath,
                bytes: output
            )
        }
    }

    private func transformRecordIndex(
        _ source: Data,
        binding: IndexOverlayBinding,
        transforms: [String: IndexEntryActivationTransform]
    ) throws -> Data {
        _ = try decodeCanonicalFile(CanonRecordIndex.self, data: source)
        var object = try Self.object(source)
        var entries = try Self.objects(object["entries"])
        for declared in binding.entries {
            let key = binding.id + "\0" + declared.id
            let transform = try require(transforms[key], "Index transform", key)
            guard transform.sourceKind != .derivedRegistrationEntry else {
                throw invalid("regular Canon index cannot consume a derived registration entry")
            }
            let sourceBytes = try require(
                resolvedCanonBytesByPath[transform.sourceRelativePath],
                "resolved index source",
                transform.sourceRelativePath
            )
            let index = try require(
                entries.firstIndex { $0["id"] as? String == declared.id },
                "candidate index entry",
                declared.id
            )
            guard entries[index]["relative_path"] as? String
                == transform.sourceRelativePath
            else {
                throw invalid("index entry source path differs from its typed transform")
            }
            entries[index]["record_digest"] = CanonicalTreeDigest.sha256(
                sourceBytes
            ).rawValue
        }
        object["entries"] = entries
        let output = try Self.canonicalFileData(object)
        _ = try decodeCanonicalFile(CanonRecordIndex.self, data: output)
        return output
    }

    private func transformDerivedIndex(
        _ source: Data,
        binding: IndexOverlayBinding,
        transforms: [String: IndexEntryActivationTransform]
    ) throws -> Data {
        _ = try decodeCanonicalFile(CanonDerivedArtifactIndex.self, data: source)
        var object = try Self.object(source)
        var entries = try Self.objects(object["entries"])
        for declared in binding.entries {
            let key = binding.id + "\0" + declared.id
            let transform = try require(transforms[key], "Index transform", key)
            guard transform.sourceKind == .derivedRegistrationEntry,
                  transform.entryID == transform.sourceID,
                  let resolvedEntry = derivedEntriesByIndexKey[transform.sourceID],
                  resolvedEntry.targetPath == transform.sourceRelativePath
            else {
                throw invalid("derived index transform does not match its captured delta entry")
            }
            let index = try require(
                entries.firstIndex { $0["index_key"] as? String == declared.id },
                "candidate derived index entry",
                declared.id
            )
            let encoded = try CanonicalJSON.encode(resolvedEntry)
            entries[index] = try Self.object(encoded)
        }
        entries.sort {
            Self.canonicalLess(
                $0["target_path"] as? String ?? "",
                $1["target_path"] as? String ?? ""
            )
        }
        object["entries"] = entries
        let output = try Self.canonicalFileData(object)
        _ = try decodeCanonicalFile(CanonDerivedArtifactIndex.self, data: output)
        return output
    }

    private func sourceComponentID(
        for transform: IndexEntryActivationTransform
    ) throws -> String {
        let manifest = candidate.manifest
        let componentID: String? = switch transform.sourceKind {
        case .ruleRecord:
            manifest.rules.first {
                $0.id.rawValue == transform.sourceID
                    && $0.targetRelativePath == transform.sourceRelativePath
            }?.reviewedComponentID
        case .profileRecord:
            manifest.profiles.first {
                $0.id.rawValue == transform.sourceID
                    && $0.targetRelativePath == transform.sourceRelativePath
            }?.reviewedComponentID
        case .adrMetadata:
            manifest.adrs.first {
                $0.id.rawValue == transform.sourceID
                    && $0.metadataTargetRelativePath == transform.sourceRelativePath
            }?.reviewedComponentID
        case .chapterMetadata:
            manifest.chapters.first {
                $0.id == transform.sourceID
                    && $0.targetRelativePath == transform.sourceRelativePath
            }?.reviewedComponentID
        case .derivedRegistrationEntry:
            manifest.derivedRegistrationDeltas.first { delta in
                delta.targets.contains {
                    $0.indexKey == transform.sourceID
                        && $0.targetRelativePath == transform.sourceRelativePath
                }
            }?.reviewedComponentID
        }
        return try require(componentID, "Index source component", transform.sourceID)
    }

    private mutating func appendOutput(
        componentID: String,
        additionalComponentIDs: [String] = [],
        artifactID: String,
        publicationID: String,
        namespace: CandidateTargetNamespace,
        path: String,
        bytes: Data
    ) throws {
        let component = try require(
            componentsByID[componentID],
            "component bundle",
            componentID
        )
        let artifact = try require(
            component.artifactsByID[artifactID],
            "bundle artifact",
            componentID + ":" + artifactID
        )
        let publication = try require(
            component.publicationsByID[publicationID],
            "bundle publication",
            componentID + ":" + publicationID
        )
        guard publication.artifactID == artifact.artifactID,
              publication.targetNamespace == namespace,
              publication.targetRelativePath == path
        else {
            throw invalid("publication does not match its manifest output binding")
        }
        usedArtifacts.insert(componentID + "\0" + artifactID)
        usedPublications.insert(componentID + "\0" + publicationID)

        let componentIDs = Set([componentID] + additionalComponentIDs)
        let affected = try componentIDs.map { id in
            try require(componentsByID[id], "affected component", id)
                .affectedComponent
        }.sorted(by: Self.componentLess)
        let output = ResolvedCandidateOutputFile(
            targetNamespace: namespace,
            targetRelativePath: path,
            bytes: bytes,
            contentDigest: CanonicalTreeDigest.sha256(bytes),
            mode: publication.targetMode.rawValue,
            affectedComponents: affected
        )
        guard outputFilesByKey.updateValue(
            PendingOutputFile(output: output, publication: publication),
            forKey: output.targetKey
        ) == nil else {
            throw invalid("multiple publications resolve to one output path")
        }
        if namespace == .canon {
            guard resolvedCanonBytesByPath.updateValue(bytes, forKey: path) == nil else {
                throw invalid("multiple resolved Canon sources use one path")
            }
        }
    }

    private mutating func artifactBytes(
        componentID: String,
        artifactID: String
    ) throws -> Data {
        let component = try require(
            componentsByID[componentID],
            "component bundle",
            componentID
        )
        let artifact = try require(
            component.artifactsByID[artifactID],
            "bundle artifact",
            componentID + ":" + artifactID
        )
        let captured = try require(
            candidate.candidateTreeCapture.filesByRelativePath[
                artifact.candidateRelativePath
            ],
            "captured candidate artifact",
            artifact.candidateRelativePath
        )
        guard captured.contentDigest == artifact.candidateFileDigest,
              CanonicalTreeDigest.sha256(captured.bytes) == artifact.candidateFileDigest
        else {
            throw invalid("captured candidate artifact bytes differ from their bundle digest")
        }
        usedArtifacts.insert(componentID + "\0" + artifactID)
        return captured.bytes
    }

    private func validatePhysicalClaimClosure() throws {
        let expectedArtifacts = Set(componentsByID.flatMap { componentID, context in
            context.bundle.artifacts.map { componentID + "\0" + $0.artifactID }
        })
        let expectedPublications = Set(componentsByID.flatMap { componentID, context in
            context.bundle.publications.map {
                componentID + "\0" + $0.publicationID
            }
        })
        guard usedArtifacts == expectedArtifacts else {
            throw invalid("resolved artifact claims are incomplete or contain extras")
        }
        guard usedPublications == expectedPublications else {
            throw invalid("resolved publication claims are incomplete or contain extras")
        }
    }

    private func resolvedDirectories() throws -> [ResolvedCandidateOutputDirectory] {
        struct Accumulator {
            let namespace: CandidateTargetNamespace
            let path: String
            let mode: UInt16
            var components: Set<String>
        }
        var accumulators: [String: Accumulator] = [:]
        for (componentID, context) in componentsByID {
            for directory in context.bundle.targetDirectories {
                for publicationID in directory.publicationIDs {
                    guard usedPublications.contains(componentID + "\0" + publicationID)
                    else {
                        throw invalid("new directory refers to an unresolved publication")
                    }
                }
                let key = directory.targetNamespace.rawValue + "\0"
                    + directory.targetRelativePath
                if var existing = accumulators[key] {
                    guard existing.mode == directory.mode.rawValue else {
                        throw invalid("co-owned directory declarations disagree on mode")
                    }
                    existing.components.insert(componentID)
                    accumulators[key] = existing
                } else {
                    accumulators[key] = Accumulator(
                        namespace: directory.targetNamespace,
                        path: directory.targetRelativePath,
                        mode: directory.mode.rawValue,
                        components: [componentID]
                    )
                }
            }
        }
        return try accumulators.values.map { value in
            let affected = try value.components.map { id in
                try require(componentsByID[id], "directory component", id)
                    .affectedComponent
            }.sorted(by: Self.componentLess)
            return ResolvedCandidateOutputDirectory(
                targetNamespace: value.namespace,
                targetRelativePath: value.path,
                mode: value.mode,
                affectedComponents: affected
            )
        }.sorted { Self.canonicalLess($0.targetKey, $1.targetKey) }
    }

    private func buildTransitions(
        files: [ResolvedCandidateOutputFile],
        directories: [ResolvedCandidateOutputDirectory]
    ) throws -> [ActivationDigestTransition] {
        var transitions: [ActivationDigestTransition] = []
        transitions.reserveCapacity(files.count + directories.count)
        for file in files {
            let pending = try require(
                outputFilesByKey[file.targetKey],
                "resolved output",
                file.targetKey
            )
            let before = try baseEntry(
                namespace: file.targetNamespace,
                path: file.targetRelativePath
            )
            try validateBeforeEntry(before, publication: pending.publication)
            let after = try CanonicalTreeEntry(
                relativePath: file.targetRelativePath,
                kind: .regularFile,
                contentSHA256: file.contentDigest,
                mode: file.mode
            )
            guard before != after else {
                throw invalid("resolved output is a no-op: \(file.targetKey)")
            }
            try transitions.append(ActivationDigestTransition(
                targetNamespace: file.targetNamespace,
                targetRelativePath: file.targetRelativePath,
                affectedComponents: file.affectedComponents,
                beforeEntry: before,
                afterEntry: after
            ))
        }
        for directory in directories {
            let before = try baseEntry(
                namespace: directory.targetNamespace,
                path: directory.targetRelativePath
            )
            guard before == nil else {
                throw invalid("declared new output directory already exists")
            }
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
                beforeEntry: nil,
                afterEntry: after
            ))
        }
        return transitions.sorted {
            Self.canonicalLess(
                $0.targetNamespace.rawValue + "\0" + $0.targetRelativePath,
                $1.targetNamespace.rawValue + "\0" + $1.targetRelativePath
            )
        }
    }

    private func baseEntry(
        namespace: CandidateTargetNamespace,
        path: String
    ) throws -> CanonicalTreeEntry? {
        let entries: [CanonicalTreeEntry] = switch namespace {
        case .canon:
            candidate.canonEvidence.fullInventory.entries
        case .pluginDerived:
            candidate.basePluginEvidence.inventory.entries
        }
        return entries.first { $0.relativePath == path }
    }

    private func validateBeforeEntry(
        _ actual: CanonicalTreeEntry?,
        publication: CandidateBundlePublication
    ) throws {
        switch (actual, publication.beforeEntry) {
        case (nil, nil):
            return
        case let (.some(entry), .some(before)):
            guard entry.kind == .regularFile,
                  entry.contentSHA256 == before.contentSHA256,
                  entry.mode == before.mode.rawValue,
                  entry.mode == publication.targetMode.rawValue
            else {
                throw invalid("existing output differs from its retained before entry")
            }
        default:
            throw invalid("output presence differs from its retained before entry")
        }
    }

    private func decodeCanonicalFile<Value: Codable>(
        _ type: Value.Type,
        data: Data
    ) throws -> Value {
        let value = try CanonicalJSON.decode(type, from: data)
        var canonical = try CanonicalJSON.encode(value)
        canonical.append(0x0A)
        guard canonical == data else {
            throw invalid("captured candidate JSON is not canonical file data")
        }
        return value
    }

    private func require<Value>(
        _ value: Value?,
        _ kind: String,
        _ id: String
    ) throws -> Value {
        guard let value else {
            throw ContractError.unresolvedReference(kind: kind, id: id)
        }
        return value
    }

    private func invalid(_ reason: String) -> ContractError {
        ContractError.invalidContract(
            kind: "candidate_overlay_resolution",
            reason: reason
        )
    }

    private static func object(_ data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw ContractError.invalidContract(
                kind: "candidate_overlay_resolution",
                reason: "captured JSON root must be an object"
            )
        }
        return object
    }

    private static func objects(_ value: Any?) throws -> [[String: Any]] {
        guard let objects = value as? [[String: Any]] else {
            throw ContractError.invalidContract(
                kind: "candidate_overlay_resolution",
                reason: "captured JSON field must be an object array"
            )
        }
        return objects
    }

    private static func canonicalFileData(_ object: [String: Any]) throws -> Data {
        var data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        data.append(0x0A)
        return data
    }

    private static func canonicalDateString(_ date: Date) throws -> String {
        try CanonicalJSON.decode(String.self, from: CanonicalJSON.encode(date))
    }

    private static func canonicalLess(_ lhs: String, _ rhs: String) -> Bool {
        lhs.utf8.lexicographicallyPrecedes(rhs.utf8)
    }

    private static func componentLess(
        _ lhs: ActivationAffectedComponentReference,
        _ rhs: ActivationAffectedComponentReference
    ) -> Bool {
        canonicalLess(
            lhs.componentKind + "\0" + lhs.componentID,
            rhs.componentKind + "\0" + rhs.componentID
        )
    }
}
