import CryptoKit
import Darwin
import Foundation

enum CanonicalTreeScanEvent: Equatable {
    case beforeRootOpen
    case afterRootOpenValidation
    case beforeEntryClassification(relativePath: String)
    case afterEntryClassification(relativePath: String)
    case afterEntryOpenValidation(relativePath: String)
    case beforeDirectoryEnumeration(relativePath: String)
    case afterDirectoryEnumeration(relativePath: String)
    case afterReadChunk(relativePath: String, offset: Int64)
    case afterFileRead(relativePath: String)
    case beforeFinalDescriptorStat(relativePath: String)
    case beforeLinkRevalidation(relativePath: String)
    case beforeRootTerminalRevalidation
}

public struct CanonicalTreeScanner {
    private let hook: (CanonicalTreeScanEvent) throws -> Void
    private let validationProjection: (String, FileSnapshot) -> FileSnapshot

    public init() {
        hook = { _ in }
        validationProjection = { _, snapshot in snapshot }
    }

    init(
        hook: @escaping (CanonicalTreeScanEvent) throws -> Void,
        validationProjection: @escaping (String, FileSnapshot) -> FileSnapshot = { _, snapshot in snapshot }
    ) {
        self.hook = hook
        self.validationProjection = validationProjection
    }

    init(validationProjection: @escaping (String, FileSnapshot) -> FileSnapshot) {
        hook = { _ in }
        self.validationProjection = validationProjection
    }

