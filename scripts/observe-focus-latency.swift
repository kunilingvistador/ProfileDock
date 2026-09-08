// A passive Window Server observer. See observe-focus-latency.md.
// Never launches/activates an app, sends an Apple event or produces input.
import AppKit
import CoreGraphics
import Darwin
import Foundation

private let chromeBundleID = "com.google.Chrome"
private let pollIntervalSeconds = 0.005

private enum ObservationFailure: String, Error {
    case invalidArguments = "invalid_arguments"
    case outputExists = "output_already_exists"
    case outputUnavailable = "output_directory_unavailable"
    case windowMetadataUnavailable = "window_metadata_unavailable"
    case targetNotFound = "target_window_not_found"
    case targetNotChrome = "target_window_is_not_chrome"
    case outputWriteFailed = "output_write_failed"
}

private struct ObservationOptions {
    let window: CGWindowID
    let seconds: Double
    let output: URL

    static func parse(_ arguments: [String]) throws -> ObservationOptions {
        let accepted: Set<String> = ["--target-window", "--seconds", "--output"]
        var values: [String: String] = [:]
        var index = 0
        while index < arguments.count {
            guard index + 1 < arguments.count, accepted.contains(arguments[index]),
                  values[arguments[index]] == nil else { throw ObservationFailure.invalidArguments }
            values[arguments[index]] = arguments[index + 1]
            index += 2
        }
        guard let rawWindow = values["--target-window"], let window = UInt32(rawWindow), window > 0,
              let rawSeconds = values["--seconds"], let seconds = Double(rawSeconds),
              seconds.isFinite, seconds >= pollIntervalSeconds, seconds <= 60,
              let output = values["--output"], output.hasPrefix("/"), !output.contains("\0") else {
            throw ObservationFailure.invalidArguments
        }
        let outputURL = URL(fileURLWithPath: output).standardizedFileURL
        var information = stat()
        if lstat(outputURL.path, &information) == 0 { throw ObservationFailure.outputExists }
        let parent = outputURL.deletingLastPathComponent()
        guard (try? parent.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
              FileManager.default.isWritableFile(atPath: parent.path) else {
            throw ObservationFailure.outputUnavailable
        }
        return ObservationOptions(window: window, seconds: seconds, output: outputURL)
    }
}

private struct WindowIdentity {
    let id: CGWindowID
    let owner: pid_t
}

// Extract only numeric identity, layer/alpha and dimensions used to filter normal
// windows. Never extract a window title, URL, image or browser tab information.
private func normalWindows(onScreen: Bool) -> [WindowIdentity]? {
    let options: CGWindowListOption = onScreen
        ? [.optionOnScreenOnly, .excludeDesktopElements] : [.optionAll, .excludeDesktopElements]
    guard let entries = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return nil }
    return entries.compactMap { entry in
        guard let identifier = entry[kCGWindowNumber as String] as? NSNumber,
              let owner = entry[kCGWindowOwnerPID as String] as? NSNumber,
              let layer = entry[kCGWindowLayer as String] as? NSNumber, layer.intValue == 0 else { return nil }
        // A minimized/off-screen target may have zero alpha or unusual bounds.
        // Those visibility checks belong to observation, not target preflight.
        if onScreen {
            guard let bounds = entry[kCGWindowBounds as String] as? [String: Any],
                  let width = bounds["Width"] as? NSNumber, width.doubleValue > 1,
                  let height = bounds["Height"] as? NSNumber, height.doubleValue > 1,
                  ((entry[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1) > 0 else { return nil }
        }
        return WindowIdentity(id: identifier.uint32Value, owner: owner.int32Value)
    }
}

private struct InventoryEntry: Encodable {
    let cgWindowID: UInt32
    let ownerBundleID: String
}

private struct FrontObservation: Encodable {
    let uptimeNs: UInt64
    let targetIsFront: Bool
}

private struct ObservationReport: Encodable {
    let schemaVersion = 1
    let mode = "passive_window_order"
    let clock = "DispatchTime.uptimeNanoseconds"
    let condition = "chrome_frontmost_and_target_first_normal_onscreen"
    let status: String
    let requestedSeconds: Double
    let pollIntervalMs = pollIntervalSeconds * 1000
    let startedUptimeNs: UInt64
    let finishedUptimeNs: UInt64
    let initialObservation: FrontObservation?
    let transitions: [FrontObservation]
    let pollCount: Int
    let windowMetadataUnavailableCount: Int
    let maximumPollGapMs: Double
    let maximumSnapshotDurationMs: Double
}

@MainActor
private final class PassiveObserver {
    private let options: ObservationOptions
    private let targetOwner: NSRunningApplication
    private let targetPID: pid_t
    private var timer: Timer?
    private var started: UInt64 = 0
    private var finished: UInt64?
    private var previousPoll: UInt64?
    private var initialObservation: FrontObservation?
    private var transitions: [FrontObservation] = []
    private var previousState: Bool?
    private var pollCount = 0
    private var unavailableCount = 0
    private var maximumPollGapMs = 0.0
    private var maximumSnapshotDurationMs = 0.0
    private var status = "completed"

    init(options: ObservationOptions) throws {
        self.options = options
        guard let windows = normalWindows(onScreen: false) else { throw ObservationFailure.windowMetadataUnavailable }
        guard let target = windows.first(where: { $0.id == options.window }) else { throw ObservationFailure.targetNotFound }
        guard let application = NSRunningApplication(processIdentifier: target.owner),
              application.bundleIdentifier == chromeBundleID, !application.isTerminated else {
            throw ObservationFailure.targetNotChrome
        }
        targetOwner = application
        targetPID = target.owner
    }

    func observe(onStarted: () -> Void) -> ObservationReport {
        started = DispatchTime.now().uptimeNanoseconds
        sample()
        if finished == nil {
            // Announce readiness only after the initial state has been sampled;
            // the UI operator can then launch without racing that first read.
            onStarted()
            let timer = Timer(timeInterval: pollIntervalSeconds, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.sample() }
            }
            timer.tolerance = 0
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
            while finished == nil {
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
            }
            timer.invalidate()
        }
        return ObservationReport(status: status, requestedSeconds: options.seconds,
            startedUptimeNs: started, finishedUptimeNs: finished ?? DispatchTime.now().uptimeNanoseconds,
            initialObservation: initialObservation, transitions: transitions, pollCount: pollCount,
            windowMetadataUnavailableCount: unavailableCount, maximumPollGapMs: maximumPollGapMs,
            maximumSnapshotDurationMs: maximumSnapshotDurationMs)
    }

    private func sample() {
        guard finished == nil else { return }
        let before = DispatchTime.now().uptimeNanoseconds
        if Double(before - started) / 1_000_000_000 >= options.seconds {
            finished = before
            return
        }
        if let previousPoll { maximumPollGapMs = max(maximumPollGapMs, Double(before - previousPoll) / 1_000_000) }
        previousPoll = before
        let frontBefore = NSWorkspace.shared.frontmostApplication
        guard let windows = normalWindows(onScreen: true) else {
            unavailableCount += 1
            status = ObservationFailure.windowMetadataUnavailable.rawValue
            finished = DispatchTime.now().uptimeNanoseconds
            return
        }
        let frontAfter = NSWorkspace.shared.frontmostApplication
        let state = !targetOwner.isTerminated
            && frontBefore?.isEqual(targetOwner) == true && frontAfter?.isEqual(targetOwner) == true
            && windows.first?.id == options.window && windows.first?.owner == targetPID
        let after = DispatchTime.now().uptimeNanoseconds
        maximumSnapshotDurationMs = max(maximumSnapshotDurationMs, Double(after - before) / 1_000_000)
        pollCount += 1
        let observation = FrontObservation(uptimeNs: after, targetIsFront: state)
        if initialObservation == nil {
            initialObservation = observation
        } else if previousState != state {
            transitions.append(observation)
        }
        previousState = state
    }
}

private func encoded<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    var data = try encoder.encode(value)
    data.append(10)
    return data
}

