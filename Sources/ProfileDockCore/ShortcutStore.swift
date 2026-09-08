import Foundation

public struct StateDocument: Codable {
    public var version: Int
    public var shortcuts: [Shortcut]
    public init(shortcuts: [Shortcut]) { version = 1; self.shortcuts = shortcuts }
}

public enum StoreError: LocalizedError {
    case unsupportedVersion, invalidData
    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion: return "This configuration was created by a newer version of ProfileDock."
        case .invalidData: return "The saved configuration is invalid. Its original file has been preserved."
        }
    }
}

public struct ShortcutStore {
    public let directory: URL
    public var file: URL { directory.appendingPathComponent("shortcuts.json") }
    public var iconsDirectory: URL { directory.appendingPathComponent("Icons", isDirectory: true) }
    public var launchersDirectory: URL { directory.appendingPathComponent("Launchers", isDirectory: true) }
    public var privateStorage: PrivateStorage { PrivateStorage(directory: directory) }
    public init(directory: URL) { self.directory = directory }

    public func load() throws -> [Shortcut] {
        guard let data = try privateStorage.readFile("shortcuts.json") else { return [] }
        let doc = try JSONDecoder().decode(StateDocument.self, from: data)
        guard doc.version == 1 else { throw StoreError.unsupportedVersion }
        try validate(doc.shortcuts)
        return doc.shortcuts
    }

    public func save(_ shortcuts: [Shortcut]) throws {
        try validate(shortcuts)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try privateStorage.write(encoder.encode(StateDocument(shortcuts: shortcuts)), to: "shortcuts.json")
    }

    private func validate(_ shortcuts: [Shortcut]) throws {
        guard Set(shortcuts.map(\.id)).count == shortcuts.count,
              shortcuts.allSatisfy({ s in
                  !s.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && s.name.count <= 100 &&
                  !s.windowName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && s.windowName.count <= 500 &&
                  (s.iconFile == nil || s.iconFile == s.id.uuidString + ".png")
              }) else { throw StoreError.invalidData }
    }
}