    public func scan(root: URL, policy: CanonicalTreePolicy) throws -> CanonicalTreeInventory {
        let rootPath = root.path
        var rootLinkStat = stat()
        guard rootPath.withCString({ lstat($0, &rootLinkStat) }) == 0 else {
            throw CanonicalTreeError.rootOpenFailed(errno)
        }
        let rootLinkSnapshot = FileSnapshot(rootLinkStat)
        guard rootLinkSnapshot.kind == mode_t(S_IFDIR) else {
            throw CanonicalTreeError.unsupportedObject(path: rootPath)
        }
        try hook(.beforeRootOpen)

        let rootRawFD = rootPath.withCString {
            open($0, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        }
        guard rootRawFD >= 0 else {
            throw CanonicalTreeError.rootOpenFailed(errno)
        }
        let rootFD = OwnedFileDescriptor(rootRawFD)

        let openedRoot = try descriptorSnapshot(rootFD.rawValue, operation: "fstat", path: rootPath)
        guard openedRoot.sameObjectAndMetadata(as: rootLinkSnapshot) else {
            throw CanonicalTreeError.objectChanged(path: rootPath)
        }

        return try scanOpenedRoot(
            rootFD: rootFD,
            rootPath: rootPath,
            openedRoot: openedRoot,
            policy: policy,
            terminalRootSnapshot: {
                var rootLinkAfterStat = stat()
                guard rootPath.withCString({ lstat($0, &rootLinkAfterStat) }) == 0 else {
                    throw CanonicalTreeError.syscall(
                        operation: "lstat",
                        path: rootPath,
                        errno: errno
                    )
                }
                return FileSnapshot(rootLinkAfterStat)
            }
        )
    }

    /// Scans the exact directory referenced by a borrowed descriptor.
    ///
    /// The scanner opens `.` relative to the descriptor so traversal owns an independent open
    /// file description. It neither closes the borrowed descriptor nor advances its directory
    /// offset.
    public func scan(
        borrowingRootDirectoryDescriptor borrowedRootFD: Int32,
        policy: CanonicalTreePolicy
    ) throws -> CanonicalTreeInventory {
        let rootPath = "<borrowed-root-directory>"
        let borrowedRoot = try descriptorSnapshot(
            borrowedRootFD,
            operation: "fstat",
            path: rootPath
        )
        guard borrowedRoot.kind == mode_t(S_IFDIR) else {
            throw CanonicalTreeError.unsupportedObject(path: rootPath)
        }
        try hook(.beforeRootOpen)

        let rawRootFD = Darwin.openat(
            borrowedRootFD,
            ".",
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
        )
        guard rawRootFD >= 0 else {
            throw CanonicalTreeError.syscall(
                operation: "openat",
                path: rootPath,
                errno: errno
            )
        }
        let rootFD = OwnedFileDescriptor(rawRootFD)
        let openedRoot = try descriptorSnapshot(
            rootFD.rawValue,
            operation: "fstat",
            path: rootPath
        )
        guard openedRoot.sameObjectAndMetadata(as: borrowedRoot) else {
            throw CanonicalTreeError.objectChanged(path: rootPath)
        }

        return try scanOpenedRoot(
            rootFD: rootFD,
            rootPath: rootPath,
            openedRoot: openedRoot,
            policy: policy,
            terminalRootSnapshot: {
                try descriptorSnapshot(
                    borrowedRootFD,
                    operation: "fstat",
                    path: rootPath
                )
            }
        )
    }

    private func scanOpenedRoot(
        rootFD: OwnedFileDescriptor,
        rootPath: String,
        openedRoot: FileSnapshot,
        policy: CanonicalTreePolicy,
        terminalRootSnapshot: () throws -> FileSnapshot
    ) throws -> CanonicalTreeInventory {
        try validateOpenedObject(
            openedRoot,
            rootDevice: openedRoot.device,
            path: rootPath,
            requireDirectory: true
        )
        try hook(.afterRootOpenValidation)

        var entries: [CanonicalTreeEntry] = []
        var matchedExclusions: Set<String> = []
        var normalizedPaths: Set<String> = []
        let exclusionSet = Set(policy.excludedRoots)

        func walk(directoryFD: Int32, relativeDirectory: String) throws {
            let directoryBefore = try descriptorSnapshot(
                directoryFD,
                operation: "fstat",
                path: relativeDirectory.isEmpty ? rootPath : relativeDirectory
            )
            let eventPath = relativeDirectory
            try hook(.beforeDirectoryEnumeration(relativePath: eventPath))
            let names = try readDirectoryNames(directoryFD, relativePath: eventPath)
            try hook(.afterDirectoryEnumeration(relativePath: eventPath))

            for name in names {
                let relativePath = relativeDirectory.isEmpty ? name : relativeDirectory + "/" + name
                _ = try CanonicalRelativePath(validating: relativePath)
                guard normalizedPaths.insert(relativePath).inserted else {
                    throw CanonicalTreeError.normalizationCollision(relativePath)
                }

                try hook(.beforeEntryClassification(relativePath: relativePath))
                let linkBefore = try relativeSnapshot(
                    parentFD: directoryFD,
                    name: name,
                    operation: "fstatat",
                    path: relativePath
                )
                try hook(.afterEntryClassification(relativePath: relativePath))
                try validateOpenedObject(
                    linkBefore,
                    rootDevice: openedRoot.device,
                    path: relativePath,
                    requireDirectory: false
                )

                let flags: Int32
                if linkBefore.kind == mode_t(S_IFDIR) {
                    flags = O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
                } else if linkBefore.kind == mode_t(S_IFREG) {
                    flags = O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK
                } else {
                    throw CanonicalTreeError.unsupportedObject(path: relativePath)
                }

                let rawFD = name.withCString { openat(directoryFD, $0, flags) }
                guard rawFD >= 0 else {
                    throw CanonicalTreeError.syscall(
                        operation: "openat",
                        path: relativePath,
                        errno: errno
                    )
                }
                let childFD = OwnedFileDescriptor(rawFD)
                let opened = try descriptorSnapshot(
                    childFD.rawValue,
                    operation: "fstat",
                    path: relativePath
                )
                guard opened.sameObjectAndMetadata(as: linkBefore) else {
                    throw CanonicalTreeError.objectChanged(path: relativePath)
                }
                try validateOpenedObject(
                    opened,
                    rootDevice: openedRoot.device,
                    path: relativePath,
                    requireDirectory: linkBefore.kind == mode_t(S_IFDIR)
                )
                try hook(.afterEntryOpenValidation(relativePath: relativePath))

                let isExcluded = exclusionSet.contains(relativePath)
                if isExcluded {
                    matchedExclusions.insert(relativePath)
                }

                if opened.kind == mode_t(S_IFDIR) {
                    if !isExcluded {
                        try entries.append(
                            CanonicalTreeEntry(
                                relativePath: relativePath,
                                kind: .directory,
                                contentSHA256: nil,
                                mode: opened.portableMode
                            )
                        )
                        try walk(directoryFD: childFD.rawValue, relativeDirectory: relativePath)
                    }
                } else {
                    var digest: HashDigest?
                    if !isExcluded {
                        digest = try hashFileDescriptor(childFD.rawValue, relativePath: relativePath)
                    }
                    try hook(.afterFileRead(relativePath: relativePath))
                    try hook(.beforeFinalDescriptorStat(relativePath: relativePath))
                    let final = try descriptorSnapshot(
                        childFD.rawValue,
                        operation: "fstat",
                        path: relativePath
                    )
                    guard final.sameObjectAndMetadata(as: opened) else {
                        throw CanonicalTreeError.objectChanged(path: relativePath)
                    }
                    try validateOpenedObject(
                        final,
                        rootDevice: openedRoot.device,
                        path: relativePath,
                        requireDirectory: false
                    )
                    if !isExcluded {
                        try entries.append(
                            CanonicalTreeEntry(
                                relativePath: relativePath,
                                kind: .regularFile,
                                contentSHA256: digest,
                                mode: final.portableMode
                            )
                        )
                    }
                }

                try hook(.beforeLinkRevalidation(relativePath: relativePath))
                let linkAfter = try relativeSnapshot(
                    parentFD: directoryFD,
                    name: name,
                    operation: "fstatat",
                    path: relativePath
                )
                let finalOpened = try descriptorSnapshot(
                    childFD.rawValue,
                    operation: "fstat",
                    path: relativePath
                )
                guard finalOpened.sameObjectAndMetadata(as: opened),
                      finalOpened.sameObjectAndMetadata(as: linkAfter)
                else {
                    throw CanonicalTreeError.objectChanged(path: relativePath)
                }
                try validateOpenedObject(
                    finalOpened,
                    rootDevice: openedRoot.device,
                    path: relativePath,
                    requireDirectory: opened.kind == mode_t(S_IFDIR)
                )
            }

            let directoryAfter = try descriptorSnapshot(
                directoryFD,
                operation: "fstat",
                path: relativeDirectory.isEmpty ? rootPath : relativeDirectory
            )
            guard directoryAfter.sameObjectAndMetadata(as: directoryBefore) else {
                throw CanonicalTreeError.objectChanged(
                    path: relativeDirectory.isEmpty ? rootPath : relativeDirectory
                )
            }
        }

        try walk(directoryFD: rootFD.rawValue, relativeDirectory: "")

        let unmatched = policy.excludedRoots.filter { !matchedExclusions.contains($0) }
        guard unmatched.isEmpty else {
            throw CanonicalTreeError.unmatchedExclusions(unmatched)
        }

        try hook(.beforeRootTerminalRevalidation)
        let rootAfter = try descriptorSnapshot(rootFD.rawValue, operation: "fstat", path: rootPath)
        let rootLinkAfter = try terminalRootSnapshot()
        guard rootAfter.sameObjectAndMetadata(as: openedRoot),
              rootAfter.sameObjectAndMetadata(as: rootLinkAfter)
        else {
            throw CanonicalTreeError.objectChanged(path: rootPath)
        }

        return try CanonicalTreeInventory(
            policy: policy,
            rootMode: openedRoot.portableMode,
            entries: entries
        )
    }

    private func readDirectoryNames(_ fd: Int32, relativePath: String) throws -> [String] {
        let duplicateFD = fcntl(fd, F_DUPFD_CLOEXEC, 0)
        guard duplicateFD >= 0 else {
            throw CanonicalTreeError.syscall(
                operation: "fcntl(F_DUPFD_CLOEXEC)",
                path: relativePath,
                errno: errno
            )
        }
        guard let directory = fdopendir(duplicateFD) else {
            let capturedErrno = errno
            close(duplicateFD)
            throw CanonicalTreeError.syscall(
                operation: "fdopendir",
                path: relativePath,
                errno: capturedErrno
            )
        }
        defer { closedir(directory) }

        var names: [String] = []
        while true {
            errno = 0
            guard let entry = readdir(directory) else {
                let capturedErrno = errno
                if capturedErrno != 0 {
                    throw CanonicalTreeError.syscall(
                        operation: "readdir",
                        path: relativePath,
                        errno: capturedErrno
                    )
                }
                break
            }

            let length = Int(entry.pointee.d_namlen)
            let name: String? = withUnsafePointer(to: &entry.pointee.d_name) { pointer in
                pointer.withMemoryRebound(to: UInt8.self, capacity: length) { bytes in
                    String(bytes: UnsafeBufferPointer(start: bytes, count: length), encoding: .utf8)
                }
            }
            guard let name else {
                throw CanonicalTreeError.invalidUTF8Name(relativePath)
            }
            if name == "." || name == ".." {
                continue
            }
            names.append(name)
        }

        try CanonicalTreeValidation.rejectNormalizationCollision(rawNames: names)
        for name in names {
            guard canonicalUTF8Equal(name, name.precomposedStringWithCanonicalMapping) else {
                throw CanonicalTreeError.nonCanonicalUnicodePath(name)
            }
            _ = try CanonicalRelativePath(validating: name)
        }
        names.sort(by: canonicalUTF8Less)
        return names
    }

    private func hashFileDescriptor(_ fd: Int32, relativePath: String) throws -> HashDigest {
        var hasher = SHA256()
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        var offset: Int64 = 0
        while true {
            let count = buffer.withUnsafeMutableBytes { bytes -> Int in
                while true {
                    let result = read(fd, bytes.baseAddress, bytes.count)
                    if result < 0, errno == EINTR {
                        continue
                    }
                    return result
                }
            }
            guard count >= 0 else {
                throw CanonicalTreeError.syscall(
                    operation: "read",
                    path: relativePath,
                    errno: errno
                )
            }
            if count == 0 {
                break
            }
            hasher.update(data: Data(buffer[0 ..< count]))
            offset += Int64(count)
            try hook(.afterReadChunk(relativePath: relativePath, offset: offset))
        }
        return HashDigest(
            uncheckedLowercaseSHA256: CanonicalTreeDigest.lowercaseHex(hasher.finalize())
        )
    }

    private func validateOpenedObject(
        _ snapshot: FileSnapshot,
        rootDevice: UInt64,
        path: String,
        requireDirectory: Bool
    ) throws {
        try CanonicalTreeValidation.validateOpenedObject(
            validationProjection(path, snapshot),
            rootDevice: rootDevice,
            path: path,
            requireDirectory: requireDirectory
        )
    }
}

enum CanonicalTreeValidation {
    static func rejectNormalizationCollision(rawNames: [String]) throws {
        var normalizedToRaw: [String: String] = [:]
        for rawName in rawNames {
            let normalized = rawName.precomposedStringWithCanonicalMapping
            if let previous = normalizedToRaw[normalized], !canonicalUTF8Equal(previous, rawName) {
                throw CanonicalTreeError.normalizationCollision(normalized)
            }
            normalizedToRaw[normalized] = rawName
        }
    }

