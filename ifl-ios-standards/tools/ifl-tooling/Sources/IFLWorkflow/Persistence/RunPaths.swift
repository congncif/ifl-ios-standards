import Foundation
import IFLContracts

public struct RunPaths: Hashable, Sendable {
    public let workItemRoot: URL
    public let runID: RunID
    public let runRoot: URL
    public let stateURL: URL
    public let eventLogURL: URL
    public let journalURL: URL
    public let lockURL: URL
    public let receiptsRootURL: URL
    public let durabilityAnchorURL: URL
    let identityRecordURL: URL
    let epochsRootURL: URL
    let runRootIdentity: DescriptorObjectMetadata
    let durabilityAnchorIdentity: DescriptorObjectMetadata
    let lockIdentity: DescriptorEntryIdentity
    let runIdentityDigest: HashDigest

    private init(
        workItemRoot: URL,
        runID: RunID,
        runRootIdentity: DescriptorObjectMetadata? = nil,
        durabilityAnchorIdentity: DescriptorObjectMetadata? = nil,
        lockIdentity: DescriptorEntryIdentity? = nil,
        runIdentityDigest: HashDigest? = nil
    ) {
        self.workItemRoot = workItemRoot.standardizedFileURL
        self.runID = runID
        runRoot = workItemRoot.standardizedFileURL
            .appendingPathComponent("artifacts", isDirectory: true)
            .appendingPathComponent("workflow", isDirectory: true)
            .appendingPathComponent("runs", isDirectory: true)
            .appendingPathComponent(runID.filesystemComponent, isDirectory: true)
        stateURL = runRoot.appendingPathComponent("state.json", isDirectory: false)
        eventLogURL = runRoot.appendingPathComponent("events.ndjson", isDirectory: false)
        journalURL = runRoot.appendingPathComponent("commit-journal.json", isDirectory: false)
        lockURL = runRoot.appendingPathComponent("writer.lock", isDirectory: false)
        receiptsRootURL = runRoot.appendingPathComponent("receipts", isDirectory: true)
        durabilityAnchorURL = runRoot.appendingPathComponent(
            ".durability-anchor",
            isDirectory: false
        )
        identityRecordURL = runRoot.appendingPathComponent(
            ".run-identity.json",
            isDirectory: false
        )
        epochsRootURL = runRoot.appendingPathComponent("epochs", isDirectory: true)
        self.runRootIdentity = runRootIdentity ?? .invalidSentinel
        self.durabilityAnchorIdentity = durabilityAnchorIdentity ?? .invalidSentinel
        self.lockIdentity = lockIdentity ?? DescriptorEntryIdentity(metadata: .invalidSentinel)
        self.runIdentityDigest = runIdentityDigest
            ?? CanonicalTreeDigest.sha256(Data("unprepared-run-paths".utf8))
    }

    public static func prepare(workItemRoot: URL, runID: RunID) throws -> RunPaths {
        try prepareForTesting(
            workItemRoot: workItemRoot,
            runID: runID,
            barrier: DarwinDurabilityBarrier()
        )
    }

