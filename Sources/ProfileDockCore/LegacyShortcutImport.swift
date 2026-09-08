import Foundation

public enum LegacyShortcutImport {
    /// Conversion is deliberately narrower than read-only import. Reject unusual
    /// scripts instead of inferring permission to replace them from a bundle name.
    public static func supportedTarget(in source: String) -> String? {
        guard !source.contains("(*"), !source.contains("*)"),
              let regex = try? NSRegularExpression(pattern: #"(?m)^\s*set targetName to "((?:[^"\\]|\\.)*)"\s*$"#),
              regex.numberOfMatches(in: source, range: NSRange(source.startIndex..., in: source)) == 1,
              let target = targetName(in: source) else { return nil }
        let code = source.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("--") }
            .joined(separator: "\n").lowercased()
        let compact = code.filter { !$0.isWhitespace }
        guard compact.contains("useframework\"appkit\""),
              compact.contains("onrunmyfocusexistingwindow()endrun"),
              compact.contains("onreopenmyfocusexistingwindow()endreopen"),
              compact.contains("onfocusexistingwindow()settargetnameto"),
              compact.contains("setindexofwindowidtargetidto1"),
              compact.contains("runningapplicationswithbundleidentifier:\"com.google.chrome\""),
              compact.contains("activatewithoptions:0"),
              !compact.contains("doshellscript"), !compact.contains("runscript"),
              !compact.contains("openlocation"), !compact.contains("makenew") else { return nil }
        return target
    }

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