// O_EXCL prevents overwriting a report (or following a symlink created during
// observation). Only the explicit output file is written, with owner-only mode.
private func writeReport(_ report: ObservationReport, to url: URL) throws {
    let data = try encoded(report)
    let descriptor = url.path.withCString { Darwin.open($0, O_WRONLY | O_CREAT | O_EXCL, 0o600) }
    guard descriptor >= 0 else { throw ObservationFailure.outputWriteFailed }
    let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
    do {
        try handle.write(contentsOf: data)
        try handle.close()
    } catch {
        try? handle.close()
        throw ObservationFailure.outputWriteFailed
    }
}

@main
private struct ObserveFocusLatency {
    @MainActor static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments == ["--help"] {
            print("""
            Passive observer (no app launches, activation, Apple events or input):
              observe-focus-latency --target-window CGID --seconds 15 --output /absolute/new-report.json
              observe-focus-latency --inventory
            Duration: 0.005–60 seconds. Polling: approximately 5 ms. Output is never overwritten.
            Inventory lists only on-screen normal window CGIDs and owner bundle IDs, front to back.
            Timing reports contain no window IDs, process IDs, titles, names, URLs or app paths.
            This observes window order, not physical clicks or painted pixels.
            """)
            return
        }
        do {
            if arguments == ["--inventory"] {
                guard let windows = normalWindows(onScreen: true) else { throw ObservationFailure.windowMetadataUnavailable }
                let inventory = windows.compactMap { window -> InventoryEntry? in
                    guard let bundle = NSRunningApplication(processIdentifier: window.owner)?.bundleIdentifier else { return nil }
                    return InventoryEntry(cgWindowID: window.id, ownerBundleID: bundle)
                }
                FileHandle.standardOutput.write(try encoded(inventory))
                return
            }
            let options = try ObservationOptions.parse(arguments)
            let observer = try PassiveObserver(options: options)
            let report = observer.observe {
                FileHandle.standardOutput.write(Data("{\"status\":\"observing\"}\n".utf8))
            }
            try writeReport(report, to: options.output)
            FileHandle.standardOutput.write(try encoded(["status": report.status]))
            if report.status != "completed" { exit(1) }
        } catch let failure as ObservationFailure {
            FileHandle.standardOutput.write((try? encoded(["status": failure.rawValue])) ?? Data())
            exit(2)
        } catch {
            // Localized errors can contain paths or other private data.
            FileHandle.standardOutput.write(Data("{\"status\":\"observation_failed\"}\n".utf8))
            exit(2)
        }
    }
}