    static func prepareForTesting(
        workItemRoot: URL,
        runID: RunID,
        barrier: any WorkflowDurabilityBarrier,
        bootstrapHook: @escaping (Int) throws -> Void = { _ in }
    ) throws -> RunPaths {
        let draft = RunPaths(workItemRoot: workItemRoot, runID: runID)
        let fileSystem = try DescriptorRelativeFileSystem(rootURL: draft.workItemRoot)
        let trustedRoot = try fileSystem.rootDirectory()
        try barrier.validateCapability(in: trustedRoot.fd)

        let components = ["artifacts", "workflow", "runs", runID.filesystemComponent]
        let prefix = bootstrapAuthorityPrefix(runID: runID)
        let phaseNames = try existingBootstrapPhaseNames(
            prefix: prefix,
            fileSystem: fileSystem
        )
        if phaseNames.isEmpty {
            do {
                _ = try fileSystem.openDirectory(components, requiredMode: 0o700)
                throw PersistenceError.integrityViolation
            } catch let error as PersistenceError where error == .ioFailure(ENOENT) {
                // A target run root must be absent before this lifecycle becomes authoritative.
            }
        }

        let lifecycleID: String
        var chain: [BootstrapObjectIdentity]
        var retainedDirectories: [DescriptorRelativeDirectory] = [trustedRoot]
        if phaseNames.isEmpty {
            lifecycleID = UUID().uuidString.lowercased()
            chain = [BootstrapObjectIdentity(trustedRoot.metadata)]
            let phase = BootstrapAuthorityRecord(
                runID: runID,
                lifecycleID: lifecycleID,
                phase: 0,
                chain: chain
            )
            let phaseFile = try createBootstrapPhase(
                phase,
                prefix: prefix,
                fileSystem: fileSystem
            )
            try barrier.synchronize(
                DurabilityPlan(
                    modified: [
                        .init(directory: trustedRoot),
                        .init(file: phaseFile, requiredPermissions: 0o600),
                    ],
                    requiredDirectoryFDs: [trustedRoot.fd],
                    anchorFD: phaseFile.fd,
                    purpose: .bootstrapIdentity
                )
            )
        } else {
            let first = try readBootstrapPhase(
                phase: 0,
                prefix: prefix,
                fileSystem: fileSystem
            )
            try first.validate(
                runID: runID,
                phase: 0,
                chain: [BootstrapObjectIdentity(trustedRoot.metadata)]
            )
            lifecycleID = first.lifecycleID
            chain = first.chain
            let phaseFile = try fileSystem.openFile(
                named: bootstrapPhaseName(prefix: prefix, phase: 0),
                in: []
            )
            try barrier.synchronize(
                DurabilityPlan(
                    modified: [
                        .init(directory: trustedRoot),
                        .init(file: phaseFile, requiredPermissions: 0o600),
                    ],
                    requiredDirectoryFDs: [trustedRoot.fd],
                    anchorFD: phaseFile.fd,
                    purpose: .bootstrapIdentity
                )
            )
        }

        let completedComponents = min(phaseNames.max() ?? 0, components.count)
        var current = trustedRoot
        if completedComponents > 0 {
            for index in 0..<completedComponents {
                let child = try fileSystem.openDirectory(
                    components[index],
                    in: current,
                    requiredMode: 0o700
                )
                retainedDirectories.append(child)
                let record = try readBootstrapPhase(
                    phase: index + 1,
                    prefix: prefix,
                    fileSystem: fileSystem
                )
                let expectedChain = retainedDirectories.map {
                    BootstrapObjectIdentity($0.metadata)
                }
                try record.validate(
                    runID: runID,
                    lifecycleID: lifecycleID,
                    phase: index + 1,
                    chain: expectedChain
                )
                let phaseFile = try fileSystem.openFile(
                    named: bootstrapPhaseName(prefix: prefix, phase: index + 1),
                    in: []
                )
                try barrier.synchronize(
                    DurabilityPlan(
                        modified: [
                            .init(directory: current),
                            .init(directory: child, requiredPermissions: 0o700),
                            .init(file: phaseFile, requiredPermissions: 0o600),
                        ],
                        requiredDirectoryFDs: [current.fd, child.fd],
                        anchorFD: phaseFile.fd,
                        purpose: .bootstrapComponent
                    )
                )
                current = child
                chain = expectedChain
            }
        }

        if completedComponents < components.count {
            for index in completedComponents..<components.count {
                try fileSystem.validateRetainedDirectory(current)
                let creation = try fileSystem.ensureDirectory(
                    components[index],
                    in: current,
                    mode: 0o700
                )
                retainedDirectories.append(creation.child)
                chain = retainedDirectories.map { BootstrapObjectIdentity($0.metadata) }
                let phase = BootstrapAuthorityRecord(
                    runID: runID,
                    lifecycleID: lifecycleID,
                    phase: index + 1,
                    chain: chain
                )
                let phaseFile = try createBootstrapPhase(
                    phase,
                    prefix: prefix,
                    fileSystem: fileSystem
                )
                try barrier.synchronize(
                    DurabilityPlan(
                        modified: [
                            .init(directory: creation.parent),
                            .init(directory: creation.child, requiredPermissions: 0o700),
                            .init(file: phaseFile, requiredPermissions: 0o600),
                        ],
                        requiredDirectoryFDs: [creation.parent.fd, creation.child.fd],
                        anchorFD: phaseFile.fd,
                        purpose: .bootstrapComponent
                    )
                )
                try bootstrapHook(index + 1)
                try fileSystem.validateRetainedDirectory(
                    creation.child,
                    requiredMode: 0o700
                )
                current = creation.child
            }
        }

        let runDirectory = current
        let runParent = try require(runDirectory.parent)
        try fileSystem.validateRetainedDirectory(runDirectory, requiredMode: 0o700)
        let anchor = try prepareFixedFile(
            named: ".durability-anchor",
            bytes: Data("ifl-workflow-durability-anchor-v1\n".utf8),
            components: components,
            fileSystem: fileSystem
        )
        let lock = try prepareFixedFile(
            named: "writer.lock",
            bytes: Data(),
            components: components,
            fileSystem: fileSystem
        )
        let epochs = try fileSystem.ensureDirectory("epochs", in: runDirectory, mode: 0o700)

        let identityName = ".run-identity.json"
        let identityRecord = DurableRunIdentity(
            runID: runID,
            lifecycleID: lifecycleID,
            ancestorChain: chain,
            runRoot: runDirectory.metadata,
            anchor: anchor.metadata,
            lock: lock.metadata
        )
        let identityBytes = try CanonicalJSON.encode(identityRecord)
        let identityFile: DescriptorRelativeFile
        if let existing = try fileSystem.readFileIfPresent(named: identityName, in: components) {
            guard existing == identityBytes else { throw PersistenceError.integrityViolation }
            identityFile = try fileSystem.openFile(named: identityName, in: components)
        } else {
            identityFile = try fileSystem.createFile(
                data: identityBytes,
                named: identityName,
                in: components,
                mode: 0o600
            )
        }
        try identityRecord.validate(
            runID: runID,
            lifecycleID: lifecycleID,
            ancestorChain: chain,
            runRoot: runDirectory.metadata,
            anchor: anchor.metadata,
            lock: lock.metadata
        )

        let finalPhase = BootstrapAuthorityRecord(
            runID: runID,
            lifecycleID: lifecycleID,
            phase: components.count + 1,
            chain: chain,
            runIdentityDigest: CanonicalTreeDigest.sha256(identityBytes),
            anchor: BootstrapObjectIdentity(anchor.metadata),
            lock: BootstrapObjectIdentity(lock.metadata)
        )
        let finalPhaseName = bootstrapPhaseName(
            prefix: prefix,
            phase: components.count + 1
        )
        let finalPhaseFile: DescriptorRelativeFile
        if let existing = try fileSystem.readFileIfPresent(named: finalPhaseName, in: []) {
            let decoded = try decodeBootstrapPhase(existing)
            guard decoded == finalPhase else { throw PersistenceError.integrityViolation }
            finalPhaseFile = try fileSystem.openFile(named: finalPhaseName, in: [])
        } else {
            finalPhaseFile = try createBootstrapPhase(
                finalPhase,
                prefix: prefix,
                fileSystem: fileSystem
            )
        }
        let observedPhases = try existingBootstrapPhaseNames(
            prefix: prefix,
            fileSystem: fileSystem
        )
        guard observedPhases == Set(0...(components.count + 1)) else {
            throw PersistenceError.integrityViolation
        }
        try barrier.synchronize(
            DurabilityPlan(
                modified: [
                    .init(directory: trustedRoot),
                    .init(directory: runParent, requiredPermissions: 0o700),
                    .init(directory: runDirectory, requiredPermissions: 0o700),
                    .init(directory: epochs.child, requiredPermissions: 0o700),
                    .init(file: identityFile, requiredPermissions: 0o600),
                    .init(file: finalPhaseFile, requiredPermissions: 0o600),
                    .init(file: anchor, requiredPermissions: 0o600),
                    .init(file: lock, requiredPermissions: 0o600),
                ],
                requiredDirectoryFDs: [
                    trustedRoot.fd, runParent.fd, runDirectory.fd, epochs.child.fd,
                ],
                anchorFD: anchor.fd,
                purpose: .bootstrapIdentity
            )
        )
        try fileSystem.validateRetainedDirectory(runDirectory, requiredMode: 0o700)

        return RunPaths(
            workItemRoot: workItemRoot,
            runID: runID,
            runRootIdentity: runDirectory.metadata,
            durabilityAnchorIdentity: anchor.metadata,
            lockIdentity: DescriptorEntryIdentity(metadata: lock.metadata),
            runIdentityDigest: CanonicalTreeDigest.sha256(identityBytes)
        )
    }