    static func validateSupportedKind(mode: mode_t, path: String = "") throws {
        let kind = mode & mode_t(S_IFMT)
        guard kind == mode_t(S_IFDIR) || kind == mode_t(S_IFREG) else {
            throw CanonicalTreeError.unsupportedObject(path: path)
        }
    }

    static func requireSameDevice(
        rootDevice: UInt64,
        entryDevice: UInt64,
        path: String = ""
    ) throws {
        guard rootDevice == entryDevice else {
            throw CanonicalTreeError.crossDevice(path: path)
        }
    }

    static func validateOpenedObject(
        _ snapshot: FileSnapshot,
        rootDevice: UInt64,
        path: String,
        requireDirectory: Bool
    ) throws {
        try validateSupportedKind(mode: snapshot.rawMode, path: path)
        if requireDirectory, snapshot.kind != mode_t(S_IFDIR) {
            throw CanonicalTreeError.unsupportedObject(path: path)
        }
        let securityBits = mode_t(S_ISUID | S_ISGID | S_ISVTX)
        guard snapshot.rawMode & securityBits == 0 else {
            throw CanonicalTreeError.securityModeBits(path: path)
        }
        try requireSameDevice(rootDevice: rootDevice, entryDevice: snapshot.device, path: path)
        if snapshot.kind == mode_t(S_IFREG), snapshot.linkCount != 1 {
            throw CanonicalTreeError.hardlinkedFile(path: path)
        }
    }
}

private final class OwnedFileDescriptor {
    let rawValue: Int32

