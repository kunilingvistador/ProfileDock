import Foundation

public enum FaviconDiscovery {
    public static func websiteURL(_ input: String) -> URL? {
        FaviconURLPolicy.websiteURL(input)
    }

    public static func candidates(html: String, baseURL: URL) -> [URL] {
        guard let baseURL = FaviconURLPolicy.requestURL(baseURL),
              let tags = try? NSRegularExpression(pattern: #"<link\b[^>]*>"#, options: [.caseInsensitive]),
              let attrs = try? NSRegularExpression(pattern: #"([\w-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))"#, options: [.caseInsensitive]) else { return [] }
        let ns = html as NSString
        var choices: [(URL, Int)] = []
        for tag in tags.matches(in: html, range: NSRange(location: 0, length: ns.length)).prefix(256) {
            let text = ns.substring(with: tag.range); let source = text as NSString
            var properties: [String: String] = [:]
            for a in attrs.matches(in: text, range: NSRange(location: 0, length: source.length)) {
                let valueRange = (2...4).map { a.range(at: $0) }.first { $0.location != NSNotFound }!
                properties[source.substring(with: a.range(at: 1)).lowercased()] = source.substring(with: valueRange)
            }
            let rels = (properties["rel"] ?? "").lowercased().split(whereSeparator: { $0.isWhitespace })
            guard rels.contains("icon") || rels.contains("apple-touch-icon"), let href = properties["href"],
                  let rawURL = URL(string: href.replacingOccurrences(of: "&amp;", with: "&"), relativeTo: baseURL)?.absoluteURL,
                  let url = FaviconURLPolicy.requestURL(rawURL),
                  FaviconURLPolicy.sameOrigin(url, as: baseURL) else { continue }
            let size = Int((properties["sizes"] ?? "").split(separator: "x").first ?? "") ?? 0
            // Prefer a high-resolution site icon; ICO remains a valid fallback.
            choices.append((url, min(size, 1024) + (rels.contains("apple-touch-icon") ? 1 : 0)))
        }
        choices.sort { $0.1 > $1.1 }
        var seen = Set<URL>()
        return choices.map(\.0).filter { seen.insert($0).inserted }
    }
}