    public func receiptURL(kind: ReceiptKind, id: ReceiptID) throws -> URL {
        receiptsRootURL
            .appendingPathComponent(kind.rawValue, isDirectory: true)
            .appendingPathComponent(try receiptFilename(id: id), isDirectory: false)
    }

    func receiptProvenanceURL(kind: ReceiptKind?) -> URL {
        let parent = kind.map {
            receiptsRootURL.appendingPathComponent($0.rawValue, isDirectory: true)
        } ?? receiptsRootURL
        return parent.appendingPathComponent(".parent-provenance.json", isDirectory: false)
    }

    func epochURL(for transactionDigest: HashDigest) -> URL {
        epochsRootURL.appendingPathComponent(
            "\(transactionDigest.rawValue).json",
            isDirectory: false
        )
    }

    func validate(runID: RunID, runRoot: URL) throws {
        guard self.runID == runID,
              self.runRoot.standardizedFileURL == runRoot.standardizedFileURL,
              runRoot.standardizedFileURL.lastPathComponent == runID.filesystemComponent
        else { throw PersistenceError.integrityViolation }
    }

    func receiptComponents(kind: ReceiptKind) -> [String] {
        ["receipts", kind.rawValue]
    }

    func receiptFilename(id: ReceiptID) throws -> String {
        let filename = "\(id.rawValue).json"
        guard isValidatedPersistenceComponent(filename) else {
            throw PersistenceError.invalidPathComponent
        }
        return filename
    }

