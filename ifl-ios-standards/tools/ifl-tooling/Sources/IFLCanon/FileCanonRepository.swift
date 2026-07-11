import Foundation
import IFLContracts

public struct FileCanonRepository: CanonRepository, Sendable {
    private let source: CanonRepositorySource
    private let readEventHandler: CanonRepositoryReadEventHandler

    public init(root: URL) {
        source = .url(root)
        readEventHandler = { _ in }
    }

    init(
        root: URL,
        readEventHandler: @escaping CanonRepositoryReadEventHandler
    ) {
        source = .url(root)
        self.readEventHandler = readEventHandler
    }

    package init(anchor: CanonRootAnchor) {
        source = .anchor(anchor)
        readEventHandler = { _ in }
    }

    package init(
        anchor: CanonRootAnchor,
        readEventHandler: @escaping CanonRepositoryReadEventHandler
    ) {
        source = .anchor(anchor)
        self.readEventHandler = readEventHandler
    }

    public func snapshot(profiles requestedProfiles: Set<ProfileID>) throws -> CanonSnapshot {
        do {
            let loader: CanonFileLoader = switch source {
            case let .url(root):
                try CanonFileLoader(root: root, readEventHandler: readEventHandler)
            case let .anchor(anchor):
                try CanonFileLoader(
                    rootDescriptor: anchor.duplicateRootDescriptor(),
                    readEventHandler: readEventHandler
                )
            }
            return try loader.loadSnapshot(requestedProfiles: requestedProfiles)
        } catch let failure as CanonDescriptorFailure {
            switch source {
            case .anchor:
                throw failure
            case .url:
                guard case let .integrityViolation(reason) = failure else {
                    throw failure
                }
                throw ContractError.invalidContract(
                    kind: "canon_repository",
                    reason: reason
                )
            }
        }
    }
}

private enum CanonRepositorySource {
    case url(URL)
    case anchor(CanonRootAnchor)
}

private struct CanonFileLoader {
    private let descriptorReader: CanonDescriptorReader
    private let inventory: CanonicalTreeInventory
    private let inventoryDigest: HashDigest
    private let entriesByPath: [String: CanonicalTreeEntry]
    private let snapshotContentDigest: HashDigest

    init(
        root: URL,
        readEventHandler: @escaping CanonRepositoryReadEventHandler
    ) throws {
        let standardizedRoot = root.standardizedFileURL
        try self.init(descriptorReader: CanonDescriptorReader(
            root: standardizedRoot,
            eventHandler: readEventHandler
        ))
    }

    init(
        rootDescriptor: CanonRootDescriptor,
        readEventHandler: @escaping CanonRepositoryReadEventHandler
    ) throws {
        try self.init(descriptorReader: CanonDescriptorReader(
            rootDescriptor: rootDescriptor,
            eventHandler: readEventHandler
        ))
    }

    private init(descriptorReader: CanonDescriptorReader) throws {
        let policy = try CanonicalTreePolicy(excludedRoots: [])
        let inventory = try descriptorReader.scan(policy: policy)
        try descriptorReader.validateRoot()
        var entriesByPath: [String: CanonicalTreeEntry] = [:]
        entriesByPath.reserveCapacity(inventory.entries.count)
        for entry in inventory.entries {
            guard entriesByPath.updateValue(entry, forKey: entry.relativePath) == nil else {
                throw ContractError.duplicateIdentifier(
                    kind: "canon inventory path",
                    id: entry.relativePath
                )
            }
        }

        self.descriptorReader = descriptorReader
        self.inventory = inventory
        inventoryDigest = try CanonicalTreeDigest.digest(inventory)
        self.entriesByPath = entriesByPath
        snapshotContentDigest = try CanonSnapshotContentPolicy.digest(of: inventory)
    }

