import Darwin
import Foundation

public enum PrivateStorageError: LocalizedError {
    case unsafePath, inaccessible, tooLarge
    public var errorDescription: String? {
        switch self {
        case .unsafePath:
            return "The ProfileDock data location is not a regular, user-owned file or directory. It has been left unchanged."
        case .inaccessible:
            return "ProfileDock could not access its private data folder."
        case .tooLarge:
            return "The saved ProfileDock file exceeds the supported size. It has been left unchanged."
        }
    }
}

/// Only touches the explicitly supplied app-owned root, an optional immediate
/// child directory and named files. Never walks or changes the user's folders.
/// Directory descriptors keep leaf operations relative to the checked folder.
public struct PrivateStorage {
    public let directory: URL
    public init(directory: URL) { self.directory = directory }

    public func prepare() throws {
        let descriptor = try openDirectory()
        close(descriptor)
    }

    @discardableResult
    public func prepareSubdirectory(_ name: String) throws -> URL {
        let descriptor = try openDirectory(subdirectory: name)
        close(descriptor)
        return directory.appendingPathComponent(name, isDirectory: true)
    }

    public func readFile(_ name: String, subdirectory: String? = nil,
                         maximumBytes: Int = 16_000_000) throws -> Data? {
        try Self.validateName(name)
        guard maximumBytes >= 0 else { throw PrivateStorageError.unsafePath }
        let directoryFD = try openDirectory(subdirectory: subdirectory)
        defer { close(directoryFD) }
        // NONBLOCK avoids hanging on a FIFO before fstat can reject it.
        let fileFD = name.withCString { openat(directoryFD, $0, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC) }
        guard fileFD >= 0 else {
            if errno == ENOENT { return nil }
            throw Self.failure()
        }
        defer { close(fileFD) }
        var information = stat()
        guard fstat(fileFD, &information) == 0 else { throw PrivateStorageError.inaccessible }
        try Self.validateFile(information)
        guard information.st_size >= 0, information.st_size <= maximumBytes else { throw PrivateStorageError.tooLarge }
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 65_536)
        while true {
            let count = buffer.withUnsafeMutableBytes { Darwin.read(fileFD, $0.baseAddress, $0.count) }
            if count < 0 {
                if errno == EINTR { continue }
                throw PrivateStorageError.inaccessible
            }
            if count == 0 { return result }
            guard count <= maximumBytes - result.count else { throw PrivateStorageError.tooLarge }
            result.append(contentsOf: buffer.prefix(count))
        }
    }

    /// Atomically replaces a regular owned file, with 0600 on every replacement.
    /// A rejected destination is neither followed nor overwritten.
    public func write(_ data: Data, to name: String, subdirectory: String? = nil) throws {
        try Self.validateName(name)
        let directoryFD = try openDirectory(subdirectory: subdirectory)
        defer { close(directoryFD) }
        try Self.validateDestination(name, in: directoryFD)
        let temporary = ".profiledock-write-" + UUID().uuidString
        let fileFD = temporary.withCString {
            openat(directoryFD, $0, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, mode_t(0o600))
        }
        guard fileFD >= 0 else { throw Self.failure() }
        defer {
            close(fileFD)
            _ = temporary.withCString { unlinkat(directoryFD, $0, 0) }
        }
        guard fchmod(fileFD, mode_t(0o600)) == 0 else { throw PrivateStorageError.inaccessible }
        try data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                let count = Darwin.write(fileFD, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
                if count < 0 {
                    if errno == EINTR { continue }
                    throw PrivateStorageError.inaccessible
                }
                guard count > 0 else { throw PrivateStorageError.inaccessible }
                offset += count
            }
        }
        guard fsync(fileFD) == 0 else { throw PrivateStorageError.inaccessible }
        // Recheck after preparation. renameat replaces the directory entry and
        // cannot write through a leaf symlink even if this same-user race occurs.
        try Self.validateDestination(name, in: directoryFD)
        let installed = temporary.withCString { source in
            name.withCString { destination in renameat(directoryFD, source, directoryFD, destination) }
        }
        guard installed == 0 else { throw Self.failure() }
    }

    /// For rolling back a newly created image. Missing files are harmless;
    /// symlinks, directories and other nonregular entries are rejected.
    public func removeFile(_ name: String, subdirectory: String? = nil) throws {
        try Self.validateName(name)
        let directoryFD = try openDirectory(subdirectory: subdirectory)
        defer { close(directoryFD) }
        try Self.validateDestination(name, in: directoryFD)
        let removed = name.withCString { unlinkat(directoryFD, $0, 0) }
        guard removed == 0 || errno == ENOENT else { throw Self.failure() }
    }

    private func openDirectory(subdirectory: String? = nil) throws -> Int32 {
        guard directory.isFileURL, directory.path.hasPrefix("/"), !directory.path.contains("\0") else {
            throw PrivateStorageError.unsafePath
        }
        if let subdirectory { try Self.validateName(subdirectory) }
        // The parent already exists (Application Support or an explicit test
        // fixture). Do not create/chmod arbitrary ancestor directories.
        let created = directory.path.withCString { mkdir($0, mode_t(0o700)) }
        if created != 0 && errno != EEXIST { throw Self.failure() }
        let rootFD = directory.path.withCString { open($0, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC) }
        guard rootFD >= 0 else { throw Self.failure() }
        do { try Self.protectDirectory(rootFD) }
        catch { close(rootFD); throw error }
        guard let subdirectory else { return rootFD }
        defer { close(rootFD) }
        let madeChild = subdirectory.withCString { mkdirat(rootFD, $0, mode_t(0o700)) }
        if madeChild != 0 && errno != EEXIST { throw Self.failure() }
        let childFD = subdirectory.withCString { openat(rootFD, $0, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC) }
        guard childFD >= 0 else { throw Self.failure() }
        do { try Self.protectDirectory(childFD) }
        catch { close(childFD); throw error }
        return childFD
    }

    private static func protectDirectory(_ descriptor: Int32) throws {
        var information = stat()
        guard fstat(descriptor, &information) == 0 else { throw PrivateStorageError.inaccessible }
        guard information.st_mode & S_IFMT == S_IFDIR, information.st_uid == getuid() else {
            throw PrivateStorageError.unsafePath
        }
        guard fchmod(descriptor, mode_t(0o700)) == 0 else { throw PrivateStorageError.inaccessible }
    }

    private static func validateName(_ name: String) throws {
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/"),
              !name.contains("\0"), name.utf8.count <= 255 else { throw PrivateStorageError.unsafePath }
    }

    private static func validateFile(_ information: stat) throws {
        guard information.st_mode & S_IFMT == S_IFREG, information.st_uid == getuid() else {
            throw PrivateStorageError.unsafePath
        }
    }

    private static func validateDestination(_ name: String, in directoryFD: Int32) throws {
        var information = stat()
        let status = name.withCString { fstatat(directoryFD, $0, &information, AT_SYMLINK_NOFOLLOW) }
        if status != 0 {
            if errno == ENOENT { return }
            throw failure()
        }
        try validateFile(information)
    }

    private static func failure() -> PrivateStorageError {
        [ELOOP, ENOTDIR].contains(errno) ? .unsafePath : .inaccessible
    }
}
