import Darwin
import Foundation

final class FileLock: @unchecked Sendable {
    private let file: DescriptorRelativeFile
    private var isLocked: Bool

    private init(file: DescriptorRelativeFile) throws {
        self.file = file
        isLocked = false
        while true {
            if flock(file.fd, LOCK_EX | LOCK_NB) == 0 {
                isLocked = true
                return
            }
            if errno == EINTR { continue }
            if errno == EWOULDBLOCK { throw PersistenceError.blockedEnvironment }
            throw persistencePOSIXError(errno)
        }
    }

    deinit {
        if isLocked { _ = flock(file.fd, LOCK_UN) }
    }

    static func acquire(
        in fileSystem: DescriptorRelativeFileSystem,
        expectedIdentity: DescriptorEntryIdentity
    ) throws -> FileLock {
        let file = try fileSystem.openFile(named: "writer.lock", in: [])
        guard file.metadata == expectedIdentity.metadata,
              file.metadata.permissions == 0o600,
              file.metadata.linkCount == 1,
              try fileSystem.entryIdentity(named: "writer.lock", in: []) == expectedIdentity
        else { throw PersistenceError.integrityViolation }
        return try FileLock(file: file)
    }
}
