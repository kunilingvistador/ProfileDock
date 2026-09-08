// Compile with the Command Line Tools; see measure-launcher-latency.md.
// This tool reads window metadata and opens ProfileDock/controller helpers only.
import AppKit
import CoreGraphics
import Darwin
import Foundation

private let controllerBundleID = "io.github.profiledock.app"
private let chromeBundleID = "com.google.Chrome"

private struct Options {
    let controller: URL
    let launcher: URL
    let targetWindow: CGWindowID
    let coldController: Bool
    let iterations: Int
    let pollMilliseconds: Double
    let timeoutMilliseconds: Double
    let readinessMilliseconds: Double

    static func parse(_ arguments: [String]) throws -> Options {
        let accepted: Set<String> = ["--controller", "--launcher", "--target-window", "--iterations", "--poll-ms", "--timeout-ms", "--ready-ms"]
        var values: [String: String] = [:]
        var coldController = false
        var index = 0
        while index < arguments.count {
            let key = arguments[index]
            if key == "--cold-controller" {
                guard !coldController else { throw Failure.invalidArguments }
                coldController = true
                index += 1
                continue
            }
            guard index + 1 < arguments.count else { throw Failure.invalidArguments }
            guard accepted.contains(key), values[key] == nil else { throw Failure.invalidArguments }
            values[key] = arguments[index + 1]
            index += 2
        }
        guard let controller = values["--controller"], controller.hasPrefix("/"),
              let launcher = values["--launcher"], launcher.hasPrefix("/"),
              let rawWindow = values["--target-window"], let window = UInt32(rawWindow), window > 0,
              let iterations = Int(values["--iterations"] ?? (coldController ? "1" : "10")), (1...200).contains(iterations),
              !coldController || iterations == 1,
              let poll = Double(values["--poll-ms"] ?? "10"), poll.isFinite, (1...100).contains(poll),
              let timeout = Double(values["--timeout-ms"] ?? "5000"), timeout.isFinite, (100...60000).contains(timeout),
              let ready = Double(values["--ready-ms"] ?? "150"), ready.isFinite, (20...5000).contains(ready),
              timeout > ready + poll else { throw Failure.invalidArguments }
        return Options(controller: URL(fileURLWithPath: controller).standardizedFileURL,
                       launcher: URL(fileURLWithPath: launcher).standardizedFileURL,
                       targetWindow: window, coldController: coldController, iterations: iterations,
                       pollMilliseconds: poll, timeoutMilliseconds: timeout,
                       readinessMilliseconds: ready)
    }
}

private enum Failure: String, Error {
    case invalidArguments = "invalid_arguments"
    case invalidController = "invalid_controller_bundle"
    case invalidLauncher = "invalid_launcher_bundle"
    case controllerPathConflict = "controller_path_conflict"
    case controllerRegistrationMismatch = "controller_registration_mismatch"
    case windowListUnavailable = "window_list_unavailable"
    case targetNotFound = "target_window_not_found"
    case targetNotChrome = "target_window_is_not_chrome"
    case coldControllerRunning = "cold_controller_already_running"
    case coldChromeFrontmost = "cold_chrome_already_frontmost"
    case coldHelperRunning = "cold_helper_already_running"
}

private struct WindowMetadata {
    let id: CGWindowID
    let owner: pid_t
    let layer: Int
    let alpha: Double
    let width: Double
    let height: Double
}

