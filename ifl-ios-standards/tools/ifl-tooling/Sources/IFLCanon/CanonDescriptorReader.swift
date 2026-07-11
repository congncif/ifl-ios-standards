import Darwin
import Foundation
import IFLContracts

package enum CanonRepositoryReadEvent: Equatable {
    case willOpenDirectory(String)
    case willOpenFile(String)
    case didReadFile(String)
}

package typealias CanonRepositoryReadEventHandler = @Sendable (
    CanonRepositoryReadEvent
) throws -> Void

final class CanonDescriptorReader {
    private let rootDescriptor: CanonRootDescriptor
    private let eventHandler: CanonRepositoryReadEventHandler

    convenience init(
        root: URL,
        eventHandler: @escaping CanonRepositoryReadEventHandler
    ) throws {
        try self.init(
            rootDescriptor: CanonRootDescriptor(opening: root),
            eventHandler: eventHandler
        )
    }

    init(
        rootDescriptor: CanonRootDescriptor,
        eventHandler: @escaping CanonRepositoryReadEventHandler
    ) throws {
        self.rootDescriptor = rootDescriptor
        self.eventHandler = eventHandler
        try rootDescriptor.validateBinding()
    }

    var rootSnapshot: CanonFileSnapshot {
        rootDescriptor.snapshot
    }

    func openDirectoryAnchor(
        relativePath: CanonicalRelativePath,
        retainedPluginIdentity: RetainedPluginRootIdentity?,
        missingReference: (kind: String, id: String)? = nil
    ) throws -> CanonRootAnchor {
        try validateRoot()

        let components = relativePath.rawValue.split(separator: "/").map(String.init)
        var parentFD = rootDescriptor.descriptor.rawValue
        var relativeDirectory = ""
        var openedDirectories: [CanonOpenedDirectory] = []
        openedDirectories.reserveCapacity(components.count)

        for component in components {
            let path = relativeDirectory.isEmpty
                ? component
                : relativeDirectory + "/" + component
            try eventHandler(.willOpenDirectory(path))
            let linkSnapshot = try Self.relativeSnapshot(
                parentFD: parentFD,
                name: component,
                path: path,
                missingReference: missingReference
            )
            try validate(snapshot: linkSnapshot, kind: mode_t(S_IFDIR), path: path)

            let rawFD = component.withCString {
                Darwin.openat(
                    parentFD,
                    $0,
                    O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
                )
            }
            guard rawFD >= 0 else {
                throw Self.changed(path: path)
            }
            let ownedFD = CanonOwnedFileDescriptor(rawFD)
            let openedSnapshot = try Self.descriptorSnapshot(rawFD, path: path)
            guard openedSnapshot == linkSnapshot else {
                throw Self.changed(path: path)
            }
            try validate(snapshot: openedSnapshot, kind: mode_t(S_IFDIR), path: path)
            openedDirectories.append(
                CanonOpenedDirectory(
                    descriptor: ownedFD,
                    parentFD: parentFD,
                    name: component,
                    relativePath: path,
                    snapshot: openedSnapshot
                )
            )
            parentFD = rawFD
            relativeDirectory = path
        }

        for directory in openedDirectories.reversed() {
            let finalDirectory = try Self.descriptorSnapshot(
                directory.descriptor.rawValue,
                path: directory.relativePath
            )
            let finalLink = try Self.relativeSnapshot(
                parentFD: directory.parentFD,
                name: directory.name,
                path: directory.relativePath
            )
            guard finalDirectory == directory.snapshot,
                  finalLink == directory.snapshot
            else {
                throw Self.changed(path: directory.relativePath)
            }
        }
        try validateRoot()
        guard let selected = openedDirectories.last else {
            throw Self.changed(path: relativePath.rawValue)
        }
        return try CanonRootAnchor(
            duplicatingRootDirectoryDescriptor: selected.descriptor.rawValue,
            path: rootDescriptor.path + "/" + relativePath.rawValue,
            retainedPluginIdentity: retainedPluginIdentity
        )
    }