    init(_ rawValue: Int32) {
        self.rawValue = rawValue
    }

    deinit {
        close(rawValue)
    }
}

struct FileSnapshot: Equatable {
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

    private init(
        device: UInt64,
        inode: UInt64,
        rawMode: mode_t,
        linkCount: UInt64,
        size: Int64,
        modificationSeconds: Int64,
        modificationNanoseconds: Int64,
        changeSeconds: Int64,
        changeNanoseconds: Int64
    ) {
        self.device = device
        self.inode = inode
        kind = rawMode & mode_t(S_IFMT)
        self.rawMode = rawMode
        self.linkCount = linkCount
        self.size = size
        self.modificationSeconds = modificationSeconds
        self.modificationNanoseconds = modificationNanoseconds
        self.changeSeconds = changeSeconds
        self.changeNanoseconds = changeNanoseconds
    }

    func replacing(device: UInt64? = nil, rawMode: mode_t? = nil) -> FileSnapshot {
        FileSnapshot(
            device: device ?? self.device,
            inode: inode,
            rawMode: rawMode ?? self.rawMode,
            linkCount: linkCount,
            size: size,
            modificationSeconds: modificationSeconds,
            modificationNanoseconds: modificationNanoseconds,
            changeSeconds: changeSeconds,
            changeNanoseconds: changeNanoseconds
        )
    }

    var portableMode: UInt16 {
        UInt16(rawMode & 0o777)
    }

    func sameObjectAndMetadata(as other: FileSnapshot) -> Bool {
        self == other
    }
}

private func descriptorSnapshot(
    _ fd: Int32,
    operation: String,
    path: String
) throws -> FileSnapshot {
    var value = stat()
    guard fstat(fd, &value) == 0 else {
        throw CanonicalTreeError.syscall(operation: operation, path: path, errno: errno)
    }
    return FileSnapshot(value)
}

private func relativeSnapshot(
    parentFD: Int32,
    name: String,
    operation: String,
    path: String
) throws -> FileSnapshot {
    var value = stat()
    let result = name.withCString {
        fstatat(parentFD, $0, &value, AT_SYMLINK_NOFOLLOW)
    }
    guard result == 0 else {
        throw CanonicalTreeError.syscall(operation: operation, path: path, errno: errno)
    }
    return FileSnapshot(value)
}
