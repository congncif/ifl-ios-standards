import Darwin
import Foundation
import IFLContracts

enum CanonRepositoryReadEvent: Equatable {
    case willOpenDirectory(String)
    case willOpenFile(String)
    case didReadFile(String)
}

typealias CanonRepositoryReadEventHandler = @Sendable (CanonRepositoryReadEvent) throws -> Void

final class CanonDescriptorReader {
    private let rootPath: String
    private let rootFD: CanonOwnedFileDescriptor
    private let rootSnapshot: CanonFileSnapshot
    private let eventHandler: CanonRepositoryReadEventHandler

    init(
        root: URL,
        eventHandler: @escaping CanonRepositoryReadEventHandler
    ) throws {
        rootPath = root.path
        self.eventHandler = eventHandler

        let linkSnapshot = try Self.rootLinkSnapshot(path: rootPath)
        guard linkSnapshot.kind == mode_t(S_IFDIR) else {
            throw Self.changed(path: rootPath)
        }

        let rawFD = rootPath.withCString {
            Darwin.open($0, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        }
        guard rawFD >= 0 else {
            throw Self.changed(path: rootPath)
        }
        rootFD = CanonOwnedFileDescriptor(rawFD)
        rootSnapshot = try Self.descriptorSnapshot(rawFD, path: rootPath)
        guard rootSnapshot == linkSnapshot else {
            throw Self.changed(path: rootPath)
        }
        try validate(snapshot: rootSnapshot, kind: mode_t(S_IFDIR), path: rootPath)
    }

    func read(relativePath: CanonicalRelativePath) throws -> Data {
        try validateRoot()

        let components = relativePath.rawValue.split(separator: "/").map(String.init)
        guard let fileName = components.last else {
            throw Self.changed(path: relativePath.rawValue)
        }

        var parentFD = rootFD.rawValue
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
                borrowingRootDirectoryDescriptor: rootFD.rawValue,
                policy: policy
            )
        } catch let error as ContractError {
            throw error
        } catch {
            throw ContractError.invalidContract(
                kind: "canon_repository",
                reason: "Canon root cannot be scanned as a descriptor-confined canonical tree"
            )
        }
    }

    func validateRoot() throws {
        let descriptor = try Self.descriptorSnapshot(rootFD.rawValue, path: rootPath)
        let link = try Self.rootLinkSnapshot(path: rootPath)
        guard descriptor == rootSnapshot, link == rootSnapshot else {
            throw Self.changed(path: rootPath)
        }
    }

    private func validate(
        snapshot: CanonFileSnapshot,
        kind: mode_t,
        path: String
    ) throws {
        guard snapshot.kind == kind,
              snapshot.device == rootSnapshot.device,
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

    private static func rootLinkSnapshot(path: String) throws -> CanonFileSnapshot {
        var value = stat()
        let result = path.withCString { Darwin.lstat($0, &value) }
        guard result == 0 else {
            throw changed(path: path)
        }
        return CanonFileSnapshot(value)
    }

    private static func descriptorSnapshot(
        _ descriptor: Int32,
        path: String
    ) throws -> CanonFileSnapshot {
        var value = stat()
        guard Darwin.fstat(descriptor, &value) == 0 else {
            throw changed(path: path)
        }
        return CanonFileSnapshot(value)
    }

    private static func relativeSnapshot(
        parentFD: Int32,
        name: String,
        path: String
    ) throws -> CanonFileSnapshot {
        var value = stat()
        let result = name.withCString {
            Darwin.fstatat(parentFD, $0, &value, AT_SYMLINK_NOFOLLOW)
        }
        guard result == 0 else {
            throw changed(path: path)
        }
        return CanonFileSnapshot(value)
    }

    private static func changed(path: String) -> ContractError {
        ContractError.invalidContract(
            kind: "canon_repository",
            reason: "\(path) changed or crossed a descriptor-confined file boundary"
        )
    }
}

private final class CanonOwnedFileDescriptor {
    let rawValue: Int32

    init(_ rawValue: Int32) {
        self.rawValue = rawValue
    }

    deinit {
        Darwin.close(rawValue)
    }
}

private struct CanonOpenedDirectory {
    let descriptor: CanonOwnedFileDescriptor
    let parentFD: Int32
    let name: String
    let relativePath: String
    let snapshot: CanonFileSnapshot
}

private struct CanonFileSnapshot: Equatable {
    let device: UInt64
    let inode: UInt64
    let kind: mode_t
    let rawMode: mode_t
    let linkCount: UInt64
    let size: Int64
    let modificationSeconds: Int64
    let modificationNanoseconds: Int64
    let changeSeconds: Int64
    let changeNanoseconds: Int64

    init(_ value: stat) {
        device = UInt64(value.st_dev)
        inode = UInt64(value.st_ino)
        kind = value.st_mode & mode_t(S_IFMT)
        rawMode = value.st_mode
        linkCount = UInt64(value.st_nlink)
        size = value.st_size
        modificationSeconds = Int64(value.st_mtimespec.tv_sec)
        modificationNanoseconds = Int64(value.st_mtimespec.tv_nsec)
        changeSeconds = Int64(value.st_ctimespec.tv_sec)
        changeNanoseconds = Int64(value.st_ctimespec.tv_nsec)
    }
}