    func epochFilename(for transactionDigest: HashDigest) -> String {
        "\(transactionDigest.rawValue).json"
    }
}

private struct BootstrapObjectIdentity: Codable, Hashable, Sendable {
    let device: UInt64
    let inode: UInt64
    let kind: String
    let permissions: UInt16

    init(_ metadata: DescriptorObjectMetadata) {
        device = metadata.device
        inode = metadata.inode
        kind = metadata.kind.rawValue
        permissions = UInt16(metadata.permissions)
    }
}

private struct BootstrapAuthorityRecord: Codable, Hashable, Sendable {
    let schemaVersion: Int
    let runID: RunID
    let lifecycleID: String
    let phase: Int
    let chain: [BootstrapObjectIdentity]
    let runIdentityDigest: HashDigest?
    let anchor: BootstrapObjectIdentity?
    let lock: BootstrapObjectIdentity?

    init(
        runID: RunID,
        lifecycleID: String,
        phase: Int,
        chain: [BootstrapObjectIdentity],
        runIdentityDigest: HashDigest? = nil,
        anchor: BootstrapObjectIdentity? = nil,
        lock: BootstrapObjectIdentity? = nil
    ) {
        schemaVersion = 1
        self.runID = runID
        self.lifecycleID = lifecycleID
        self.phase = phase
        self.chain = chain
        self.runIdentityDigest = runIdentityDigest
        self.anchor = anchor
        self.lock = lock
    }