    func read(relativePath: CanonicalRelativePath) throws -> Data {
        try validateRoot()

        let components = relativePath.rawValue.split(separator: "/").map(String.init)
        guard let fileName = components.last else {
            throw Self.changed(path: relativePath.rawValue)
        }

        var parentFD = rootDescriptor.descriptor.rawValue
        var relativeDirectory = ""
        var openedDirectories: [CanonOpenedDirectory] = []
        openedDirectories.reserveCapacity(max(components.count - 1, 0))

        for component in components.dropLast() {
            let path = relativeDirectory.isEmpty
                ? component
                : relativeDirectory + "/" + component
            try eventHandler(.willOpenDirectory(path))
            let linkSnapshot = try Self.relativeSnapshot(
                parentFD: parentFD,
                name: component,
                path: path
            )
            try validate(snapshot: linkSnapshot, kind: mode_t(S_IFDIR), path: path)

            let rawFD = component.withCString {
                Darwin.openat(
                    parentFD,
                    $0,
                    O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
                )
            }
            guard rawFD >= 0 else {
                throw Self.changed(path: path)
            }
            let ownedFD = CanonOwnedFileDescriptor(rawFD)
            let openedSnapshot = try Self.descriptorSnapshot(rawFD, path: path)
            guard openedSnapshot == linkSnapshot else {
                throw Self.changed(path: path)
            }
            try validate(snapshot: openedSnapshot, kind: mode_t(S_IFDIR), path: path)
            openedDirectories.append(
                CanonOpenedDirectory(
                    descriptor: ownedFD,
                    parentFD: parentFD,
                    name: component,
                    relativePath: path,
                    snapshot: openedSnapshot
                )
            )
            parentFD = rawFD
            relativeDirectory = path
        }

        let filePath = relativePath.rawValue
        try eventHandler(.willOpenFile(filePath))
        let linkSnapshot = try Self.relativeSnapshot(
            parentFD: parentFD,
            name: fileName,
            path: filePath
        )
        try validate(snapshot: linkSnapshot, kind: mode_t(S_IFREG), path: filePath)

        let rawFileFD = fileName.withCString {
            Darwin.openat(
                parentFD,
                $0,
                O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK
            )
        }
        guard rawFileFD >= 0 else {
            throw Self.changed(path: filePath)
        }
        let fileFD = CanonOwnedFileDescriptor(rawFileFD)
        let openedFile = try Self.descriptorSnapshot(fileFD.rawValue, path: filePath)
        guard openedFile == linkSnapshot else {
            throw Self.changed(path: filePath)
        }
        try validate(snapshot: openedFile, kind: mode_t(S_IFREG), path: filePath)

        let data = try Self.readOwnedData(
            descriptor: fileFD.rawValue,
            expectedSize: openedFile.size,
            path: filePath
        )
        try eventHandler(.didReadFile(filePath))

        let finalFile = try Self.descriptorSnapshot(fileFD.rawValue, path: filePath)
        let finalLink = try Self.relativeSnapshot(
            parentFD: parentFD,
            name: fileName,
            path: filePath
        )
        guard finalFile == openedFile, finalLink == openedFile else {
            throw Self.changed(path: filePath)
        }

        for directory in openedDirectories.reversed() {
            let finalDirectory = try Self.descriptorSnapshot(
                directory.descriptor.rawValue,
                path: directory.relativePath
            )
            let finalLink = try Self.relativeSnapshot(
                parentFD: directory.parentFD,
                name: directory.name,
                path: directory.relativePath
            )
            guard finalDirectory == directory.snapshot,
                  finalLink == directory.snapshot
            else {
                throw Self.changed(path: directory.relativePath)
            }
        }
        try validateRoot()
        return data
    }

    func scan(policy: CanonicalTreePolicy) throws -> CanonicalTreeInventory {
        do {
            return try CanonicalTreeScanner().scan(
                borrowingRootDirectoryDescriptor: rootDescriptor.descriptor.rawValue,
                policy: policy
            )
        } catch let error as ContractError {
            throw error
        } catch {
            throw CanonDescriptorFailure.integrityViolation(
                "Canon root cannot be scanned as a descriptor-confined canonical tree"
            )
        }
    }

