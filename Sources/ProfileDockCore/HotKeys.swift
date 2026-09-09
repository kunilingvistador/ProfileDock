import Foundation

/// Physical keys and our own stable modifier bits, independent of AppKit/Carbon.
public struct HotKey: Codable, Hashable {
    public var keyCode: UInt32
    public var modifiers: UInt32
    public static let control: UInt32 = 1, option: UInt32 = 2, shift: UInt32 = 4, command: UInt32 = 8
    public init(keyCode: UInt32, modifiers: UInt32) { self.keyCode = keyCode; self.modifiers = modifiers }
    public static let keyLabels: [UInt32: String] = [
        0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",8:"C",9:"V",11:"B",
        12:"Q",13:"W",14:"E",15:"R",16:"Y",17:"T",18:"1",19:"2",20:"3",21:"4",22:"6",23:"5",
        24:"=",25:"9",26:"7",27:"−",28:"8",29:"0",30:"]",31:"O",32:"U",33:"[",34:"I",35:"P",
        37:"L",38:"J",39:"'",40:"K",41:";",42:"\\",43:",",44:"/",45:"N",46:"M",47:".",49:"Space",50:"`",
        123:"←",124:"→",125:"↓",126:"↑"
    ]
    public var isValid: Bool {
        Self.keyLabels[keyCode] != nil && modifiers & ~UInt32(15) == 0 &&
        modifiers & (Self.command | Self.control) != 0 && modifiers.nonzeroBitCount >= 2
    }
    public var symbols: String {
        [(Self.control,"⌃"),(Self.option,"⌥"),(Self.shift,"⇧"),(Self.command,"⌘")]
            .filter { modifiers & $0.0 != 0 }.map(\.1).joined()
    }
}

public struct HotKeyAssignment: Codable, Equatable {
    public var shortcutID: UUID
    public var hotKey: HotKey
    public init(shortcutID: UUID, hotKey: HotKey) { self.shortcutID = shortcutID; self.hotKey = hotKey }
}

public struct HotKeyDocument: Codable, Equatable {
    public var version: Int = 1
    public var enabled: Bool = true
    public var assignments: [HotKeyAssignment] = []
    public init() {}
    public func validate() throws {
        guard version == 1 else { throw HotKeyError.unsupportedVersion }
        guard assignments.count <= 500,
              Set(assignments.map(\.shortcutID)).count == assignments.count,
              Set(assignments.map(\.hotKey)).count == assignments.count,
              assignments.allSatisfy({ $0.hotKey.isValid }) else { throw HotKeyError.invalidData }
    }
    public func hotKey(for id: UUID) -> HotKey? { assignments.first { $0.shortcutID == id }?.hotKey }
    public func assigning(_ key: HotKey?, to id: UUID) -> Self {
        var next = self
        next.assignments.removeAll { $0.shortcutID == id }
        if let key { next.assignments.append(.init(shortcutID: id, hotKey: key)) }
        return next
    }
}

public enum HotKeyError: Error, Equatable {
    case invalidData, unsupportedVersion, registrationFailed(Int32), reserved, tokenLimit
}

public struct HotKeyStore {
    public let storage: PrivateStorage
    public init(directory: URL) { storage = PrivateStorage(directory: directory) }
    public func load() throws -> HotKeyDocument {
        guard let bytes = try storage.readFile("hotkeys.json", maximumBytes: 128_000) else { return HotKeyDocument() }
        let document = try JSONDecoder().decode(HotKeyDocument.self, from: bytes)
        try document.validate()
        return document
    }
    public func save(_ document: HotKeyDocument) throws {
        try document.validate()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try storage.write(encoder.encode(document), to: "hotkeys.json")
    }
}

@MainActor public protocol HotKeyRegistering: AnyObject {
    func register(_ key: HotKey, token: UInt32) throws
    func unregister(token: UInt32)
}

/// Coordinates registration and disk commits; Chrome and UI are outside this type.
@MainActor public final class HotKeyCoordinator {
    public private(set) var document: HotKeyDocument
    public private(set) var failures: [UUID: Error] = [:]
    private struct Registration { var key: HotKey; var token: UInt32 }
    private var registrations: [UUID: Registration] = [:]
    private var pressed: Set<UInt32> = []
    private var nextToken: UInt32 = 0
    private var suspended = false
    private let backend: HotKeyRegistering
    private let persist: (HotKeyDocument) throws -> Void
    public var knownIDs: Set<UUID>
    public var onInvoke: ((UUID) -> Void)?

    public init(document: HotKeyDocument, knownIDs: Set<UUID>, backend: HotKeyRegistering,
                persist: @escaping (HotKeyDocument) throws -> Void) throws {
        try document.validate()
        self.document = document; self.knownIDs = knownIDs; self.backend = backend; self.persist = persist
    }
    private func allocate(_ key: HotKey) throws -> Registration {
        guard nextToken < UInt32.max else { throw HotKeyError.tokenLimit }
        nextToken += 1
        try backend.register(key, token: nextToken)
        return Registration(key: key, token: nextToken)
    }
    private func release(_ registration: Registration) {
        backend.unregister(token: registration.token); pressed.remove(registration.token)
    }
    public func stop() {
        registrations.values.forEach(release); registrations.removeAll(); pressed.removeAll()
    }
    public func suspend() { suspended = true; stop() }
    public func resume() { suspended = false; reconcile() }
    public func reconcile() {
        failures.removeAll()
        let desired = document.enabled && !suspended
            ? Dictionary(uniqueKeysWithValues: document.assignments.filter { knownIDs.contains($0.shortcutID) }.map { ($0.shortcutID, $0.hotKey) }) : [:]
        for (id, registration) in registrations where desired[id] != registration.key {
            release(registration); registrations.removeValue(forKey: id)
        }
        for (id, key) in desired where registrations[id] == nil {
            do { registrations[id] = try allocate(key) } catch { failures[id] = error }
        }
    }
    /// Keep the old working registrations and document if registration or writing fails.
    public func apply(_ next: HotKeyDocument) throws {
        try next.validate()
        var prepared: [UUID: Registration] = [:]
        do {
            if next.enabled {
                for item in next.assignments where knownIDs.contains(item.shortcutID) {
                    if registrations[item.shortcutID]?.key == item.hotKey { continue }
                    prepared[item.shortcutID] = try allocate(item.hotKey)
                }
            }
            try persist(next)
        } catch {
            prepared.values.forEach(release)
            throw error
        }
        for (id, registration) in registrations where !next.enabled || next.hotKey(for: id) != registration.key || !knownIDs.contains(id) {
            release(registration); registrations.removeValue(forKey: id)
        }
        document = next; failures.removeAll()
        if suspended { prepared.values.forEach(release) }
        else { registrations.merge(prepared) { _, new in new } }
    }
    public func receive(token: UInt32, isDown: Bool) {
        if !isDown { pressed.remove(token); return }
        guard !suspended, document.enabled, !pressed.contains(token),
              let id = registrations.first(where: { $0.value.token == token })?.key,
              knownIDs.contains(id) else { return }
        pressed.insert(token)
        onInvoke?(id)
    }
    public func isActive(_ id: UUID) -> Bool { registrations[id] != nil && !suspended }
}