    init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.stringValue)))
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        runID = try container.decode(RunID.self, forKey: .runID)
        lifecycleID = try container.decode(String.self, forKey: .lifecycleID)
        phase = try container.decode(Int.self, forKey: .phase)
        chain = try container.decode([BootstrapObjectIdentity].self, forKey: .chain)
        runIdentityDigest = try container.decodeIfPresent(HashDigest.self, forKey: .runIdentityDigest)
        anchor = try container.decodeIfPresent(BootstrapObjectIdentity.self, forKey: .anchor)
        lock = try container.decodeIfPresent(BootstrapObjectIdentity.self, forKey: .lock)
    }

    func validate(
        runID: RunID,
        lifecycleID: String? = nil,
        phase: Int,
        chain: [BootstrapObjectIdentity]
    ) throws {
        guard schemaVersion == 1,
              self.runID == runID,
              lifecycleID.map({ self.lifecycleID == $0 }) ?? true,
              isValidatedPersistenceIdentifier(self.lifecycleID),
              self.phase == phase,
              self.chain == chain
        else { throw PersistenceError.integrityViolation }
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case runID = "run_id"
        case lifecycleID = "lifecycle_id"
        case phase
        case chain
        case runIdentityDigest = "run_identity_digest"
        case anchor
        case lock
    }
}

private struct DurableRunIdentity: Codable {
    let schemaVersion: Int
    let runID: RunID
    let lifecycleID: String
    let ancestorChain: [BootstrapObjectIdentity]
    let runRootDevice: UInt64
    let runRootInode: UInt64
    let anchorDevice: UInt64
    let anchorInode: UInt64
    let lockDevice: UInt64
    let lockInode: UInt64

    init(
        runID: RunID,
        lifecycleID: String,
        ancestorChain: [BootstrapObjectIdentity],
        runRoot: DescriptorObjectMetadata,
        anchor: DescriptorObjectMetadata,
        lock: DescriptorObjectMetadata
    ) {
        schemaVersion = 1
        self.runID = runID
        self.lifecycleID = lifecycleID
        self.ancestorChain = ancestorChain
        runRootDevice = runRoot.device
        runRootInode = runRoot.inode
        anchorDevice = anchor.device
        anchorInode = anchor.inode
        lockDevice = lock.device
        lockInode = lock.inode
    }

    init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.stringValue)))
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        runID = try container.decode(RunID.self, forKey: .runID)
        lifecycleID = try container.decode(String.self, forKey: .lifecycleID)
        ancestorChain = try container.decode([BootstrapObjectIdentity].self, forKey: .ancestorChain)
        runRootDevice = try container.decode(UInt64.self, forKey: .runRootDevice)
        runRootInode = try container.decode(UInt64.self, forKey: .runRootInode)
        anchorDevice = try container.decode(UInt64.self, forKey: .anchorDevice)
        anchorInode = try container.decode(UInt64.self, forKey: .anchorInode)
        lockDevice = try container.decode(UInt64.self, forKey: .lockDevice)
        lockInode = try container.decode(UInt64.self, forKey: .lockInode)
    }

    func validate(
        runID: RunID,
        lifecycleID: String,
        ancestorChain: [BootstrapObjectIdentity],
        runRoot: DescriptorObjectMetadata,
        anchor: DescriptorObjectMetadata,
        lock: DescriptorObjectMetadata
    ) throws {
        guard schemaVersion == 1,
              self.runID == runID,
              self.lifecycleID == lifecycleID,
              isValidatedPersistenceIdentifier(lifecycleID),
              self.ancestorChain == ancestorChain,
              runRootDevice == runRoot.device,
              runRootInode == runRoot.inode,
              anchorDevice == anchor.device,
              anchorInode == anchor.inode,
              lockDevice == lock.device,
              lockInode == lock.inode,
              runRoot.kind == .directory,
              runRoot.permissions == 0o700,
              anchor.kind == .regularFile,
              anchor.permissions == 0o600,
              anchor.linkCount == 1,
              lock.kind == .regularFile,
              lock.permissions == 0o600,
              lock.linkCount == 1
        else { throw PersistenceError.integrityViolation }
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case runID = "run_id"
        case lifecycleID = "lifecycle_id"
        case ancestorChain = "ancestor_chain"
        case runRootDevice = "run_root_device"
        case runRootInode = "run_root_inode"
        case anchorDevice = "anchor_device"
        case anchorInode = "anchor_inode"
        case lockDevice = "lock_device"
        case lockInode = "lock_inode"
    }
}