    func captureTree(emitReadEvents: Bool = true) throws -> CanonDescriptorTreeCapture {
        try validateRoot()
        let rootBefore = try Self.descriptorSnapshot(
            rootDescriptor.descriptor.rawValue,
            path: rootDescriptor.path
        )
        var entries: [CanonicalTreeEntry] = []
        var filesByRelativePath: [String: Data] = [:]
        var snapshotsByRelativePath: [String: CanonFileSnapshot] = ["": rootBefore]
        var visitedDirectoryIdentities: Set<CanonObjectIdentity> = [
            rootBefore.objectIdentity,
        ]

        func walk(directoryFD: Int32, relativeDirectory: String) throws {
            let directoryBefore = try Self.descriptorSnapshot(
                directoryFD,
                path: relativeDirectory.isEmpty ? rootDescriptor.path : relativeDirectory
            )
            let names = try Self.directoryNames(
                descriptor: directoryFD,
                path: relativeDirectory
            )

            for name in names {
                let relativePath = relativeDirectory.isEmpty
                    ? name
                    : relativeDirectory + "/" + name
                _ = try CanonicalRelativePath(validating: relativePath)
                let linkBefore = try Self.relativeSnapshot(
                    parentFD: directoryFD,
                    name: name,
                    path: relativePath
                )
                let expectedKind: mode_t
                let flags: Int32
                switch linkBefore.kind {
                case mode_t(S_IFDIR):
                    expectedKind = mode_t(S_IFDIR)
                    flags = O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
                    if emitReadEvents {
                        try eventHandler(.willOpenDirectory(relativePath))
                    }
                case mode_t(S_IFREG):
                    expectedKind = mode_t(S_IFREG)
                    flags = O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK
                    if emitReadEvents {
                        try eventHandler(.willOpenFile(relativePath))
                    }
                default:
                    throw Self.changed(path: relativePath)
                }
                try validate(snapshot: linkBefore, kind: expectedKind, path: relativePath)

                let rawFD = name.withCString {
                    Darwin.openat(directoryFD, $0, flags)
                }
                guard rawFD >= 0 else {
                    throw Self.changed(path: relativePath)
                }
                let childFD = CanonOwnedFileDescriptor(rawFD)
                let opened = try Self.descriptorSnapshot(
                    childFD.rawValue,
                    path: relativePath
                )
                guard opened == linkBefore else {
                    throw Self.changed(path: relativePath)
                }
                try validate(snapshot: opened, kind: expectedKind, path: relativePath)
                if expectedKind == mode_t(S_IFDIR) {
                    guard visitedDirectoryIdentities.insert(opened.objectIdentity).inserted else {
                        throw Self.changed(path: relativePath)
                    }
                }
                guard snapshotsByRelativePath.updateValue(
                    opened,
                    forKey: relativePath
                ) == nil else {
                    throw Self.changed(path: relativePath)
                }

                if expectedKind == mode_t(S_IFDIR) {
                    try entries.append(CanonicalTreeEntry(
                        relativePath: relativePath,
                        kind: .directory,
                        contentSHA256: nil,
                        mode: Self.portableMode(opened)
                    ))
                    try walk(
                        directoryFD: childFD.rawValue,
                        relativeDirectory: relativePath
                    )
                } else {
                    let data = try Self.readOwnedData(
                        descriptor: childFD.rawValue,
                        expectedSize: opened.size,
                        path: relativePath
                    )
                    if emitReadEvents {
                        try eventHandler(.didReadFile(relativePath))
                    }
                    guard filesByRelativePath.updateValue(data, forKey: relativePath) == nil else {
                        throw Self.changed(path: relativePath)
                    }
                    try entries.append(CanonicalTreeEntry(
                        relativePath: relativePath,
                        kind: .regularFile,
                        contentSHA256: CanonicalTreeDigest.sha256(data),
                        mode: Self.portableMode(opened)
                    ))
                }

                let finalOpened = try Self.descriptorSnapshot(
                    childFD.rawValue,
                    path: relativePath
                )
                let linkAfter = try Self.relativeSnapshot(
                    parentFD: directoryFD,
                    name: name,
                    path: relativePath
                )
                guard finalOpened == opened, linkAfter == opened else {
                    throw Self.changed(path: relativePath)
                }
            }

            let directoryAfter = try Self.descriptorSnapshot(
                directoryFD,
                path: relativeDirectory.isEmpty ? rootDescriptor.path : relativeDirectory
            )
            guard directoryAfter == directoryBefore else {
                throw Self.changed(
                    path: relativeDirectory.isEmpty
                        ? rootDescriptor.path
                        : relativeDirectory
                )
            }
        }

        try walk(
            directoryFD: rootDescriptor.descriptor.rawValue,
            relativeDirectory: ""
        )
        let rootAfter = try Self.descriptorSnapshot(
            rootDescriptor.descriptor.rawValue,
            path: rootDescriptor.path
        )
        guard rootAfter == rootBefore else {
            throw Self.changed(path: rootDescriptor.path)
        }
        try validateRoot()
        return try CanonDescriptorTreeCapture(
            inventory: CanonicalTreeInventory(
                policy: CanonicalTreePolicy(excludedRoots: []),
                rootMode: Self.portableMode(rootAfter),
                entries: entries
            ),
            filesByRelativePath: filesByRelativePath,
            snapshotsByRelativePath: snapshotsByRelativePath
        )
    }

    func validateRoot() throws {
        try rootDescriptor.validateBinding()
    }

    private func validate(
        snapshot: CanonFileSnapshot,
        kind: mode_t,
        path: String
    ) throws {
        guard snapshot.kind == kind,
              snapshot.device == rootDescriptor.snapshot.device,
              snapshot.rawMode & mode_t(S_ISUID | S_ISGID | S_ISVTX) == 0,
              kind != mode_t(S_IFREG) || snapshot.linkCount == 1
        else {
            throw Self.changed(path: path)
        }
    }

