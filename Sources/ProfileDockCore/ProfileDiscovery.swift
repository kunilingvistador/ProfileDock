import Foundation

public enum ChromeProfileDiscovery {
    /// Only Chrome's profile metadata is read. No history, cookies or sessions.
    public static func decode(localState: Data, root: URL) throws -> [BrowserProfile] {
        guard let document = try JSONSerialization.jsonObject(with: localState) as? [String: Any],
              let profile = document["profile"] as? [String: Any],
              let cache = profile["info_cache"] as? [String: [String: Any]] else { return [] }
        return cache.compactMap { directory, fields in
            guard directory == "Default" || directory.range(of: #"^Profile [0-9]+$"#, options: .regularExpression) != nil else { return nil }
            let rawName = fields["name"] as? String ?? directory
            let name = rawName.isEmpty ? directory : rawName
            let account = (fields["user_name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            let candidate = root.appendingPathComponent(directory).appendingPathComponent("Google Profile Picture.png")
            let avatar = FileManager.default.fileExists(atPath: candidate.path) ? candidate.path : nil
            return BrowserProfile(id: directory, name: name, account: account, avatarPath: avatar)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
