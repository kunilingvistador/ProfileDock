import Foundation

/// The last controller explicitly opened by the user, independent of stale Launch Services entries.
/// This is a disposable location hint, not shortcut configuration or an updater.
public struct ControllerLocationRegistry {
    public static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ProfileDock", isDirectory: true)
    }

    public let directory: URL
    public var file: URL { directory.appendingPathComponent("controller-location.json") }
    public init(directory: URL = Self.defaultDirectory) { self.directory = directory }

    public func record(controllerURL: URL) throws {
        guard ControllerResolver.isCompatibleController(controllerURL) else {
            throw ControllerLocationError.invalidController
        }
        let record = Record(version: 1, appPath: controllerURL.standardizedFileURL.path)
        try PrivateStorage(directory: directory).write(JSONEncoder().encode(record), to: "controller-location.json")
    }

    public func controllerURL() -> URL? {
        guard let data = try? PrivateStorage(directory: directory).readFile("controller-location.json", maximumBytes: 16_384),
              let record = try? JSONDecoder().decode(Record.self, from: data),
              record.version == 1, record.appPath.hasPrefix("/"), !record.appPath.contains("\0") else { return nil }
        let url = URL(fileURLWithPath: record.appPath, isDirectory: true)
        return ControllerResolver.isCompatibleController(url) ? url.standardizedFileURL : nil
    }

    private struct Record: Codable {
        let version: Int
        let appPath: String
    }
}

public enum ControllerLocationError: Error {
    case invalidController, symbolicLink
}

/// Only considers known locations; it never scans for app copies or guesses from version numbers.
public enum ControllerResolver {
    public static let bundleID = "io.github.profiledock.app"

    public static var standardLocations: [URL] {
        [URL(fileURLWithPath: "/Applications/ProfileDock.app", isDirectory: true),
         FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/ProfileDock.app", isDirectory: true)]
    }

    public static func resolve(preferred: URL?, running: [URL], registered: URL?, fallback: URL?,
                               standardLocations: [URL] = Self.standardLocations) -> URL? {
        if let preferred, isCompatibleController(preferred) { return preferred.standardizedFileURL }

        // Several running copies do not establish which one the user wants.
        // Deduplicate alternate spellings of the same real location before deciding.
        let runningControllers = Set(running.filter(isCompatibleController)
            .map { $0.standardizedFileURL.resolvingSymlinksInPath() })
        if runningControllers.count == 1 { return runningControllers.first }

        let remaining = [registered].compactMap { $0 } + standardLocations + [fallback].compactMap { $0 }
        return remaining.first(where: isCompatibleController)?.standardizedFileURL
    }

    /// Structural compatibility check. macOS remains responsible for code-signing and launch policy.
    public static func isCompatibleController(_ url: URL) -> Bool {
        guard url.isFileURL, url.pathExtension.lowercased() == "app", isDirectory(url) else { return false }
        let contents = url.appendingPathComponent("Contents", isDirectory: true)
        let executables = contents.appendingPathComponent("MacOS", isDirectory: true)
        let info = contents.appendingPathComponent("Info.plist")
        let executable = executables.appendingPathComponent("ProfileDock")
        guard isDirectory(contents), isDirectory(executables), isRegularFile(info), isRegularFile(executable),
              FileManager.default.isExecutableFile(atPath: executable.path),
              let data = try? Data(contentsOf: info),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              plist["CFBundleIdentifier"] as? String == bundleID,
              plist["CFBundlePackageType"] as? String == "APPL",
              plist["CFBundleExecutable"] as? String == "ProfileDock",
              let types = plist["CFBundleURLTypes"] as? [[String: Any]],
              types.contains(where: { ($0["CFBundleURLSchemes"] as? [String])?.contains("profiledock") == true }) else { return false }
        return true
    }

    private static func isDirectory(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { return false }
        return values.isDirectory == true && values.isSymbolicLink != true
    }

    private static func isRegularFile(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]) else { return false }
        return values.isRegularFile == true && values.isSymbolicLink != true
    }
}
