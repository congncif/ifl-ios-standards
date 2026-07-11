import Darwin
import Foundation

enum DescriptorObjectKind: String, Hashable, Sendable {
    case regularFile = "regular_file"
    case directory
    case symbolicLink = "symbolic_link"
    case other
}

struct DescriptorObjectMetadata: Hashable, Sendable {
    let device: UInt64
    let inode: UInt64
    let kind: DescriptorObjectKind
    let permissions: mode_t
    let linkCount: UInt64

    func hasSameIdentity(as other: DescriptorObjectMetadata) -> Bool {
        device == other.device && inode == other.inode && kind == other.kind
    }
}

final class DescriptorRelativeDirectory: @unchecked Sendable {
    let fd: Int32
    let metadata: DescriptorObjectMetadata
    let parent: DescriptorRelativeDirectory?
    let component: String?

    init(
        fd: Int32,
        metadata: DescriptorObjectMetadata,
        parent: DescriptorRelativeDirectory? = nil,
        component: String? = nil
    ) {
        self.fd = fd
        self.metadata = metadata
        self.parent = parent
        self.component = component
    }

    deinit {
        _ = Darwin.close(fd)
    }
}

final class DescriptorRelativeFile: @unchecked Sendable {
    let fd: Int32
    let metadata: DescriptorObjectMetadata
    let parent: DescriptorRelativeDirectory

    init(fd: Int32, metadata: DescriptorObjectMetadata, parent: DescriptorRelativeDirectory) {
        self.fd = fd
        self.metadata = metadata
        self.parent = parent
    }

    deinit {
        _ = Darwin.close(fd)
    }
}

enum DescriptorRelativeOperationPoint: Hashable, Sendable {
    case directoryOpened
    case destinationValidated
    case beforeRename
    case afterSwapBeforeCleanup
}

struct DescriptorRelativeOperationHook: @unchecked Sendable {
    private let handler: @Sendable (DescriptorRelativeOperationPoint) throws -> Void

    init(_ handler: @escaping @Sendable (DescriptorRelativeOperationPoint) throws -> Void) {
        self.handler = handler
    }

    static var none: DescriptorRelativeOperationHook {
        DescriptorRelativeOperationHook { _ in }
    }

    func call(_ point: DescriptorRelativeOperationPoint) throws {
        try handler(point)
    }
}

struct DescriptorDirectoryCreation {
    let parent: DescriptorRelativeDirectory
    let child: DescriptorRelativeDirectory
    let created: Bool
}

struct DescriptorEntryIdentity: Hashable, Sendable {
    let metadata: DescriptorObjectMetadata
}

enum DescriptorDestinationExpectation: Hashable, Sendable {
    case absent
    case exact(DescriptorEntryIdentity)
}

struct DescriptorNamespaceReplacement: Hashable, @unchecked Sendable {
    let quarantineName: String
    let identity: DescriptorEntryIdentity
    let file: DescriptorRelativeFile
    let parent: DescriptorRelativeDirectory
    let components: [String]
    let temporaryName: String

    static func == (
        lhs: DescriptorNamespaceReplacement,
        rhs: DescriptorNamespaceReplacement
    ) -> Bool {
        lhs.quarantineName == rhs.quarantineName
            && lhs.identity == rhs.identity
            && lhs.parent.metadata == rhs.parent.metadata
            && lhs.components == rhs.components
            && lhs.temporaryName == rhs.temporaryName
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(quarantineName)
        hasher.combine(identity)
        hasher.combine(parent.metadata)
        hasher.combine(components)
        hasher.combine(temporaryName)
    }
}

final class DescriptorRelativeFileSystem: @unchecked Sendable {
    private let rootFD: Int32
    private let rootMetadata: DescriptorObjectMetadata

