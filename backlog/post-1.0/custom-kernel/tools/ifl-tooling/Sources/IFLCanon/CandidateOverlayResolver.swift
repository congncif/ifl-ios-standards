import Foundation
import IFLContracts

package struct CandidateOverlayResolver {
    package init() {}

    package func resolve(
        _ candidate: ValidatedCandidateOverlay,
        approval: CanonActivationApprovalInput
    ) throws -> ResolvedCandidateActivation {
        try validateApproval(approval, for: candidate)
        try validateTransformDescriptor(candidate)
        let transformed = try CandidateActivationTransform.apply(
            candidate: candidate,
            approval: approval
        )
        let inventories = try resolveInventories(
            candidate: candidate,
            transformed: transformed
        )
        let resolvedSnapshot = try ResolvedCanonSnapshotDecoder(
            inventory: inventories.fullCanonInventory,
            fileBytesByRelativePath: inventories.resolvedCanonFileBytes,
            snapshotContentDigest: inventories.publishedSnapshotContentDigest
        ).decode()
        let findings = CanonValidator().validate(resolvedSnapshot)
        guard findings.isEmpty else {
            let finding = findings[0]
            throw ContractError.invalidContract(
                kind: "candidate_overlay_resolution",
                reason: "resolved Canon failed \(finding.checkID): \(finding.message)"
            )
        }
        let resolvedDigest = try resolvedActivationDigest(
            candidate: candidate,
            approval: approval,
            transformed: transformed,
            inventories: inventories
        )
        return ResolvedCandidateActivation(
            overlayID: candidate.overlayID.rawValue,
            overlayDigest: candidate.overlayDigest,
            targetCanonVersion: candidate.manifest.targetCanonVersion,
            targetProductVersion: candidate.manifest.targetProductVersion,
            baseSnapshotContentDigest: candidate.manifest.baseSnapshotContentDigest,
            approvalInput: approval,
            activationTransformIdentity: candidate.transformDescriptor.identity,
            activationTransformDigest: candidate.transformDescriptor.digest,
            outputFiles: transformed.outputFiles,
            outputDirectories: transformed.outputDirectories,
            digestTransitions: transformed.digestTransitions,
            baseCanonInventory: candidate.canonEvidence.fullInventory,
            baseCanonInventoryDigest: candidate.canonEvidence.fullInventoryDigest,
            basePluginInventory: candidate.basePluginEvidence.inventory,
            basePluginInventoryDigest: candidate.basePluginEvidence.inventoryDigest,
            candidateTreeCapture: candidate.candidateTreeCapture,
            projectedPublishedCanonInventory: inventories.projectedCanonInventory,
            publishedSnapshotContentDigest: inventories.publishedSnapshotContentDigest,
            resolvedPluginInventory: inventories.resolvedPluginInventory,
            resolvedPluginInventoryDigest: inventories.resolvedPluginInventoryDigest,
            resolvedCanonSnapshot: resolvedSnapshot,
            resolvedActivationDigest: resolvedDigest
        )
    }

    private func resolveInventories(
        candidate: ValidatedCandidateOverlay,
        transformed: CandidateActivationTransformResult
    ) throws -> ResolvedCandidateInventoryClosure {
        var canonEntries = Dictionary(
            uniqueKeysWithValues: candidate.canonEvidence.fullInventory.entries.map {
                ($0.relativePath, $0)
            }
        )
        var resolvedCanonBytes = candidate.canonEvidence.fileBytesByRelativePath
        for directory in transformed.outputDirectories
            where directory.targetNamespace == .canon
        {
            canonEntries[directory.targetRelativePath] = try CanonicalTreeEntry(
                relativePath: directory.targetRelativePath,
                kind: .directory,
                contentSHA256: nil,
                mode: directory.mode
            )
        }
        for file in transformed.outputFiles where file.targetNamespace == .canon {
            canonEntries[file.targetRelativePath] = try CanonicalTreeEntry(
                relativePath: file.targetRelativePath,
                kind: .regularFile,
                contentSHA256: file.contentDigest,
                mode: file.mode
            )
            resolvedCanonBytes[file.targetRelativePath] = file.bytes
        }
        let fullCanonInventory = try CanonicalTreeInventory(
            policy: candidate.canonEvidence.fullInventory.policy,
            rootMode: candidate.canonEvidence.fullInventory.rootMode,
            entries: Array(canonEntries.values)
        )
        let projectedCanon = try CanonSnapshotContentPolicy.project(fullCanonInventory)
        let publishedDigest = try CanonicalTreeDigest.digest(projectedCanon)

        var pluginEntries = Dictionary(
            uniqueKeysWithValues: candidate.basePluginEvidence.inventory.entries.map {
                ($0.relativePath, $0)
            }
        )
        for directory in transformed.outputDirectories {
            let path = pluginPath(
                namespace: directory.targetNamespace,
                relativePath: directory.targetRelativePath
            )
            pluginEntries[path] = try CanonicalTreeEntry(
                relativePath: path,
                kind: .directory,
                contentSHA256: nil,
                mode: directory.mode
            )
        }
        for file in transformed.outputFiles {
            let path = pluginPath(
                namespace: file.targetNamespace,
                relativePath: file.targetRelativePath
            )
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
        let resolvedPluginDigest = try CanonicalTreeDigest.digest(resolvedPlugin)

        try validateTransitionInventoryClosure(
            base: candidate.basePluginEvidence.inventory,
            resolved: resolvedPlugin,
            transformed: transformed
        )
        let projectedCanonFromPlugin = try subtreeInventory(
            resolvedPlugin,
            prefix: "standards/canon"
        )
        guard projectedCanonFromPlugin == fullCanonInventory else {
            throw invalid("resolved plugin Canon subtree differs from the resolved Canon inventory")
        }
        let capturedCandidateFromPlugin = try subtreeInventory(
            resolvedPlugin,
            prefix: "standards/canon-candidates/\(candidate.overlayID.rawValue)"
        )
        guard capturedCandidateFromPlugin == candidate.candidateTreeCapture.inventory else {
            throw invalid("resolved plugin candidate subtree differs from the immutable capture")
        }
        return ResolvedCandidateInventoryClosure(
            fullCanonInventory: fullCanonInventory,
            resolvedCanonFileBytes: resolvedCanonBytes,
            projectedCanonInventory: projectedCanon,
            publishedSnapshotContentDigest: publishedDigest,
            resolvedPluginInventory: resolvedPlugin,
            resolvedPluginInventoryDigest: resolvedPluginDigest
        )
    }

    private func validateTransitionInventoryClosure(
        base: CanonicalTreeInventory,
        resolved: CanonicalTreeInventory,
        transformed: CandidateActivationTransformResult
    ) throws {
        guard base.rootMode == resolved.rootMode,
              base.policy == resolved.policy
        else {
            throw invalid("resolution cannot change the plugin root mode or inventory policy")
        }
        let baseByPath = Dictionary(
            uniqueKeysWithValues: base.entries.map { ($0.relativePath, $0) }
        )
        let resolvedByPath = Dictionary(
            uniqueKeysWithValues: resolved.entries.map { ($0.relativePath, $0) }
        )
        let changed = Set(resolvedByPath.compactMap { path, entry in
            baseByPath[path] == entry ? nil : path
        })
        let deleted = baseByPath.keys.filter { resolvedByPath[$0] == nil }
        guard deleted.isEmpty else {
            throw invalid("resolved plugin inventory contains a deletion")
        }

        var expectedTransitions: [ActivationDigestTransition] = []
        expectedTransitions.reserveCapacity(
            transformed.outputFiles.count + transformed.outputDirectories.count
        )
        var expectedLogicalKeys: Set<String> = []
        var expectedNormalizedKeys: Set<String> = []

        func appendExpected(
            namespace: CandidateTargetNamespace,
            relativePath: String,
            kind: CanonicalTreeEntry.Kind,
            contentDigest: HashDigest?,
            mode: UInt16,
            affectedComponents: [ActivationAffectedComponentReference]
        ) throws {
            let logicalKey = namespace.rawValue + "\0" + relativePath
            let normalizedPath = pluginPath(
                namespace: namespace,
                relativePath: relativePath
            )
            guard expectedLogicalKeys.insert(logicalKey).inserted else {
                throw invalid("resolved output target keys are not unique")
            }
            guard expectedNormalizedKeys.insert(normalizedPath).inserted else {
                throw invalid(
                    "resolved transition keys are not unique after namespace normalization"
                )
            }

            let before = try baseByPath[normalizedPath].map {
                try CanonicalTreeEntry(
                    relativePath: relativePath,
                    kind: $0.kind,
                    contentSHA256: $0.contentSHA256,
                    mode: $0.mode
                )
            }
            let after = try CanonicalTreeEntry(
                relativePath: relativePath,
                kind: kind,
                contentSHA256: contentDigest,
                mode: mode
            )
            let normalizedAfter = try CanonicalTreeEntry(
                relativePath: normalizedPath,
                kind: kind,
                contentSHA256: contentDigest,
                mode: mode
            )
            guard resolvedByPath[normalizedPath] == normalizedAfter else {
                throw invalid(
                    "resolved transition after entry differs from the resolved inventory"
                )
            }
            try expectedTransitions.append(ActivationDigestTransition(
                targetNamespace: namespace,
                targetRelativePath: relativePath,
                affectedComponents: affectedComponents,
                beforeEntry: before,
                afterEntry: after
            ))
        }

        for output in transformed.outputFiles {
            try appendExpected(
                namespace: output.targetNamespace,
                relativePath: output.targetRelativePath,
                kind: .regularFile,
                contentDigest: output.contentDigest,
                mode: output.mode,
                affectedComponents: output.affectedComponents
            )
        }
        for output in transformed.outputDirectories {
            try appendExpected(
                namespace: output.targetNamespace,
                relativePath: output.targetRelativePath,
                kind: .directory,
                contentDigest: nil,
                mode: output.mode,
                affectedComponents: output.affectedComponents
            )
        }
        expectedTransitions.sort {
            canonicalLess(
                $0.targetNamespace.rawValue + "\0" + $0.targetRelativePath,
                $1.targetNamespace.rawValue + "\0" + $1.targetRelativePath
            )
        }
        guard transformed.digestTransitions == expectedTransitions else {
            throw invalid(
                "resolved transitions differ from their complete output and inventory entries"
            )
        }

        var actualNormalizedKeys: Set<String> = []
        for transition in transformed.digestTransitions {
            let normalizedPath = pluginPath(
                namespace: transition.targetNamespace,
                relativePath: transition.targetRelativePath
            )
            guard actualNormalizedKeys.insert(normalizedPath).inserted else {
                throw invalid(
                    "resolved transition keys are not unique after namespace normalization"
                )
            }
            let normalizedBefore = try transition.beforeEntry.map {
                try CanonicalTreeEntry(
                    relativePath: normalizedPath,
                    kind: $0.kind,
                    contentSHA256: $0.contentSHA256,
                    mode: $0.mode
                )
            }
            let normalizedAfter = try CanonicalTreeEntry(
                relativePath: normalizedPath,
                kind: transition.afterEntry.kind,
                contentSHA256: transition.afterEntry.contentSHA256,
                mode: transition.afterEntry.mode
            )
            guard normalizedBefore == baseByPath[normalizedPath],
                  normalizedAfter == resolvedByPath[normalizedPath]
            else {
                throw invalid(
                    "resolved transition entries differ from the exact inventory entries"
                )
            }
        }
        guard changed == actualNormalizedKeys else {
            throw invalid("resolved transitions do not equal the complete inventory delta")
        }
    }

    private func subtreeInventory(
        _ inventory: CanonicalTreeInventory,
        prefix: String
    ) throws -> CanonicalTreeInventory {
        guard let root = inventory.entries.first(where: {
            $0.relativePath == prefix && $0.kind == .directory
        }) else {
            throw invalid("resolved plugin inventory is missing subtree \(prefix)")
        }
        let childPrefix = prefix + "/"
        var entries: [CanonicalTreeEntry] = []
        for entry in inventory.entries where entry.relativePath.hasPrefix(childPrefix) {
            let relative = String(entry.relativePath.dropFirst(childPrefix.count))
            try entries.append(CanonicalTreeEntry(
                relativePath: relative,
                kind: entry.kind,
                contentSHA256: entry.contentSHA256,
                mode: entry.mode
            ))
        }
        return try CanonicalTreeInventory(
            policy: CanonicalTreePolicy(excludedRoots: []),
            rootMode: root.mode,
            entries: entries
        )
    }

    private func resolvedActivationDigest(
        candidate: ValidatedCandidateOverlay,
        approval: CanonActivationApprovalInput,
        transformed: CandidateActivationTransformResult,
        inventories: ResolvedCandidateInventoryClosure
    ) throws -> HashDigest {
        let capturedFiles = candidate.candidateTreeCapture.filesByRelativePath.map {
            path, file in
            ResolvedCandidateFileDigestWire(
                relativePath: path,
                contentDigest: CanonicalTreeDigest.sha256(file.bytes),
                mode: file.mode
            )
        }.sorted { canonicalLess($0.relativePath, $1.relativePath) }
        let outputFiles = transformed.outputFiles.map {
            ResolvedOutputFileDigestWire(
                targetNamespace: $0.targetNamespace,
                targetRelativePath: $0.targetRelativePath,
                contentDigest: CanonicalTreeDigest.sha256($0.bytes),
                mode: $0.mode,
                affectedComponents: $0.affectedComponents
            )
        }
        let outputDirectories = transformed.outputDirectories.map {
            ResolvedOutputDirectoryDigestWire(
                targetNamespace: $0.targetNamespace,
                targetRelativePath: $0.targetRelativePath,
                mode: $0.mode,
                affectedComponents: $0.affectedComponents
            )
        }
        let payload = ResolvedActivationDigestPayload(
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
            candidateFiles: capturedFiles,
            approval: ResolvedApprovalDigestWire(
                integrationApproval: approval.integrationApproval,
                approvalTimestamp: approval.approvalTimestamp,
                approvalSourceArtifactID: approval.approvalSourceArtifactID,
                approvalSourceArtifactDigest: approval.approvalSourceArtifactDigest,
                approvalSidecarRelativePath: approval.approvalSidecarRelativePath,
                approvalSidecarBytesBase64: approval.approvalSidecarBytes.base64EncodedString(),
                approvalSidecarDigest: approval.approvalSidecarDigest
            ),
            outputFiles: outputFiles,
            outputDirectories: outputDirectories,
            digestTransitions: transformed.digestTransitions,
            projectedPublishedCanonInventory: inventories.projectedCanonInventory,
            publishedSnapshotContentDigest: inventories.publishedSnapshotContentDigest,
            resolvedPluginInventory: inventories.resolvedPluginInventory,
            resolvedPluginInventoryDigest: inventories.resolvedPluginInventoryDigest
        )
        var preimage = Data("ifl.candidate-overlay.resolved-activation/v1\0".utf8)
        try preimage.append(CanonicalJSON.encode(payload))
        return CanonicalTreeDigest.sha256(preimage)
    }

    private func pluginPath(
        namespace: CandidateTargetNamespace,
        relativePath: String
    ) -> String {
        switch namespace {
        case .canon:
            "standards/canon/" + relativePath
        case .pluginDerived:
            relativePath
        }
    }

    private func invalid(_ reason: String) -> ContractError {
        ContractError.invalidContract(
            kind: "candidate_overlay_resolution",
            reason: reason
        )
    }

    private func canonicalLess(_ lhs: String, _ rhs: String) -> Bool {
        lhs.utf8.lexicographicallyPrecedes(rhs.utf8)
    }

    private func validateApproval(
        _ approval: CanonActivationApprovalInput,
        for candidate: ValidatedCandidateOverlay
    ) throws {
        guard approval.integrationApproval.reviewedComponentID
            == candidate.overlayID.rawValue
        else {
            throw ContractError.unresolvedReference(
                kind: "integration_approval_overlay",
                id: candidate.overlayID.rawValue
            )
        }
        guard approval.integrationApproval.reviewedComponentDigest
            == candidate.overlayDigest
        else {
            throw ContractError.digestMismatch(
                kind: "integration_approval_overlay",
                expected: candidate.overlayDigest.rawValue,
                actual: approval.integrationApproval.reviewedComponentDigest.rawValue
            )
        }
        let sidecarDigest = CanonicalTreeDigest.sha256(approval.approvalSidecarBytes)
        guard sidecarDigest == approval.approvalSidecarDigest else {
            throw ContractError.digestMismatch(
                kind: "approval_sidecar",
                expected: approval.approvalSidecarDigest.rawValue,
                actual: sidecarDigest.rawValue
            )
        }
    }

    private func validateTransformDescriptor(
        _ candidate: ValidatedCandidateOverlay
    ) throws {
        let compiled = CandidateOverlayTransformDescriptor.v1
        guard candidate.manifest.activationTransformIdentity == compiled.identity,
              candidate.manifest.activationTransformDigest == compiled.digest,
              candidate.transformDescriptor.identity == compiled.identity,
              candidate.transformDescriptor.digest == compiled.digest
        else {
            throw ContractError.invalidContract(
                kind: "candidate_overlay_resolution",
                reason: "validated candidate does not bind the compiled transform descriptor"
            )
        }
    }
}

private struct ResolvedCandidateInventoryClosure {
    let fullCanonInventory: CanonicalTreeInventory
    let resolvedCanonFileBytes: [String: Data]
    let projectedCanonInventory: CanonicalTreeInventory
    let publishedSnapshotContentDigest: HashDigest
    let resolvedPluginInventory: CanonicalTreeInventory
    let resolvedPluginInventoryDigest: HashDigest
}

private struct ResolvedCanonSnapshotDecoder {
    let inventory: CanonicalTreeInventory
    let fileBytesByRelativePath: [String: Data]
    let snapshotContentDigest: HashDigest

    func decode() throws -> CanonSnapshot {
        guard try readFile("VERSION", expectedDigest: nil) == Data("1\n".utf8) else {
            throw ContractError.invalidCanonVersion("resolved VERSION")
        }
        let ruleIndex = try recordIndex("rules.index.json", expectedID: "rules")
        let profileIndex = try recordIndex("profiles.index.json", expectedID: "profiles")
        let adrIndex = try recordIndex("adrs.index.json", expectedID: "adrs")
        let chapterIndex = try recordIndex("chapters.index.json", expectedID: "chapters")
        let derivedIndex = try canonicalRecord(
            CanonDerivedArtifactIndex.self,
            path: "registry/derived-artifacts.index.json",
            expectedDigest: nil
        )
        guard derivedIndex.id == "derived-artifacts" else {
            throw invalid("resolved derived index has the wrong identity")
        }

        let rules: [RuleRecord] = try records(
            ruleIndex,
            prefix: "rules/",
            identifier: { $0.id.rawValue }
        )
        let profiles: [ProfileRecord] = try records(
            profileIndex,
            prefix: "profiles/",
            identifier: { $0.id.rawValue }
        )
        try validateProfileInheritanceClosure(profiles)
        let adrs = try loadADRs(adrIndex)
        let chapters: [ChapterMetadata] = try records(
            chapterIndex,
            prefix: "chapters/",
            identifier: { $0.id }
        )
        let requirementRegistry = try canonicalRecord(
            RequirementRegistry.self,
            path: "registry/requirements.v1.json",
            expectedDigest: nil
        )
        try resolveChapterDependencies(
            chapters,
            rules: rules,
            requirementRegistry: requirementRegistry
        )
        return CanonSnapshot(
            canonVersion: 1,
            rules: rules,
            profiles: profiles,
            selectedProfileIDs: profiles.map(\.id),
            adrs: adrs.records,
            adrMarkdownByID: adrs.markdownByID,
            chapters: chapters,
            requirementRegistry: requirementRegistry,
            derivedArtifacts: derivedIndex.entries,
            snapshotContentDigest: snapshotContentDigest
        )
    }

    private func recordIndex(
        _ filename: String,
        expectedID: String
    ) throws -> CanonRecordIndex {
        let index = try canonicalRecord(
            CanonRecordIndex.self,
            path: "registry/" + filename,
            expectedDigest: nil
        )
        guard index.id == expectedID else {
            throw invalid("resolved index \(filename) has the wrong identity")
        }
        return index
    }

    private func validateProfileInheritanceClosure(
        _ profiles: [ProfileRecord]
    ) throws {
        let profilesByID = Dictionary(
            uniqueKeysWithValues: profiles.map { ($0.id, $0) }
        )
        for root in profiles.sorted(by: {
            canonicalLess($0.id.rawValue, $1.id.rawValue)
        }) {
            var visited: Set<ProfileID> = [root.id]
            var pending = Array(root.inheritsProfileIDs.sorted(by: {
                canonicalLess($0.rawValue, $1.rawValue)
            }).reversed())
            while let inheritedID = pending.popLast() {
                guard let inherited = profilesByID[inheritedID] else {
                    throw ContractError.unresolvedReference(
                        kind: "inherited profile",
                        id: inheritedID.rawValue
                    )
                }
                guard visited.insert(inheritedID).inserted else { continue }
                pending.append(contentsOf: inherited.inheritsProfileIDs.sorted(by: {
                    canonicalLess($0.rawValue, $1.rawValue)
                }).reversed())
            }
        }
    }

    private func records<Value: Codable>(
        _ index: CanonRecordIndex,
        prefix: String,
        identifier: (Value) -> String
    ) throws -> [Value] {
        try index.entries.map { entry in
            guard entry.relativePath.rawValue.hasPrefix(prefix),
                  entry.relativePath.rawValue.hasSuffix(".json")
            else {
                throw invalid("resolved index entry has the wrong record family")
            }
            let record = try canonicalRecord(
                Value.self,
                path: entry.relativePath.rawValue,
                expectedDigest: entry.recordDigest
            )
            guard identifier(record) == entry.id else {
                throw invalid("resolved index ID differs from its decoded record")
            }
            return record
        }
    }

    private func loadADRs(
        _ index: CanonRecordIndex
    ) throws -> (records: [ADRMetadata], markdownByID: [ADRIdentifier: String]) {
        var records: [ADRMetadata] = []
        var markdownByID: [ADRIdentifier: String] = [:]
        for entry in index.entries {
            guard entry.relativePath.rawValue.hasPrefix("adrs/"),
                  entry.relativePath.rawValue.hasSuffix(".json")
            else {
                throw invalid("resolved ADR index path has the wrong record family")
            }
            let metadata = try canonicalRecord(
                ADRMetadata.self,
                path: entry.relativePath.rawValue,
                expectedDigest: entry.recordDigest
            )
            guard metadata.id.rawValue == entry.id else {
                throw invalid("resolved ADR index ID differs from its metadata")
            }
            let markdownPath = String(
                entry.relativePath.rawValue.dropLast(".json".count)
            ) + ".md"
            guard metadata.referenceArtifactIDs.contains(markdownPath) else {
                throw invalid("resolved ADR metadata omits its Markdown sidecar")
            }
            var markdownData: Data?
            for reference in metadata.referenceArtifactIDs {
                let data = try readFile(
                    reference,
                    expectedDigest: reference == markdownPath
                        ? metadata.markdownDigest
                        : nil
                )
                if reference == markdownPath {
                    markdownData = data
                }
            }
            guard let markdownData,
                  let markdown = String(data: markdownData, encoding: .utf8),
                  markdownByID.updateValue(markdown, forKey: metadata.id) == nil
            else {
                throw invalid("resolved ADR Markdown is missing, duplicated, or not UTF-8")
            }
            records.append(metadata)
        }
        return (records, markdownByID)
    }

    private func canonicalRecord<Value: Codable>(
        _ type: Value.Type,
        path: String,
        expectedDigest: HashDigest?
    ) throws -> Value {
        let data = try readFile(path, expectedDigest: expectedDigest)
        let value = try CanonicalJSON.decode(type, from: data)
        var canonical = try CanonicalJSON.encode(value)
        canonical.append(0x0A)
        guard canonical == data else {
            throw invalid("resolved Canon record is not canonical file data: \(path)")
        }
        return value
    }

    private func readFile(
        _ path: String,
        expectedDigest: HashDigest?
    ) throws -> Data {
        guard let entry = inventory.entries.first(where: {
            $0.relativePath == path && $0.kind == .regularFile
        }),
            let inventoryDigest = entry.contentSHA256,
            let data = fileBytesByRelativePath[path]
        else {
            throw ContractError.unresolvedReference(kind: "resolved canon file", id: path)
        }
        let actual = CanonicalTreeDigest.sha256(data)
        guard actual == inventoryDigest else {
            throw ContractError.digestMismatch(
                kind: "resolved canon inventory file",
                expected: inventoryDigest.rawValue,
                actual: actual.rawValue
            )
        }
        if let expectedDigest, expectedDigest != actual {
            throw ContractError.digestMismatch(
                kind: "resolved canon indexed record",
                expected: expectedDigest.rawValue,
                actual: actual.rawValue
            )
        }
        return data
    }

    private func resolveChapterDependencies(
        _ chapters: [ChapterMetadata],
        rules: [RuleRecord],
        requirementRegistry: RequirementRegistry
    ) throws {
        let activeRuleIDs = Set(rules.lazy.filter { $0.lifecycle == .active }.map(\.id))
        var owners: [RuleID: String] = [:]
        for binding in requirementRegistry.traceability.flatMap(\.ruleBindings)
            where activeRuleIDs.contains(binding.ruleID)
        {
            if let existing = owners[binding.ruleID], existing != binding.ownerRoleID {
                throw invalid("resolved active Rule has conflicting owner bindings")
            }
            owners[binding.ruleID] = binding.ownerRoleID
        }
        let context = ChapterDependencyContext.production(activeRuleOwners: owners)
        for dependency in chapters.flatMap(\.requiredRuleDependencies) {
            _ = try dependency.resolve(in: context)
        }
    }

    private func invalid(_ reason: String) -> ContractError {
        ContractError.invalidContract(
            kind: "candidate_overlay_resolution",
            reason: reason
        )
    }

    private func canonicalLess(_ lhs: String, _ rhs: String) -> Bool {
        lhs.utf8.lexicographicallyPrecedes(rhs.utf8)
    }
}

private struct ResolvedCandidateFileDigestWire: Encodable {
    let relativePath: String
    let contentDigest: HashDigest
    let mode: UInt16

    private enum CodingKeys: String, CodingKey {
        case relativePath = "relative_path"
        case contentDigest = "content_digest"
        case mode
    }
}

private struct ResolvedApprovalDigestWire: Encodable {
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

private struct ResolvedOutputFileDigestWire: Encodable {
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

private struct ResolvedOutputDirectoryDigestWire: Encodable {
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

private struct ResolvedActivationDigestPayload: Encodable {
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
    let candidateFiles: [ResolvedCandidateFileDigestWire]
    let approval: ResolvedApprovalDigestWire
    let outputFiles: [ResolvedOutputFileDigestWire]
    let outputDirectories: [ResolvedOutputDirectoryDigestWire]
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