    func loadSnapshot(requestedProfiles: Set<ProfileID>) throws -> CanonSnapshot {
        let canonVersion = try loadCanonVersion()

        // The repository authority is the five required indexes. Load and validate all of
        // them before following a single record path.
        let ruleIndex = try loadIndex(filename: "rules.index.json", expectedID: "rules")
        let profileIndex = try loadIndex(filename: "profiles.index.json", expectedID: "profiles")
        let adrIndex = try loadIndex(filename: "adrs.index.json", expectedID: "adrs")
        let chapterIndex = try loadIndex(filename: "chapters.index.json", expectedID: "chapters")
        let derivedIndex = try loadDerivedArtifactIndex()

        let rules: [RuleRecord] = try loadRecords(
            from: ruleIndex,
            pathPrefix: "rules/",
            kind: "rule_record",
            identifier: { $0.id.rawValue }
        )
        let profiles: [ProfileRecord] = try loadRecords(
            from: profileIndex,
            pathPrefix: "profiles/",
            kind: "profile_record",
            identifier: { $0.id.rawValue }
        )
        let selectedProfileIDs = try resolveSelectedProfileIDs(
            requestedProfiles,
            available: profiles
        )

        let loadedADRs = try loadADRs(from: adrIndex)
        let chapters: [ChapterMetadata] = try loadRecords(
            from: chapterIndex,
            pathPrefix: "chapters/",
            kind: "chapter_metadata",
            identifier: { $0.id }
        )
        let requirementRegistry = try loadCanonicalRecord(
            RequirementRegistry.self,
            relativePath: "registry/requirements.v1.json",
            expectedDigest: nil,
            kind: "requirement_registry"
        )
        try resolveProductionChapterDependencies(
            chapters,
            rules: rules,
            requirementRegistry: requirementRegistry
        )
        try confirmInventoryIsStable()

        return CanonSnapshot(
            canonVersion: canonVersion,
            rules: rules,
            profiles: profiles,
            selectedProfileIDs: selectedProfileIDs,
            adrs: loadedADRs.records,
            adrMarkdownByID: loadedADRs.markdownByID,
            chapters: chapters,
            requirementRegistry: requirementRegistry,
            derivedArtifacts: derivedIndex.entries,
            snapshotContentDigest: snapshotContentDigest
        )
    }

    private func loadCanonVersion() throws -> Int {
        let data = try readFile(relativePath: "VERSION", expectedDigest: nil)
        guard data == Data([0x31, 0x0A]) else {
            throw ContractError.invalidCanonVersion(String(decoding: data, as: UTF8.self))
        }
        return 1
    }

    private func loadIndex(filename: String, expectedID: String) throws -> CanonRecordIndex {
        let relativePath = "registry/\(filename)"
        let index = try loadCanonicalRecord(
            CanonRecordIndex.self,
            relativePath: relativePath,
            expectedDigest: nil,
            kind: "canon_record_index"
        )
        guard index.id == expectedID else {
            throw ContractError.invalidContract(
                kind: "canon_record_index",
                reason: "\(relativePath) id must be \(expectedID)"
            )
        }
        return index
    }

    private func loadDerivedArtifactIndex() throws -> CanonDerivedArtifactIndex {
        let relativePath = "registry/derived-artifacts.index.json"
        let index = try loadCanonicalRecord(
            CanonDerivedArtifactIndex.self,
            relativePath: relativePath,
            expectedDigest: nil,
            kind: "canon_derived_artifact_index"
        )
        guard index.id == "derived-artifacts" else {
            throw ContractError.invalidContract(
                kind: "canon_derived_artifact_index",
                reason: "\(relativePath) id must be derived-artifacts"
            )
        }
        return index
    }

    private func loadRecords<Record: Codable>(
        from index: CanonRecordIndex,
        pathPrefix: String,
        kind: String,
        identifier: (Record) -> String
    ) throws -> [Record] {
        try index.entries.map { entry in
            try validateRecordPath(entry.relativePath, prefix: pathPrefix, kind: kind)
            let record = try loadCanonicalRecord(
                Record.self,
                relativePath: entry.relativePath.rawValue,
                expectedDigest: entry.recordDigest,
                kind: kind
            )
            guard identifier(record) == entry.id else {
                throw ContractError.invalidContract(
                    kind: kind,
                    reason: "index id \(entry.id) does not match record id \(identifier(record))"
                )
            }
            return record
        }
    }

    private func loadADRs(from index: CanonRecordIndex) throws -> LoadedADRs {
        var records: [ADRMetadata] = []
        var markdownByID: [ADRIdentifier: String] = [:]
        records.reserveCapacity(index.entries.count)
        markdownByID.reserveCapacity(index.entries.count)

        for entry in index.entries {
            try validateRecordPath(entry.relativePath, prefix: "adrs/", kind: "adr_metadata")
            let adr = try loadCanonicalRecord(
                ADRMetadata.self,
                relativePath: entry.relativePath.rawValue,
                expectedDigest: entry.recordDigest,
                kind: "adr_metadata"
            )
            guard adr.id.rawValue == entry.id else {
                throw ContractError.invalidContract(
                    kind: "adr_metadata",
                    reason: "index id \(entry.id) does not match record id \(adr.id.rawValue)"
                )
            }
            let markdown = try validateADRMarkdown(adr, metadataPath: entry.relativePath)
            guard markdownByID.updateValue(markdown, forKey: adr.id) == nil else {
                throw ContractError.duplicateIdentifier(kind: "ADR Markdown", id: adr.id.rawValue)
            }
            records.append(adr)
        }
        return LoadedADRs(records: records, markdownByID: markdownByID)
    }

