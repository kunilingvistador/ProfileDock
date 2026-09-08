import Darwin
import Foundation

/// Explicit local diagnostics for development measurements. Disabled by default.
/// Records numeric timings and fixed operation labels, never shortcut/window data.
public enum PerformanceTrace {
    private static let lock = NSLock()
    private static let file: URL? = {
        let directory = URL(fileURLWithPath: "/private/tmp/ProfileDock-Performance-\(getuid())", isDirectory: true)
        let files = FileManager.default
        guard let attributes = try? files.attributesOfItem(atPath: directory.path),
              attributes[.type] as? FileAttributeType == .typeDirectory,
              (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == getuid(),
              (attributes[.posixPermissions] as? NSNumber)?.intValue == 0o700,
              files.fileExists(atPath: directory.appendingPathComponent("enabled").path) else { return nil }
        let url = directory.appendingPathComponent("events-\(ProcessInfo.processInfo.processIdentifier).jsonl")
        // Refuse existing paths, including symlinks. Each process gets a new file.
        let descriptor = open(url.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else { return nil }
        close(descriptor)
        return url
    }()

    public static func record(_ phase: String, at timestamp: UInt64 = DispatchTime.now().uptimeNanoseconds,
                              values: [String: Double] = [:]) {
        guard let file else { return }
        let row: [String: Any] = ["phase": phase, "uptimeNs": timestamp,
                                  "process": ProcessInfo.processInfo.processIdentifier, "values": values]
        guard var data = try? JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]) else { return }
        data.append(10)
        lock.lock(); defer { lock.unlock() }
        guard let handle = try? FileHandle(forWritingTo: file) else { return }
        defer { try? handle.close() }
        do { try handle.seekToEnd(); try handle.write(contentsOf: data) } catch { /* Diagnostics cannot fail focus. */ }
    }
}
