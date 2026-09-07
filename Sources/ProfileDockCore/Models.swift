import Foundation

public struct BrowserProfile: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let account: String?
    public let avatarPath: String?
    public init(id: String, name: String, account: String? = nil, avatarPath: String? = nil) {
        self.id = id; self.name = name; self.account = account; self.avatarPath = avatarPath
    }
}

public struct BrowserWindow: Identifiable, Hashable {
    public let id: String
    public let givenName: String
    public let title: String
    public let minimized: Bool
    public let incognito: Bool
    public var label: String { givenName.isEmpty ? title : givenName }
    public init(id: String, givenName: String, title: String, minimized: Bool, incognito: Bool = false) {
        self.id = id; self.givenName = givenName; self.title = title
        self.minimized = minimized; self.incognito = incognito
    }
}

public struct Shortcut: Identifiable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var windowName: String
    public var profileDirectory: String?
    public var iconFile: String?
    public var createdAt: Date
    public init(id: UUID = UUID(), name: String, windowName: String, profileDirectory: String? = nil, iconFile: String? = nil, createdAt: Date = Date()) {
        self.id = id; self.name = name; self.windowName = windowName
        self.profileDirectory = profileDirectory; self.iconFile = iconFile; self.createdAt = createdAt
    }
}

public enum ShortcutStatus: Equatable {
    case ready, missing, ambiguous, disconnected, checking
}

public enum WindowMatch: Equatable {
    case found(BrowserWindow), missing, ambiguous
}

public enum WindowMatcher {
    public static func match(name: String, in windows: [BrowserWindow]) -> WindowMatch {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .missing }
        let candidates = windows.filter { $0.givenName == name && !$0.incognito }
        if candidates.count == 1 { return .found(candidates[0]) }
        return candidates.isEmpty ? .missing : .ambiguous
    }

    public static func bindingName(displayName: String, id: UUID) -> String {
        let readable = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(readable.prefix(60)) · PD-\(id.uuidString)"
    }
}

public enum ShortcutRoute: Equatable {
    case focus(UUID), show
    public static func parse(_ url: URL) -> ShortcutRoute? {
        guard url.scheme?.lowercased() == "profiledock", url.user == nil, url.password == nil,
              url.port == nil, url.query == nil, url.fragment == nil else { return nil }
        guard let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath else { return nil }
        if url.host == "show", path.isEmpty || path == "/" { return .show }
        guard url.host == "focus" else { return nil }
        let pieces = path.split(separator: "/", omittingEmptySubsequences: false)
        guard pieces.count == 2, pieces[0].isEmpty, let id = UUID(uuidString: String(pieces[1])) else { return nil }
        return .focus(id)
    }
    public static func focusURL(_ id: UUID) -> URL {
        URL(string: "profiledock://focus/\(id.uuidString)")!
    }
}

public enum SafeFilename {
    public static func make(_ name: String, id: UUID) -> String {
        let forbidden = CharacterSet.controlCharacters.subtracting(CharacterSet(charactersIn: "\u{200c}\u{200d}"))
            .union(CharacterSet(charactersIn: "/:\\"))
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.map { forbidden.contains($0) ? "-" : String($0) }.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var stem = ""
        for character in cleaned {
            let candidate = stem + String(character)
            if candidate.utf8.count > 160 { break }
            stem = candidate
        }
        return "\(stem.isEmpty || stem == "." || stem == ".." ? "Profile" : stem)-\(id.uuidString).app"
    }
}
