import Foundation

/// A conservative website-icon policy, not a network sandbox. A syntactically
/// public DNS name can still resolve to a private address, including after DNS
/// rebinding. This policy does not resolve or pin addresses.
public enum FaviconURLPolicy {
    public static let maximumRedirects = 3

    public static func websiteURL(_ input: String) -> URL? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.utf8.count <= 8192 else { return nil }
        let candidate = text.contains("://") ? text : "https://" + text
        guard let url = URL(string: candidate) else { return nil }
        return requestURL(url)
    }

    /// Keeps the requested path and query. Fragments are never sent in HTTP.
    public static func requestURL(_ url: URL) -> URL? {
        guard url.absoluteString.utf8.count <= 8192,
              url.scheme?.lowercased() == "https", url.user == nil, url.password == nil,
              url.port == nil || url.port == 443,
              var host = url.host?.lowercased(), !host.isEmpty,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        // A single final dot is the DNS absolute-name spelling of the same host.
        if host.hasSuffix(".") { host.removeLast() }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard host.utf8.count <= 253, labels.count >= 2,
              labels.allSatisfy(validDNSLabel),
              labels.last?.contains(where: { $0.isASCII && $0.isLetter }) == true,
              !labels.allSatisfy(numericAddressComponent) else { return nil }
        let localSuffixes = ["localhost", "local", "internal", "lan", "home", "home.arpa", "test", "invalid", "example", "onion"]
        guard !localSuffixes.contains(where: { host == $0 || host.hasSuffix("." + $0) }) else { return nil }
        components.scheme = "https"
        components.host = host
        components.port = nil
        components.fragment = nil
        return components.url
    }

    public static func sameOrigin(_ candidate: URL, as original: URL) -> Bool {
        guard let candidate = requestURL(candidate), let original = requestURL(original) else { return false }
        return candidate.host == original.host // Both are HTTPS on effective port 443.
    }

    /// `redirectsAlreadyFollowed` is counted separately for each download task.
    public static func allowsRedirect(to candidate: URL, from original: URL, redirectsAlreadyFollowed: Int) -> Bool {
        redirectsAlreadyFollowed >= 0 && redirectsAlreadyFollowed < maximumRedirects && sameOrigin(candidate, as: original)
    }

    /// Delegate default handling is reserved for the platform's normal TLS
    /// certificate verification. HTTP auth, SSO, and client certificates fail.
    public static func usesDefaultAuthenticationHandling(for method: String) -> Bool {
        method == NSURLAuthenticationMethodServerTrust
    }

    private static func validDNSLabel(_ label: Substring) -> Bool {
        guard (1...63).contains(label.utf8.count),
              label.first?.isASCII == true, label.last?.isASCII == true,
              label.first?.isLetter == true || label.first?.isNumber == true,
              label.last?.isLetter == true || label.last?.isNumber == true else { return false }
        return label.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
    }

    private static func numericAddressComponent(_ label: Substring) -> Bool {
        if label.allSatisfy({ $0 >= "0" && $0 <= "9" }) { return true }
        return label.hasPrefix("0x") && label.count > 2 && label.dropFirst(2).allSatisfy(\.isHexDigit)
    }
}