    private func validateADRMarkdown(
        _ adr: ADRMetadata,
        metadataPath: CanonicalRelativePath
    ) throws -> String {
        let metadata = metadataPath.rawValue
        let markdownPath = String(metadata.dropLast(".json".count)) + ".md"
        guard adr.referenceArtifactIDs.contains(markdownPath) else {
            throw ContractError.invalidContract(
                kind: "adr_metadata",
                reason: "reference_artifact_ids must contain sidecar \(markdownPath)"
            )
        }

        var markdownData: Data?
        for reference in adr.referenceArtifactIDs {
            let canonicalReference: CanonicalRelativePath
            do {
                canonicalReference = try CanonicalRelativePath(validating: reference)
            } catch {
                throw ContractError.invalidContract(
                    kind: "adr_metadata",
                    reason: "reference artifact path must be confined and canonical"
                )
            }
            let data = try readFile(
                relativePath: canonicalReference.rawValue,
                expectedDigest: canonicalReference.rawValue == markdownPath
                    ? adr.markdownDigest
                    : nil
            )
            if canonicalReference.rawValue == markdownPath {
                markdownData = data
            }
        }
        guard let markdownData else {
            throw ContractError.unresolvedReference(kind: "ADR Markdown", id: markdownPath)
        }
        guard let markdown = String(data: markdownData, encoding: .utf8) else {
            throw ContractError.invalidContract(
                kind: "adr_metadata",
                reason: "ADR Markdown must be valid UTF-8"
            )
        }
        return markdown
    }

    private func loadCanonicalRecord<Record: Codable>(
        _ type: Record.Type,
        relativePath: String,
        expectedDigest: HashDigest?,
        kind: String
    ) throws -> Record {
        let data = try readFile(relativePath: relativePath, expectedDigest: expectedDigest)
        let record: Record
        do {
            record = try CanonicalJSON.decode(type, from: data)
        } catch let error as ContractError {
            throw error
        } catch {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "\(relativePath) cannot be decoded as its declared contract"
            )
        }

