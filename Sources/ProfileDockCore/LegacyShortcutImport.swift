import Foundation

public enum LegacyShortcutImport {
    /// Only reads a literal assignment from our earlier local applets. Never
    /// executes imported code, and never evaluates arbitrary AppleScript.
    public static func targetName(in source: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"(?m)^\s*set targetName to "((?:[^"\\]|\\.)*)"\s*$"#),
              let result = regex.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)),
              let range = Range(result.range(at: 1), in: source) else { return nil }
        let quoted = "\"" + source[range] + "\""
        guard let data = quoted.data(using: .utf8), let value = try? JSONDecoder().decode(String.self, from: data),
              !value.isEmpty, value.count <= 500 else { return nil }
        return value
    }
}