// CGWindowListCopyWindowInfo is documented to return front-to-back ordering.
// Do not read kCGWindowName, URLs, or serialize the returned dictionaries.
private func windowMetadata(onScreen: Bool) -> [WindowMetadata]? {
    let options: CGWindowListOption = onScreen
        ? [.optionOnScreenOnly, .excludeDesktopElements] : [.optionAll, .excludeDesktopElements]
    guard let entries = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return nil }
    return entries.compactMap { entry in
        guard let id = entry[kCGWindowNumber as String] as? NSNumber,
              let owner = entry[kCGWindowOwnerPID as String] as? NSNumber,
              let layer = entry[kCGWindowLayer as String] as? NSNumber,
              let bounds = entry[kCGWindowBounds as String] as? [String: Any],
              let width = bounds["Width"] as? NSNumber,
              let height = bounds["Height"] as? NSNumber else { return nil }
        return WindowMetadata(id: id.uint32Value, owner: owner.int32Value, layer: layer.intValue,
                              alpha: (entry[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1,
                              width: width.doubleValue, height: height.doubleValue)
    }
}

private func firstNormalWindow() -> WindowMetadata? {
    windowMetadata(onScreen: true)?.first { $0.layer == 0 && $0.alpha > 0 && $0.width > 1 && $0.height > 1 }
}

private func now() -> UInt64 { DispatchTime.now().uptimeNanoseconds }
private func milliseconds(_ end: UInt64, since start: UInt64) -> Double {
    Double(end - start) / 1_000_000
}
private func sameFile(_ a: URL?, _ b: URL) -> Bool {
    a?.resolvingSymlinksInPath().standardizedFileURL == b.resolvingSymlinksInPath().standardizedFileURL
}

private struct Sample: Encodable {
    let iteration: Int
    let status: String
    let baselineReadyMs: Double?
    let elapsedMs: Double
    let latencyMs: Double?
    let launchCallbackMs: Double?
    let maximumPollGapMs: Double

    private enum CodingKeys: String, CodingKey {
        case iteration, status, baselineReadyMs, elapsedMs, latencyMs, launchCallbackMs, maximumPollGapMs
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(iteration, forKey: .iteration)
        try container.encode(status, forKey: .status)
        // Keep a missing baseline distinguishable from a zero-duration baseline.
        try container.encode(baselineReadyMs, forKey: .baselineReadyMs)
        try container.encode(elapsedMs, forKey: .elapsedMs)
        try container.encodeIfPresent(latencyMs, forKey: .latencyMs)
        try container.encodeIfPresent(launchCallbackMs, forKey: .launchCallbackMs)
        try container.encode(maximumPollGapMs, forKey: .maximumPollGapMs)
    }
}

private struct Statistics: Encodable {
    let successfulCount: Int
    let failedCount: Int
    let minimumMs: Double?
    let medianMs: Double?
    let p95Ms: Double?
    let maximumMs: Double?

    init(samples: [Sample]) {
        let values = samples.compactMap { $0.status == "success" ? $0.latencyMs : nil }.sorted()
        successfulCount = values.count
        failedCount = samples.count - values.count
        minimumMs = values.first
        maximumMs = values.last
        if values.isEmpty {
            medianMs = nil
            p95Ms = nil
        } else {
            let middle = values.count / 2
            medianMs = values.count.isMultiple(of: 2) ? (values[middle - 1] + values[middle]) / 2 : values[middle]
            p95Ms = values[Int(ceil(Double(values.count) * 0.95)) - 1]
        }
    }
}

private struct Report: Encodable {
    let schemaVersion = 1
    let status: String
    let mode: String
    let requestedIterations: Int
    let pollIntervalMs: Double
    let readinessStabilityMs: Double
    let timeoutMs: Double
    let samples: [Sample]
    let summary: Statistics
}

private func emit<T: Encodable>(_ value: T, exitCode: Int32) -> Never {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    if let data = try? encoder.encode(value) {
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data([10]))
    } else {
        FileHandle.standardOutput.write(Data("{\"status\":\"json_encoding_failed\"}\n".utf8))
    }
    exit(exitCode)
}