    private static func readOwnedData(
        descriptor: Int32,
        expectedSize: Int64,
        path: String
    ) throws -> Data {
        var data = Data()
        if expectedSize >= 0, expectedSize <= Int64(Int.max) {
            data.reserveCapacity(Int(expectedSize))
        }
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let count = buffer.withUnsafeMutableBytes { bytes -> Int in
                while true {
                    let result = Darwin.read(descriptor, bytes.baseAddress, bytes.count)
                    if result < 0, errno == EINTR {
                        continue
                    }
                    return result
                }
            }
            guard count >= 0 else {
                throw changed(path: path)
            }
            guard count > 0 else { break }
            data.append(contentsOf: buffer[0 ..< count])
        }
        guard Int64(data.count) == expectedSize else {
            throw changed(path: path)
        }
        return data
    }

    private static func directoryNames(
        descriptor: Int32,
        path: String
    ) throws -> [String] {
        let reopened = ".".withCString {
            Darwin.openat(
                descriptor,
                $0,
                O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
            )
        }
        guard reopened >= 0 else {
            throw changed(path: path)
        }
        guard let directory = Darwin.fdopendir(reopened) else {
            Darwin.close(reopened)
            throw changed(path: path)
        }
        defer { Darwin.closedir(directory) }

        var names: [String] = []
        while true {
            errno = 0
            guard let entry = Darwin.readdir(directory) else {
                guard errno == 0 else { throw changed(path: path) }
                break
            }
            let length = Int(entry.pointee.d_namlen)
            let name: String? = withUnsafePointer(to: &entry.pointee.d_name) { pointer in
                pointer.withMemoryRebound(to: UInt8.self, capacity: length) { bytes in
                    String(
                        bytes: UnsafeBufferPointer(start: bytes, count: length),
                        encoding: .utf8
                    )
                }
            }
            guard let name else { throw changed(path: path) }
            if name != ".", name != ".." {
                _ = try CanonicalRelativePath(validating: name)
                names.append(name)
            }
        }
        names.sort { $0.utf8.lexicographicallyPrecedes($1.utf8) }
        return names
    }

    private static func portableMode(_ snapshot: CanonFileSnapshot) -> UInt16 {
        UInt16(snapshot.rawMode & 0o777)
    }

    private static func descriptorSnapshot(
        _ descriptor: Int32,
        path: String
    ) throws -> CanonFileSnapshot {
        try canonDescriptorSnapshot(descriptor, path: path)
    }

    private static func relativeSnapshot(
        parentFD: Int32,
        name: String,
        path: String,
        missingReference: (kind: String, id: String)? = nil
    ) throws -> CanonFileSnapshot {
        var value = stat()
        let result = name.withCString {
            Darwin.fstatat(parentFD, $0, &value, AT_SYMLINK_NOFOLLOW)
        }
        let failure = errno
        guard result == 0 else {
            if failure == ENOENT, let missingReference {
                throw ContractError.unresolvedReference(
                    kind: missingReference.kind,
                    id: missingReference.id
                )
            }
            throw changed(path: path)
        }
        return CanonFileSnapshot(value)
    }

    private static func changed(path: String) -> CanonDescriptorFailure {
        CanonDescriptorFailure.integrityViolation(
            "\(path) changed or crossed a descriptor-confined file boundary"
        )
    }
}

struct CanonDescriptorTreeCapture {
    let inventory: CanonicalTreeInventory
    let filesByRelativePath: [String: Data]
    let snapshotsByRelativePath: [String: CanonFileSnapshot]

    init(
        inventory: CanonicalTreeInventory,
        filesByRelativePath: [String: Data],
        snapshotsByRelativePath: [String: CanonFileSnapshot]
    ) throws {
        let inventoryFiles = Set(
            inventory.entries.lazy
                .filter { $0.kind == .regularFile }
                .map(\.relativePath)
        )
        guard inventoryFiles == Set(filesByRelativePath.keys) else {
            throw CanonDescriptorFailure.integrityViolation(
                "captured file bytes do not equal the descriptor tree inventory"
            )
        }
        let inventoryPaths = Set(inventory.entries.map(\.relativePath)).union([""])
        guard inventoryPaths == Set(snapshotsByRelativePath.keys) else {
            throw CanonDescriptorFailure.integrityViolation(
                "captured object identities do not equal the descriptor tree inventory"
            )
        }
        self.inventory = inventory
        self.filesByRelativePath = filesByRelativePath
        self.snapshotsByRelativePath = snapshotsByRelativePath
    }
}

private struct CanonOpenedDirectory {
    let descriptor: CanonOwnedFileDescriptor
    let parentFD: Int32
    let name: String
    let relativePath: String
    let snapshot: CanonFileSnapshot
}
