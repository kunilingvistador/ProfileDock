import Foundation
import XCTest
@testable import ProfileDockCore

final class FocusRequestGateTests: XCTestCase {
    func testOnlyTheLatestRequestRemainsCurrent() {
        let gate = FocusRequestGate()
        let first = gate.request()
        XCTAssertTrue(gate.isCurrent(first))
        let second = gate.request()
        XCTAssertFalse(gate.isCurrent(first))
        XCTAssertTrue(gate.isCurrent(second))
        XCTAssertFalse(gate.isCurrent(UUID()))
    }

    func testInFlightAFinishesQueuedBIsSkippedAndCActivates() {
        let gate = FocusRequestGate()
        let queue = DispatchQueue(label: "ProfileDock.FocusGateTest")
        let log = EventLog()
        let aStarted = DispatchSemaphore(value: 0)
        let releaseA = DispatchSemaphore(value: 0)

        func submit(_ label: String, token: UUID, work: @escaping @Sendable () -> Void = {}) {
            queue.async {
                guard gate.isCurrent(token) else { log.append("skip " + label); return }
                log.append("send " + label)
                work()
                log.append("finish " + label)
                if gate.isCurrent(token) { log.append("activate " + label) }
            }
        }

        submit("A", token: gate.request()) {
            aStarted.signal()
            _ = releaseA.wait(timeout: .now() + 2)
        }
        XCTAssertEqual(aStarted.wait(timeout: .now() + 2), .success)
        submit("B", token: gate.request())
        submit("C", token: gate.request())
        releaseA.signal()
        queue.sync {}

        XCTAssertEqual(log.values, ["send A", "finish A", "skip B", "send C", "finish C", "activate C"])
    }

    func testRequestSupersededDuringPreparationDoesNotSend() {
        let gate = FocusRequestGate()
        let queue = DispatchQueue(label: "ProfileDock.FocusPreparationTest")
        let log = EventLog()
        let preparing = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let first = gate.request()
        queue.async {
            guard gate.isCurrent(first) else { return }
            preparing.signal()
            _ = release.wait(timeout: .now() + 2)
            // Mirrors the worker's second check after script compilation.
            guard gate.isCurrent(first) else { log.append("skip prepared A"); return }
            log.append("send A")
        }
        XCTAssertEqual(preparing.wait(timeout: .now() + 2), .success)
        let latest = gate.request()
        release.signal()
        queue.sync {}
        XCTAssertEqual(log.values, ["skip prepared A"])
        XCTAssertTrue(gate.isCurrent(latest))
    }
}

private final class EventLog: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [String] = []

    func append(_ entry: String) {
        lock.lock()
        defer { lock.unlock() }
        entries.append(entry)
    }

    var values: [String] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }
}