        var canonical = try CanonicalJSON.encode(record)
        canonical.append(0x0A)
        guard canonical == data else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "\(relativePath) must use canonical JSON bytes"
            )
        }
        return record
    }

    private func readFile(
        relativePath rawRelativePath: String,
        expectedDigest: HashDigest?
    ) throws -> Data {
        let relativePath: CanonicalRelativePath
        do {
            relativePath = try CanonicalRelativePath(validating: rawRelativePath)
        } catch {
            throw ContractError.invalidContract(
                kind: "canon_repository",
                reason: "file path must be confined and canonical"
            )
        }

        guard let inventoryEntry = entriesByPath[relativePath.rawValue],
              inventoryEntry.kind == .regularFile,
              let inventoryDigest = inventoryEntry.contentSHA256
        else {
            throw ContractError.unresolvedReference(
                kind: "canon file",
                id: relativePath.rawValue
            )
        }

        let data = try descriptorReader.read(relativePath: relativePath)
        let actualDigest = CanonicalTreeDigest.sha256(data)
        guard actualDigest == inventoryDigest else {
            throw ContractError.digestMismatch(
                kind: "canon inventory file",
                expected: inventoryDigest.rawValue,
                actual: actualDigest.rawValue
            )
        }
        if let expectedDigest, actualDigest != expectedDigest {
            throw ContractError.digestMismatch(
                kind: "canon indexed record",
                expected: expectedDigest.rawValue,
                actual: actualDigest.rawValue
            )
        }
        return data
    }

    private func validateRecordPath(
        _ relativePath: CanonicalRelativePath,
        prefix: String,
        kind: String
    ) throws {
        guard relativePath.rawValue.hasPrefix(prefix),
              relativePath.rawValue.hasSuffix(".json")
        else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "index path must be a JSON record below \(prefix)"
            )
        }
    }

    private func resolveSelectedProfileIDs(
        _ requestedProfiles: Set<ProfileID>,
        available profiles: [ProfileRecord]
    ) throws -> [ProfileID] {
        let profilesByID = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        for profile in profiles.sorted(by: { Self.canonicalLess($0.id, $1.id) }) {
            for inheritedID in profile.inheritsProfileIDs.sorted(by: Self.canonicalLess) {
                _ = try requireProfile(inheritedID, in: profilesByID)
            }
        }

        let availableIDs = Set(profilesByID.keys)
        let missing = requestedProfiles
            .filter { !availableIDs.contains($0) }
            .sorted(by: Self.canonicalLess)
        if let missingProfile = missing.first {
            throw ContractError.unresolvedReference(
                kind: "requested profile",
                id: missingProfile.rawValue
            )
        }

        guard !requestedProfiles.isEmpty else {
            return profiles.map(\.id)
        }

        var selected = requestedProfiles
        var pending = Array(requestedProfiles)
        while let profileID = pending.popLast() {
            let profile = try requireProfile(profileID, in: profilesByID)
            for inheritedID in profile.inheritsProfileIDs where selected.insert(inheritedID).inserted {
                _ = try requireProfile(inheritedID, in: profilesByID)
                pending.append(inheritedID)
            }
        }
        return profiles.map(\.id).filter(selected.contains)
    }

    private static func canonicalLess(_ lhs: ProfileID, _ rhs: ProfileID) -> Bool {
        lhs.rawValue.utf8.lexicographicallyPrecedes(rhs.rawValue.utf8)
    }

    private func requireProfile(
        _ id: ProfileID,
        in profilesByID: [ProfileID: ProfileRecord]
    ) throws -> ProfileRecord {
        guard let profile = profilesByID[id] else {
            throw ContractError.unresolvedReference(
                kind: "inherited profile",
                id: id.rawValue
            )
        }
        return profile
    }

    private func resolveProductionChapterDependencies(
        _ chapters: [ChapterMetadata],
        rules: [RuleRecord],
        requirementRegistry: RequirementRegistry
    ) throws {
        let activeRuleIDs = Set(
            rules.lazy.filter { $0.lifecycle == .active }.map(\.id)
        )
        var activeRuleOwners: [RuleID: String] = [:]
        for binding in requirementRegistry.traceability.flatMap(\.ruleBindings)
            where activeRuleIDs.contains(binding.ruleID)
        {
            if let existing = activeRuleOwners[binding.ruleID], existing != binding.ownerRoleID {
                throw ContractError.invalidContract(
                    kind: "rule_owner_binding",
                    reason: "active rule \(binding.ruleID.rawValue) has conflicting owners"
                )
            }
            activeRuleOwners[binding.ruleID] = binding.ownerRoleID
        }

        let context = ChapterDependencyContext.production(activeRuleOwners: activeRuleOwners)
        for dependency in chapters.flatMap(\.requiredRuleDependencies) {
            _ = try dependency.resolve(in: context)
        }
    }

    private func confirmInventoryIsStable() throws {
        let finalInventory = try descriptorReader.scan(
            policy: CanonicalTreePolicy(excludedRoots: [])
        )
        guard finalInventory == inventory else {
            let finalDigest = try CanonicalTreeDigest.digest(finalInventory)
            throw ContractError.digestMismatch(
                kind: "canon snapshot",
                expected: inventoryDigest.rawValue,
                actual: finalDigest.rawValue
            )
        }
        try descriptorReader.validateRoot()
    }
}

private struct LoadedADRs {
    let records: [ADRMetadata]
    let markdownByID: [ADRIdentifier: String]
}

package extension CanonSnapshot {
    func selectingProfiles(_ requestedProfiles: Set<ProfileID>) throws -> CanonSnapshot {
        guard !requestedProfiles.isEmpty else { return self }

        let profilesByID = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        let missing = requestedProfiles
            .filter { profilesByID[$0] == nil }
            .sorted { $0.rawValue.utf8.lexicographicallyPrecedes($1.rawValue.utf8) }
        if let missingProfile = missing.first {
            throw ContractError.unresolvedReference(
                kind: "requested profile",
                id: missingProfile.rawValue
            )
        }

        var selected = requestedProfiles
        var pending = Array(requestedProfiles)
        while let profileID = pending.popLast() {
            guard let profile = profilesByID[profileID] else {
                throw ContractError.unresolvedReference(
                    kind: "requested profile",
                    id: profileID.rawValue
                )
            }
            for inheritedID in profile.inheritsProfileIDs where selected.insert(inheritedID).inserted {
                guard profilesByID[inheritedID] != nil else {
                    throw ContractError.unresolvedReference(
                        kind: "inherited profile",
                        id: inheritedID.rawValue
                    )
                }
                pending.append(inheritedID)
            }
        }

        return CanonSnapshot(
            canonVersion: canonVersion,
            rules: rules,
            profiles: profiles,
            selectedProfileIDs: profiles.map(\.id).filter(selected.contains),
            adrs: adrs,
            adrMarkdownByID: adrMarkdownByID,
            chapters: chapters,
            requirementRegistry: requirementRegistry,
            derivedArtifacts: derivedArtifacts,
            snapshotContentDigest: snapshotContentDigest
        )
    }
}