private func bootstrapAuthorityPrefix(runID: RunID) -> String {
    ".ifl-run-\(runID.filesystemComponent)-bootstrap-"
}

private func bootstrapPhaseName(prefix: String, phase: Int) -> String {
    "\(prefix)\(phase).json"
}

private func existingBootstrapPhaseNames(
    prefix: String,
    fileSystem: DescriptorRelativeFileSystem
) throws -> Set<Int> {
    var result: Set<Int> = []
    for name in try fileSystem.listEntries(in: []) where name.hasPrefix(prefix) {
        guard name.hasSuffix(".json"),
              let phase = Int(name.dropFirst(prefix.count).dropLast(5)),
              (0...5).contains(phase),
              result.insert(phase).inserted
        else { throw PersistenceError.integrityViolation }
    }
    if let maximum = result.max(), result != Set(0...maximum) {
        throw PersistenceError.integrityViolation
    }
    return result
}

private func createBootstrapPhase(
    _ record: BootstrapAuthorityRecord,
    prefix: String,
    fileSystem: DescriptorRelativeFileSystem
) throws -> DescriptorRelativeFile {
    try fileSystem.createFile(
        data: CanonicalJSON.encode(record),
        named: bootstrapPhaseName(prefix: prefix, phase: record.phase),
        in: [],
        mode: 0o600
    )
}

private func readBootstrapPhase(
    phase: Int,
    prefix: String,
    fileSystem: DescriptorRelativeFileSystem
) throws -> BootstrapAuthorityRecord {
    try decodeBootstrapPhase(
        fileSystem.readFile(
            named: bootstrapPhaseName(prefix: prefix, phase: phase),
            in: []
        )
    )
}

private func decodeBootstrapPhase(_ bytes: Data) throws -> BootstrapAuthorityRecord {
    do {
        let record = try CanonicalJSON.decode(BootstrapAuthorityRecord.self, from: bytes)
        guard try CanonicalJSON.encode(record) == bytes else {
            throw PersistenceError.integrityViolation
        }
        return record
    } catch {
        throw PersistenceError.integrityViolation
    }
}

private func prepareFixedFile(
    named name: String,
    bytes: Data,
    components: [String],
    fileSystem: DescriptorRelativeFileSystem
) throws -> DescriptorRelativeFile {
    if let existing = try fileSystem.readFileIfPresent(named: name, in: components) {
        guard existing == bytes else { throw PersistenceError.integrityViolation }
        let file = try fileSystem.openFile(named: name, in: components)
        guard file.metadata.permissions == 0o600, file.metadata.linkCount == 1 else {
            throw PersistenceError.integrityViolation
        }
        return file
    }
    return try fileSystem.createFile(
        data: bytes,
        named: name,
        in: components,
        mode: 0o600
    )
}

private func require<T>(_ value: T?) throws -> T {
    guard let value else { throw PersistenceError.integrityViolation }
    return value
}

private extension DescriptorObjectMetadata {
    static let invalidSentinel = DescriptorObjectMetadata(
        device: 0,
        inode: 0,
        kind: .other,
        permissions: 0,
        linkCount: 0
    )
}