@MainActor
private final class Benchmark: NSObject, NSApplicationDelegate {
    private enum Phase { case preparing, preparingCold, measuring }
    private let options: Options
    private let launcherBundleID: String
    private let targetOwner: pid_t
    private var timer: Timer?
    private var phase = Phase.preparing
    private var iteration = 0
    private var baselineStarted: UInt64 = 0
    private var baselineStableSince: UInt64?
    private var baselineReadyMs: Double?
    private var coldBaselinePID: pid_t?
    private var finderActivationAttempted = false
    private var controllerPID: pid_t?
    private var controllerOpened = false
    private var sampleStarted: UInt64 = 0
    private var firstTargetObserved: UInt64?
    private var launchCallbackMs: Double?
    private var launchCallbackReceived = false
    private var launchFailed = false
    private var previousPoll: UInt64?
    private var maximumPollGapMs: Double = 0
    private var samples: [Sample] = []

    init(options: Options) throws {
        self.options = options
        guard options.controller.pathExtension == "app",
              let controllerBundle = Bundle(url: options.controller),
              controllerBundle.bundleIdentifier == controllerBundleID,
              let controllerExecutable = controllerBundle.executableURL,
              FileManager.default.isExecutableFile(atPath: controllerExecutable.path) else { throw Failure.invalidController }
        guard options.launcher.pathExtension == "app",
              let launcher = Bundle(url: options.launcher),
              let identifier = launcher.bundleIdentifier,
              let shortcut = launcher.object(forInfoDictionaryKey: "ProfileDockShortcutID") as? String,
              let shortcutID = UUID(uuidString: shortcut),
              identifier == "io.github.profiledock.launcher.\(shortcutID.uuidString.lowercased())",
              let launcherExecutable = launcher.executableURL,
              FileManager.default.isExecutableFile(atPath: launcherExecutable.path) else { throw Failure.invalidLauncher }
        launcherBundleID = identifier
        // A helper selects Launch Services' registered controller before its fallback path.
        // Refuse ambiguous installs rather than measuring the wrong build.
        if let registered = NSWorkspace.shared.urlForApplication(withBundleIdentifier: controllerBundleID),
           !sameFile(registered, options.controller) { throw Failure.controllerRegistrationMismatch }
        if NSRunningApplication.runningApplications(withBundleIdentifier: controllerBundleID)
            .contains(where: { !sameFile($0.bundleURL, options.controller) }) { throw Failure.controllerPathConflict }
        if options.coldController {
            guard NSRunningApplication.runningApplications(withBundleIdentifier: controllerBundleID).isEmpty else { throw Failure.coldControllerRunning }
            guard NSRunningApplication.runningApplications(withBundleIdentifier: identifier).isEmpty else { throw Failure.coldHelperRunning }
        }
        guard let windows = windowMetadata(onScreen: false) else { throw Failure.windowListUnavailable }
        guard let target = windows.first(where: { $0.id == options.targetWindow && $0.layer == 0 }) else { throw Failure.targetNotFound }
        guard NSRunningApplication(processIdentifier: target.owner)?.bundleIdentifier == chromeBundleID else { throw Failure.targetNotChrome }
        targetOwner = target.owner
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let pollingTimer = Timer(timeInterval: options.pollMilliseconds / 1000, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        pollingTimer.tolerance = 0
        timer = pollingTimer
        RunLoop.main.add(pollingTimer, forMode: .common)
        if options.coldController {
            // The caller quits only the controller manually. If necessary, activate
            // an already-running Finder without opening it or touching Chrome.
            guard NSRunningApplication.runningApplications(withBundleIdentifier: controllerBundleID).isEmpty else { finish(status: Failure.coldControllerRunning.rawValue) }
            guard NSRunningApplication.runningApplications(withBundleIdentifier: launcherBundleID).isEmpty else { finish(status: Failure.coldHelperRunning.rawValue) }
            iteration = 1
            baselineReadyMs = nil
            baselineStarted = now()
            baselineStableSince = nil
            phase = .preparingCold
            poll()
        } else {
            prepareNextSample()
        }
    }

    private func prepareNextSample() {
        guard iteration < options.iterations else { finish(status: samples.allSatisfy { $0.status == "success" } ? "success" : "failed") }
        iteration += 1
        phase = .preparing
        baselineStarted = now()
        baselineStableSince = nil
        controllerOpened = false
        controllerPID = nil
        let currentIteration = iteration
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.addsToRecentItems = false
        configuration.createsNewApplicationInstance = false
        // A normal open/reopen displays ProfileDock's own manager window.
        // Never activate Chrome while preparing a sample.
        NSWorkspace.shared.openApplication(at: options.controller, configuration: configuration) { [weak self] application, error in
            DispatchQueue.main.async {
                guard let self, self.iteration == currentIteration, self.phase == .preparing else { return }
                guard error == nil, let application,
                      sameFile(application.bundleURL, self.options.controller) else {
                    self.finish(status: "baseline_controller_open_failed")
                }
                self.controllerPID = application.processIdentifier
                self.controllerOpened = true
            }
        }
    }

    private func poll() {
        let timestamp = now()
        switch phase {
        case .preparingCold:
            guard NSRunningApplication.runningApplications(withBundleIdentifier: controllerBundleID).isEmpty else { finish(status: Failure.coldControllerRunning.rawValue) }
            guard NSRunningApplication.runningApplications(withBundleIdentifier: launcherBundleID).isEmpty else { finish(status: Failure.coldHelperRunning.rawValue) }
            guard milliseconds(timestamp, since: baselineStarted) < options.timeoutMilliseconds else {
                finish(status: "cold_baseline_not_ready_timeout")
            }
            let frontmost = NSWorkspace.shared.frontmostApplication
            if let frontmost, frontmost.bundleIdentifier != chromeBundleID {
                if coldBaselinePID != frontmost.processIdentifier || baselineStableSince == nil {
                    coldBaselinePID = frontmost.processIdentifier
                    baselineStableSince = timestamp
                }
                if milliseconds(timestamp, since: baselineStableSince!) >= options.readinessMilliseconds {
                    baselineReadyMs = milliseconds(timestamp, since: baselineStarted)
                    requestLauncher()
                }
            } else {
                coldBaselinePID = nil
                baselineStableSince = nil
                if frontmost?.bundleIdentifier == chromeBundleID, !finderActivationAttempted {
                    finderActivationAttempted = true
                    guard let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first(where: { !$0.isTerminated }) else {
                        finish(status: "cold_finder_not_running")
                    }
                    guard finder.activate(options: []) else { finish(status: "cold_finder_activation_failed") }
                }
            }
        case .preparing:
            guard milliseconds(timestamp, since: baselineStarted) < options.timeoutMilliseconds else {
                finish(status: "baseline_not_ready_timeout")
            }
            let frontmost = NSWorkspace.shared.frontmostApplication
            let controllerFinished = controllerPID.flatMap { NSRunningApplication(processIdentifier: $0) }?.isFinishedLaunching == true
            let helperIdle = NSRunningApplication.runningApplications(withBundleIdentifier: launcherBundleID).isEmpty
            let firstWindow = firstNormalWindow()
            let ready = controllerOpened && controllerFinished && helperIdle
                && frontmost?.processIdentifier == controllerPID
                && firstWindow?.owner == controllerPID
            if ready {
                if baselineStableSince == nil { baselineStableSince = timestamp }
                if milliseconds(timestamp, since: baselineStableSince!) >= options.readinessMilliseconds {
                    baselineReadyMs = milliseconds(timestamp, since: baselineStarted)
                    requestLauncher()
                }
            } else {
                baselineStableSince = nil
            }
        case .measuring:
            if let previousPoll { maximumPollGapMs = max(maximumPollGapMs, milliseconds(timestamp, since: previousPoll)) }
            previousPoll = timestamp
            let frontmost = NSWorkspace.shared.frontmostApplication
            let firstWindow = firstNormalWindow()
            if firstTargetObserved == nil,
               frontmost?.processIdentifier == targetOwner,
               frontmost?.bundleIdentifier == chromeBundleID,
               firstWindow?.id == options.targetWindow,
               firstWindow?.owner == targetOwner {
                firstTargetObserved = now()
            }
            if launchFailed {
                finishSample(status: "launcher_open_failed")
            } else if launchCallbackReceived, firstTargetObserved != nil {
                finishSample(status: "success")
            } else if milliseconds(now(), since: sampleStarted) >= options.timeoutMilliseconds {
                finishSample(status: launchCallbackReceived ? "target_focus_timeout" : "launcher_callback_timeout")
            }
        }
    }

    private func requestLauncher() {
        if options.coldController {
            // Recheck immediately at the measurement boundary; abort rather than
            // silently turning a requested cold measurement into a warm one.
            guard NSRunningApplication.runningApplications(withBundleIdentifier: controllerBundleID).isEmpty else { finish(status: Failure.coldControllerRunning.rawValue) }
            guard NSRunningApplication.runningApplications(withBundleIdentifier: launcherBundleID).isEmpty else { finish(status: Failure.coldHelperRunning.rawValue) }
            guard let frontmost = NSWorkspace.shared.frontmostApplication,
                  frontmost.bundleIdentifier != chromeBundleID else { finish(status: Failure.coldChromeFrontmost.rawValue) }
        }
        phase = .measuring
        firstTargetObserved = nil
        launchCallbackMs = nil
        launchCallbackReceived = false
        launchFailed = false
        maximumPollGapMs = 0
        let currentIteration = iteration
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.addsToRecentItems = false
        configuration.createsNewApplicationInstance = false
        sampleStarted = now()
        previousPoll = sampleStarted
        // This is the actual exported .app, not a shortcut URL or AppleScript bypass.
        NSWorkspace.shared.openApplication(at: options.launcher, configuration: configuration) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self, self.iteration == currentIteration, self.phase == .measuring else { return }
                self.launchCallbackMs = milliseconds(now(), since: self.sampleStarted)
                self.launchCallbackReceived = true
                self.launchFailed = error != nil
            }
        }
    }

    private func finishSample(status: String) {
        samples.append(Sample(iteration: iteration, status: status,
                              baselineReadyMs: baselineReadyMs,
                              elapsedMs: milliseconds(now(), since: sampleStarted),
                              latencyMs: status == "success" ? firstTargetObserved.map { milliseconds($0, since: sampleStarted) } : nil,
                              launchCallbackMs: launchCallbackMs,
                              maximumPollGapMs: maximumPollGapMs))
        // Fail fast: a timeout could be a permission dialog, missing binding or user activity.
        // Do not repeatedly launch helpers into an uncertain UI state.
        guard status == "success" else { finish(status: status) }
        prepareNextSample()
    }

    private func finish(status: String) -> Never {
        timer?.invalidate()
        emit(Report(status: status, mode: options.coldController ? "cold_controller" : "warm_controller", requestedIterations: options.iterations,
                    pollIntervalMs: options.pollMilliseconds,
                    readinessStabilityMs: options.readinessMilliseconds,
                    timeoutMs: options.timeoutMilliseconds,
                    samples: samples, summary: Statistics(samples: samples)),
             exitCode: status == "success" ? 0 : 1)
    }
}

MainActor.assumeIsolated {
    do {
        let options = try Options.parse(Array(CommandLine.arguments.dropFirst()))
        let benchmark = try Benchmark(options: options)
        let application = NSApplication.shared
        application.setActivationPolicy(.prohibited)
        application.delegate = benchmark
        withExtendedLifetime(benchmark) { application.run() }
    } catch let failure as Failure {
        emit(["status": failure.rawValue], exitCode: 2)
    } catch {
        // Never print localized error descriptions: they may contain personal paths.
        emit(["status": "preflight_failed"], exitCode: 2)
    }
}