    init(rootURL: URL) throws {
        guard rootURL.isFileURL, rootURL.path.hasPrefix("/") else {
            throw PersistenceError.invalidPathComponent
        }
        var pathMetadata = stat()
        guard lstat(rootURL.path, &pathMetadata) == 0 else {
            throw persistencePOSIXError(errno)
        }
        guard descriptorKind(mode: pathMetadata.st_mode) == .directory else {
            throw PersistenceError.integrityViolation
        }
        let fd = try retryingDescriptorCall {
            Darwin.open(rootURL.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        }
        do {
            let opened = try descriptorMetadata(fd)
            guard opened.kind == .directory,
                  opened.device == UInt64(pathMetadata.st_dev),
                  opened.inode == UInt64(pathMetadata.st_ino)
            else { throw PersistenceError.integrityViolation }
            rootFD = fd
            rootMetadata = opened
        } catch {
            _ = Darwin.close(fd)
            throw error
        }
    }

    deinit {
        _ = Darwin.close(rootFD)
    }

    func createDirectories(_ components: [String], mode: mode_t) throws {
        var prefix: [String] = []
        for component in components {
            _ = try ensureDirectory(component, in: prefix, mode: mode)
            prefix.append(component)
        }
    }

    func writeExclusive(
        _ data: Data,
        named name: String,
        in components: [String],
        mode: mode_t,
        hook: DescriptorRelativeOperationHook = .none
    ) throws {
        _ = try createFile(
            data: data,
            named: name,
            in: components,
            mode: mode,
            hook: hook
        )
    }

    func readFile(named name: String, in components: [String]) throws -> Data {
        try readFileIfPresent(named: name, in: components).unwrap(
            or: PersistenceError.notFound
        )
    }

    func replaceFile(
        temporaryName: String,
        destinationName: String,
        in components: [String],
        expectedDestination: DescriptorDestinationExpectation,
        hook: DescriptorRelativeOperationHook = .none
    ) throws -> DescriptorNamespaceReplacement? {
        try validatePersistenceComponent(temporaryName)
        try validatePersistenceComponent(destinationName)
        let directory = try openDirectory(components)
        let temporary = try openRegularFile(
            named: temporaryName,
            in: directory,
            flags: O_RDONLY
        )
        defer { _ = Darwin.close(temporary.fd) }
        let destination = try openOptionalRegularFile(
            named: destinationName,
            in: directory,
            flags: O_RDONLY
        )
        defer {
            if let destination { _ = Darwin.close(destination.fd) }
        }
        guard destinationMatchesExpectation(
            destination?.metadata,
            expectation: expectedDestination
        ) else { throw PersistenceError.integrityViolation }
        try hook.call(.destinationValidated)

        let currentTemporary = try openRegularFile(
            named: temporaryName,
            in: directory,
            flags: O_RDONLY
        )
        defer { _ = Darwin.close(currentTemporary.fd) }
        guard currentTemporary.metadata == temporary.metadata else {
            throw PersistenceError.integrityViolation
        }
        let currentDestination = try openOptionalRegularFile(
            named: destinationName,
            in: directory,
            flags: O_RDONLY
        )
        defer {
            if let currentDestination { _ = Darwin.close(currentDestination.fd) }
        }
        guard currentDestination?.metadata == destination?.metadata,
              destinationMatchesExpectation(
                  currentDestination?.metadata,
                  expectation: expectedDestination
              )
        else {
            throw PersistenceError.integrityViolation
        }
        try hook.call(.beforeRename)
        try validateAncestry(directory)

        let flags: UInt32 = destination == nil
            ? UInt32(RENAME_EXCL | RENAME_NOFOLLOW_ANY)
            : UInt32(RENAME_SWAP | RENAME_NOFOLLOW_ANY)
        try withValidatedCString(temporaryName) { temporaryCString in
            try withValidatedCString(destinationName) { destinationCString in
                try retryingZeroCall {
                    renameatx_np(
                        directory.fd,
                        temporaryCString,
                        directory.fd,
                        destinationCString,
                        flags
                    )
                }
            }
        }
        let postRenameIsValid: Bool
        do {
            postRenameIsValid = try validatePostRename(
                temporaryName: temporaryName,
                destinationName: destinationName,
                directory: directory,
                expectedTemporary: currentTemporary.metadata,
                expectedDestination: destination?.metadata
            )
        } catch {
            try rollbackRename(
                temporaryName: temporaryName,
                destinationName: destinationName,
                directory: directory,
                hadDestination: destination != nil
            )
            throw PersistenceError.integrityViolation
        }
        guard postRenameIsValid else {
            try rollbackRename(
                temporaryName: temporaryName,
                destinationName: destinationName,
                directory: directory,
                hadDestination: destination != nil
            )
            throw PersistenceError.integrityViolation
        }
        guard let destination else { return nil }
        try hook.call(.afterSwapBeforeCleanup)
        let displacedFD = try retryingDescriptorCall {
            fcntl(destination.fd, F_DUPFD_CLOEXEC, 0)
        }
        let displacedFile = DescriptorRelativeFile(
            fd: displacedFD,
            metadata: destination.metadata,
            parent: directory
        )
        return DescriptorNamespaceReplacement(
            quarantineName: namespaceQuarantineName(
                for: DescriptorEntryIdentity(metadata: destination.metadata)
            ),
            identity: DescriptorEntryIdentity(metadata: destination.metadata),
            file: displacedFile,
            parent: directory,
            components: components,
            temporaryName: temporaryName
        )
    }

    func destinationExpectation(
        named name: String,
        in components: [String]
    ) throws -> DescriptorDestinationExpectation {
        try validatePersistenceComponent(name)
        let directory = try openDirectory(components)
        try validateAncestry(directory)
        guard let opened = try openOptionalRegularFile(
            named: name,
            in: directory,
            flags: O_RDONLY
        ) else { return .absent }
        defer { _ = Darwin.close(opened.fd) }
        return .exact(DescriptorEntryIdentity(metadata: opened.metadata))
    }

    func namespaceReplacement(
        temporaryName: String,
        in components: [String],
        expectedIdentity: DescriptorEntryIdentity
    ) throws -> DescriptorNamespaceReplacement {
        try validatePersistenceComponent(temporaryName)
        let directory = try openDirectory(components)
        try validateAncestry(directory)
        let quarantineName = namespaceQuarantineName(for: expectedIdentity)
        let source = try openOptionalRegularFile(
            named: temporaryName,
            in: directory,
            flags: O_RDONLY
        )
        let quarantine = try openOptionalRegularFile(
            named: quarantineName,
            in: directory,
            flags: O_RDONLY
        )
        guard (source == nil) != (quarantine == nil) else {
            if let source { _ = Darwin.close(source.fd) }
            if let quarantine { _ = Darwin.close(quarantine.fd) }
            throw PersistenceError.integrityViolation
        }
        guard let opened = source ?? quarantine else {
            throw PersistenceError.integrityViolation
        }
        guard opened.metadata == expectedIdentity.metadata else {
            _ = Darwin.close(opened.fd)
            throw PersistenceError.integrityViolation
        }
        let file = DescriptorRelativeFile(
            fd: opened.fd,
            metadata: opened.metadata,
            parent: directory
        )
        return DescriptorNamespaceReplacement(
            quarantineName: quarantineName,
            identity: expectedIdentity,
            file: file,
            parent: directory,
            components: components,
            temporaryName: temporaryName
        )
    }

    @discardableResult
    func validateNamespaceQuarantine(
        named name: String,
        in components: [String]
    ) throws -> DescriptorEntryIdentity {
        try validatePersistenceComponent(name)
        let directory = try openDirectory(components)
        try validateAncestry(directory)
        let opened = try openRegularFile(named: name, in: directory, flags: O_RDONLY)
        defer { _ = Darwin.close(opened.fd) }
        let identity = DescriptorEntryIdentity(metadata: opened.metadata)
        guard opened.metadata.kind == .regularFile,
              opened.metadata.device == rootMetadata.device,
              opened.metadata.permissions == 0o600,
              opened.metadata.linkCount == 1,
              name == namespaceQuarantineName(for: identity)
        else { throw PersistenceError.integrityViolation }
        return identity
    }

    func quarantineNamespaceReplacement(
        _ replacement: DescriptorNamespaceReplacement,
        hook: DescriptorRelativeOperationHook = .none
    ) throws {
        try validateAncestry(replacement.parent)
        guard replacement.file.metadata == replacement.identity.metadata,
              try descriptorMetadata(replacement.file.fd).hasSameIdentity(
                  as: replacement.identity.metadata
              )
        else { throw PersistenceError.integrityViolation }
        let source = try entryMetadataIfPresent(
            named: replacement.temporaryName,
            in: replacement.parent
        )
        let quarantine = try entryMetadataIfPresent(
            named: replacement.quarantineName,
            in: replacement.parent
        )
        if source == nil {
            guard quarantine == replacement.identity.metadata else {
                throw PersistenceError.integrityViolation
            }
            return
        }
        guard source == replacement.identity.metadata, quarantine == nil else {
            throw PersistenceError.integrityViolation
        }
        try hook.call(.beforeRename)
        try withValidatedCString(replacement.temporaryName) { sourcePointer in
            try withValidatedCString(replacement.quarantineName) { quarantinePointer in
                try retryingZeroCall {
                    renameatx_np(
                        replacement.parent.fd,
                        sourcePointer,
                        replacement.parent.fd,
                        quarantinePointer,
                        UInt32(RENAME_EXCL | RENAME_NOFOLLOW_ANY)
                    )
                }
            }
        }
        guard try entryMetadataIfPresent(
            named: replacement.temporaryName,
            in: replacement.parent
        ) == nil,
        try entryMetadata(
            named: replacement.quarantineName,
            in: replacement.parent
        ) == replacement.identity.metadata,
        try descriptorMetadata(replacement.file.fd).hasSameIdentity(
            as: replacement.identity.metadata
        )
        else {
            throw PersistenceError.integrityViolation
        }
        try validateAncestry(replacement.parent)
    }

    private func destinationMatchesExpectation(
        _ metadata: DescriptorObjectMetadata?,
        expectation: DescriptorDestinationExpectation
    ) -> Bool {
        switch expectation {
        case .absent:
            metadata == nil
        case let .exact(identity):
            metadata == identity.metadata
        }
    }

    private func namespaceQuarantineName(
        for identity: DescriptorEntryIdentity
    ) -> String {
        ".quarantine-\(String(identity.metadata.device, radix: 16))-\(String(identity.metadata.inode, radix: 16)).tmp"
    }

    func rootDirectory() throws -> DescriptorRelativeDirectory {
        let independent = try ".".withCString { pointer in
            try retryingDescriptorCall {
                openat(
                    rootFD,
                    pointer,
                    O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK
                )
            }
        }
        do {
            let metadata = try descriptorMetadata(independent)
            guard metadata.hasSameIdentity(as: rootMetadata),
                  metadata.permissions == rootMetadata.permissions
            else {
                throw PersistenceError.integrityViolation
            }
            return DescriptorRelativeDirectory(fd: independent, metadata: metadata)
        } catch {
            _ = Darwin.close(independent)
            throw error
        }
    }

    func openDirectory(
        _ components: [String],
        requiredMode: mode_t? = nil
    ) throws -> DescriptorRelativeDirectory {
        var current = try rootDirectory()
        for component in components {
            try validatePersistenceComponent(component)
            try validateAncestry(current)
            let entry = try entryMetadata(named: component, in: current)
            guard entry.kind == .directory,
                  entry.device == rootMetadata.device
            else { throw PersistenceError.integrityViolation }
            let nextFD = try withValidatedCString(component) { pointer in
                try retryingDescriptorCall {
                    openat(
                        current.fd,
                        pointer,
                        O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK
                    )
                }
            }
            do {
                let metadata = try descriptorMetadata(nextFD)
                guard metadata.kind == .directory,
                      metadata.device == rootMetadata.device,
                      metadata.hasSameIdentity(as: entry)
                else { throw PersistenceError.integrityViolation }
                current = DescriptorRelativeDirectory(
                    fd: nextFD,
                    metadata: metadata,
                    parent: current,
                    component: component
                )
                try validateAncestry(current)
            } catch {
                _ = Darwin.close(nextFD)
                throw error
            }
        }
        if let requiredMode, current.metadata.permissions != requiredMode {
            throw PersistenceError.integrityViolation
        }
        try validateAncestry(current)
        return current
    }

    func validateRetainedDirectory(
        _ directory: DescriptorRelativeDirectory,
        requiredMode: mode_t? = nil
    ) throws {
        try validateAncestry(directory)
        let current = try descriptorMetadata(directory.fd)
        guard current.hasSameIdentity(as: directory.metadata),
              current.permissions == directory.metadata.permissions,
              requiredMode.map({ current.permissions == $0 }) ?? true
        else { throw PersistenceError.integrityViolation }
    }

    func openDirectory(
        _ component: String,
        in parent: DescriptorRelativeDirectory,
        requiredMode: mode_t
    ) throws -> DescriptorRelativeDirectory {
        try validatePersistenceComponent(component)
        try validateRetainedDirectory(parent)
        let entry = try entryMetadata(named: component, in: parent)
        guard entry.kind == .directory,
              entry.device == rootMetadata.device,
              entry.permissions == requiredMode
        else { throw PersistenceError.integrityViolation }
        let fd = try withValidatedCString(component) { pointer in
            try retryingDescriptorCall {
                openat(
                    parent.fd,
                    pointer,
                    O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK
                )
            }
        }
        do {
            let metadata = try descriptorMetadata(fd)
            guard metadata == entry else { throw PersistenceError.integrityViolation }
            let child = DescriptorRelativeDirectory(
                fd: fd,
                metadata: metadata,
                parent: parent,
                component: component
            )
            try validateRetainedDirectory(child, requiredMode: requiredMode)
            return child
        } catch {
            _ = Darwin.close(fd)
            throw error
        }
    }

    func ensureDirectory(
        _ component: String,
        in parent: DescriptorRelativeDirectory,
        mode: mode_t
    ) throws -> DescriptorDirectoryCreation {
        try validatePersistenceComponent(component)
        try validateRetainedDirectory(parent)
        let created = try withValidatedCString(component) { pointer -> Bool in
            while true {
                if mkdirat(parent.fd, pointer, mode) == 0 { return true }
                if errno == EINTR { continue }
                if errno == EEXIST { return false }
                throw persistencePOSIXError(errno)
            }
        }
        let child = try openDirectory(component, in: parent, requiredMode: mode)
        try validateRetainedDirectory(parent)
        return DescriptorDirectoryCreation(parent: parent, child: child, created: created)
    }

    func ensureDirectory(
        _ component: String,
        in parentComponents: [String],
        mode: mode_t
    ) throws -> DescriptorDirectoryCreation {
        try validatePersistenceComponent(component)
        let parent = try openDirectory(parentComponents)
        try validateAncestry(parent)
        let created = try withValidatedCString(component) { pointer -> Bool in
            while true {
                if mkdirat(parent.fd, pointer, mode) == 0 { return true }
                if errno == EINTR { continue }
                if errno == EEXIST { return false }
                throw persistencePOSIXError(errno)
            }
        }
        let childFD = try withValidatedCString(component) { pointer in
            try retryingDescriptorCall {
                openat(
                    parent.fd,
                    pointer,
                    O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK
                )
            }
        }
        do {
            let metadata = try descriptorMetadata(childFD)
            guard metadata.kind == .directory,
                  metadata.device == rootMetadata.device,
                  metadata.permissions == mode
            else { throw PersistenceError.integrityViolation }
            let child = DescriptorRelativeDirectory(
                fd: childFD,
                metadata: metadata,
                parent: parent,
                component: component
            )
            try validateAncestry(child)
            return DescriptorDirectoryCreation(
                parent: parent,
                child: child,
                created: created
            )
        } catch {
            _ = Darwin.close(childFD)
            throw error
        }
    }

    func createFile(
        data: Data,
        named name: String,
        in components: [String],
        mode: mode_t,
        hook: DescriptorRelativeOperationHook = .none
    ) throws -> DescriptorRelativeFile {
        try validatePersistenceComponent(name)
        let directory = try openDirectory(components)
        try hook.call(.directoryOpened)
        try validateAncestry(directory)
        let fd = try withValidatedCString(name) { pointer in
            try retryingDescriptorCall {
                openat(
                    directory.fd,
                    pointer,
                    O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK,
                    mode
                )
            }
        }
        do {
            try writeAll(data, to: fd)
            let metadata = try descriptorMetadata(fd)
            guard metadata.kind == .regularFile,
                  metadata.device == rootMetadata.device,
                  metadata.permissions == mode,
                  metadata.linkCount == 1
            else { throw PersistenceError.integrityViolation }
            try validateAncestry(directory)
            let entry = try entryMetadata(named: name, in: directory)
            guard entry == metadata else { throw PersistenceError.integrityViolation }
            return DescriptorRelativeFile(fd: fd, metadata: metadata, parent: directory)
        } catch {
            let opened = try? descriptorMetadata(fd)
            if let current = try? entryMetadata(named: name, in: directory),
               let opened,
               current.hasSameIdentity(as: opened)
            {
                try? removeRetainedExpectedFile(
                    named: name,
                    in: directory,
                    expectedMetadata: current,
                    retainedFD: fd
                )
            }
            _ = Darwin.close(fd)
            throw error
        }
    }

    func openFile(named name: String, in components: [String]) throws -> DescriptorRelativeFile {
        try validatePersistenceComponent(name)
        let directory = try openDirectory(components)
        try validateAncestry(directory)
        let opened = try openRegularFile(named: name, in: directory, flags: O_RDONLY)
        return DescriptorRelativeFile(fd: opened.fd, metadata: opened.metadata, parent: directory)
    }

    func readFileIfPresent(named name: String, in components: [String]) throws -> Data? {
        try validatePersistenceComponent(name)
        let directory = try openDirectory(components)
        try validateAncestry(directory)
        guard let opened = try openOptionalRegularFile(named: name, in: directory, flags: O_RDONLY)
        else { return nil }
        defer { _ = Darwin.close(opened.fd) }
        return try readAll(from: opened.fd)
    }

    func removeFileIfPresent(named name: String, in components: [String]) throws -> Bool {
        try validatePersistenceComponent(name)
        do {
            let identity = try entryIdentity(named: name, in: components)
            try removeExpectedFile(named: name, in: components, expectedIdentity: identity)
            return true
        } catch let error as PersistenceError where error == .ioFailure(ENOENT) {
            return false
        }
    }

    func listEntries(in components: [String]) throws -> [String] {
        let directory = try openDirectory(components)
        try validateAncestry(directory)
        let independent = try ".".withCString { pointer in
            try retryingDescriptorCall {
                openat(
                    directory.fd,
                    pointer,
                    O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK
                )
            }
        }
        do {
            let metadata = try descriptorMetadata(independent)
            guard metadata.hasSameIdentity(as: directory.metadata),
                  metadata.permissions == directory.metadata.permissions
            else { throw PersistenceError.integrityViolation }
        } catch {
            _ = Darwin.close(independent)
            throw error
        }
        guard let stream = fdopendir(independent) else {
            _ = Darwin.close(independent)
            throw persistencePOSIXError(errno)
        }
        defer { _ = closedir(stream) }
        var names: [String] = []
        while true {
            errno = 0
            guard let entry = readdir(stream) else {
                if errno != 0 { throw persistencePOSIXError(errno) }
                break
            }
            let length = Int(entry.pointee.d_namlen)
            var nameStorage = entry.pointee.d_name
            let name = withUnsafePointer(to: &nameStorage) { pointer in
                pointer.withMemoryRebound(to: CChar.self, capacity: length + 1) {
                    String(cString: $0)
                }
            }
            if name == "." || name == ".." { continue }
            try validatePersistenceComponent(name)
            names.append(name)
        }
        try validateAncestry(directory)
        return names.sorted()
    }

    func entryIdentity(
        named name: String,
        in components: [String]
    ) throws -> DescriptorEntryIdentity {
        try validatePersistenceComponent(name)
        let directory = try openDirectory(components)
        try validateAncestry(directory)
        let metadata = try entryMetadata(named: name, in: directory)
        guard metadata.kind == .regularFile,
              metadata.device == rootMetadata.device,
              metadata.linkCount == 1
        else { throw PersistenceError.integrityViolation }
        return DescriptorEntryIdentity(metadata: metadata)
    }

    func removeExpectedFile(
        named name: String,
        in components: [String],
        expectedIdentity: DescriptorEntryIdentity
    ) throws {
        let replacement = try namespaceReplacement(
            temporaryName: name,
            in: components,
            expectedIdentity: expectedIdentity
        )
        try quarantineNamespaceReplacement(replacement)
    }

    private func openRegularFile(
        named name: String,
        in directory: DescriptorRelativeDirectory,
        flags: Int32
    ) throws -> (fd: Int32, metadata: DescriptorObjectMetadata) {
        try validateAncestry(directory)
        let preflight = try entryMetadata(named: name, in: directory)
        guard preflight.kind == .regularFile,
              preflight.device == rootMetadata.device,
              preflight.linkCount == 1
        else { throw PersistenceError.integrityViolation }
        let fd = try withValidatedCString(name) { pointer in
            try retryingDescriptorCall {
                openat(
                    directory.fd,
                    pointer,
                    flags | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK | O_NOCTTY
                )
            }
        }
        do {
            let metadata = try descriptorMetadata(fd)
            guard metadata.kind == .regularFile,
                  metadata.device == rootMetadata.device,
                  metadata.linkCount == 1,
                  metadata.hasSameIdentity(as: preflight)
            else { throw PersistenceError.integrityViolation }
            try validateAncestry(directory)
            guard try entryMetadata(named: name, in: directory) == metadata else {
                throw PersistenceError.integrityViolation
            }
            return (fd, metadata)
        } catch {
            _ = Darwin.close(fd)
            throw error
        }
    }

    private func openOptionalRegularFile(
        named name: String,
        in directory: DescriptorRelativeDirectory,
        flags: Int32
    ) throws -> (fd: Int32, metadata: DescriptorObjectMetadata)? {
        do {
            return try openRegularFile(named: name, in: directory, flags: flags)
        } catch let error as PersistenceError {
            if case .ioFailure(ENOENT) = error { return nil }
            throw error
        }
    }

    private func removeRetainedExpectedFile(
        named name: String,
        in directory: DescriptorRelativeDirectory,
        expectedMetadata: DescriptorObjectMetadata,
        retainedFD: Int32
    ) throws {
        guard try entryMetadata(named: name, in: directory) == expectedMetadata,
              try descriptorMetadata(retainedFD).hasSameIdentity(as: expectedMetadata)
        else { throw PersistenceError.integrityViolation }
        let quarantine = namespaceQuarantineName(
            for: DescriptorEntryIdentity(metadata: expectedMetadata)
        )
        try withValidatedCString(name) { source in
            try withValidatedCString(quarantine) { destination in
                try retryingZeroCall {
                    renameatx_np(
                        directory.fd,
                        source,
                        directory.fd,
                        destination,
                        UInt32(RENAME_EXCL | RENAME_NOFOLLOW_ANY)
                    )
                }
            }
        }
        guard try entryMetadata(named: quarantine, in: directory) == expectedMetadata else {
            throw PersistenceError.integrityViolation
        }
        guard try entryMetadataIfPresent(named: name, in: directory) == nil,
              try descriptorMetadata(retainedFD).hasSameIdentity(as: expectedMetadata)
        else {
            throw PersistenceError.integrityViolation
        }
    }

    private func entryMetadata(
        named name: String,
        in directory: DescriptorRelativeDirectory
    ) throws -> DescriptorObjectMetadata {
        try withValidatedCString(name) { pointer in
            var value = stat()
            while true {
                if fstatat(directory.fd, pointer, &value, AT_SYMLINK_NOFOLLOW) == 0 {
                    return metadata(from: value)
                }
                if errno == EINTR { continue }
                throw persistencePOSIXError(errno)
            }
        }
    }

    private func entryMetadataIfPresent(
        named name: String,
        in directory: DescriptorRelativeDirectory
    ) throws -> DescriptorObjectMetadata? {
        do {
            return try entryMetadata(named: name, in: directory)
        } catch let error as PersistenceError where error == .ioFailure(ENOENT) {
            return nil
        }
    }

    private func validateAncestry(_ directory: DescriptorRelativeDirectory) throws {
        guard let parent = directory.parent, let component = directory.component else {
            let current = try descriptorMetadata(directory.fd)
            guard current.hasSameIdentity(as: rootMetadata),
                  current.kind == .directory
            else { throw PersistenceError.integrityViolation }
            return
        }
        try validateAncestry(parent)
        let entry = try entryMetadata(named: component, in: parent)
        let current = try descriptorMetadata(directory.fd)
        guard entry.hasSameIdentity(as: current),
              entry.permissions == current.permissions,
              current.hasSameIdentity(as: directory.metadata),
              current.permissions == directory.metadata.permissions,
              current.kind == .directory,
              current.device == rootMetadata.device
        else { throw PersistenceError.integrityViolation }
    }

    private func validatePostRename(
        temporaryName: String,
        destinationName: String,
        directory: DescriptorRelativeDirectory,
        expectedTemporary: DescriptorObjectMetadata,
        expectedDestination: DescriptorObjectMetadata?
    ) throws -> Bool {
        let moved = try openRegularFile(
            named: destinationName,
            in: directory,
            flags: O_RDONLY
        )
        defer { _ = Darwin.close(moved.fd) }
        guard moved.metadata == expectedTemporary else { return false }
        let displaced = try openOptionalRegularFile(
            named: temporaryName,
            in: directory,
            flags: O_RDONLY
        )
        defer {
            if let displaced { _ = Darwin.close(displaced.fd) }
        }
        return displaced?.metadata == expectedDestination
    }

    private func rollbackRename(
        temporaryName: String,
        destinationName: String,
        directory: DescriptorRelativeDirectory,
        hadDestination: Bool
    ) throws {
        let flags: UInt32 = hadDestination
            ? UInt32(RENAME_SWAP | RENAME_NOFOLLOW_ANY)
            : UInt32(RENAME_EXCL | RENAME_NOFOLLOW_ANY)
        try withValidatedCString(destinationName) { destinationCString in
            try withValidatedCString(temporaryName) { temporaryCString in
                try retryingZeroCall {
                    renameatx_np(
                        directory.fd,
                        destinationCString,
                        directory.fd,
                        temporaryCString,
                        flags
                    )
                }
            }
        }
    }
}

private func validatePersistenceComponent(_ value: String) throws {
    guard isValidatedPersistenceComponent(value) else {
        throw PersistenceError.invalidPathComponent
    }
}

private func withValidatedCString<T>(
    _ value: String,
    _ body: (UnsafePointer<CChar>) throws -> T
) throws -> T {
    try validatePersistenceComponent(value)
    return try value.withCString(body)
}

private func descriptorKind(mode: mode_t) -> DescriptorObjectKind {
    switch mode & mode_t(S_IFMT) {
    case mode_t(S_IFREG): .regularFile
    case mode_t(S_IFDIR): .directory
    case mode_t(S_IFLNK): .symbolicLink
    default: .other
    }
}

private func descriptorMetadata(_ fd: Int32) throws -> DescriptorObjectMetadata {
    var value = stat()
    while true {
        if fstat(fd, &value) == 0 { break }
        if errno == EINTR { continue }
        throw persistencePOSIXError(errno)
    }
    return metadata(from: value)
}

private func metadata(from value: stat) -> DescriptorObjectMetadata {
    DescriptorObjectMetadata(
        device: UInt64(value.st_dev),
        inode: UInt64(value.st_ino),
        kind: descriptorKind(mode: value.st_mode),
        permissions: value.st_mode & 0o777,
        linkCount: UInt64(value.st_nlink)
    )
}

private func retryingDescriptorCall(_ body: () -> Int32) throws -> Int32 {
    while true {
        let result = body()
        if result >= 0 { return result }
        if errno == EINTR { continue }
        throw persistencePOSIXError(errno)
    }
}

private func retryingZeroCall(_ body: () -> Int32) throws {
    while true {
        if body() == 0 { return }
        if errno == EINTR { continue }
        throw persistencePOSIXError(errno)
    }
}

private func writeAll(_ data: Data, to fd: Int32) throws {
    try data.withUnsafeBytes { rawBuffer in
        guard let base = rawBuffer.baseAddress else { return }
        var offset = 0
        while offset < rawBuffer.count {
            let written = Darwin.write(fd, base.advanced(by: offset), rawBuffer.count - offset)
            if written > 0 {
                offset += written
            } else if written < 0, errno == EINTR {
                continue
            } else {
                throw persistencePOSIXError(errno)
            }
        }
    }
}

private func readAll(from fd: Int32) throws -> Data {
    guard lseek(fd, 0, SEEK_SET) >= 0 else { throw persistencePOSIXError(errno) }
    var result = Data()
    var buffer = [UInt8](repeating: 0, count: 16 * 1024)
    while true {
        let count = Darwin.read(fd, &buffer, buffer.count)
        if count > 0 {
            result.append(contentsOf: buffer.prefix(count))
        } else if count == 0 {
            return result
        } else if errno == EINTR {
            continue
        } else {
            throw persistencePOSIXError(errno)
        }
    }
}

func persistencePOSIXError(_ code: Int32) -> PersistenceError {
    switch code {
    case ELOOP, ENOTDIR, EXDEV, EMLINK:
        .integrityViolation
    default:
        .ioFailure(code)
    }
}

private extension Optional {
    func unwrap(or error: @autoclosure () -> any Error) throws -> Wrapped {
        guard let self else { throw error() }
        return self
    }
}
