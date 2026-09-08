import Foundation

/// Coalesces requests that have not started without interrupting work in flight.
/// Request publication and activation checks run on the caller's main actor;
/// the serial worker also checks immediately before sending a browser command.
public final class FocusRequestGate: @unchecked Sendable {
    private let lock = NSLock()
    private var latest: UUID?

    public init() {}

    public func request() -> UUID {
        lock.lock()
        defer { lock.unlock() }
        let token = UUID()
        latest = token
        return token
    }

    public func isCurrent(_ token: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return latest == token
    }
}
