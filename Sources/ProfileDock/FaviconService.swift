import Foundation
import ImageIO
import ProfileDockCore

struct FaviconService {
    func fetch(website: String) async throws -> Data {
        guard let url = FaviconDiscovery.websiteURL(website) else { throw IconError.invalidURL }
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil; config.httpShouldSetCookies = false
        config.timeoutIntervalForRequest = 12; config.timeoutIntervalForResource = 25
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        var candidates: [URL] = []
        if let (data, finalURL) = try? await download(url, session: session, limit: 2_000_000) {
            if validImage(data) { return data }
            if let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) {
                candidates = FaviconDiscovery.candidates(html: html, baseURL: finalURL)
            }
        }
        if let fallback = URL(string: "/favicon.ico", relativeTo: url)?.absoluteURL { candidates.append(fallback) }
        for candidate in candidates.prefix(6) {
            try Task.checkCancellation()
            if let (data, _) = try? await download(candidate, session: session, limit: 8_000_000), validImage(data) { return data }
        }
        throw IconError.downloadFailed
    }

    private func download(_ url: URL, session: URLSession, limit: Int) async throws -> (Data, URL) {
        var request = URLRequest(url: url); request.setValue("ProfileDock/0.1 (site icon request)", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let finalURL = response.url, FaviconDiscovery.websiteURL(finalURL.absoluteString) != nil else { throw IconError.downloadFailed }
        guard response.expectedContentLength <= limit else { throw IconError.tooLarge }
        var data = Data()
        for try await byte in bytes {
            guard data.count < limit else { throw IconError.tooLarge }
            data.append(byte)
        }
        return (data, finalURL)
    }

    private func validImage(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0,
              let info = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = info[kCGImagePropertyPixelWidth] as? Int, let height = info[kCGImagePropertyPixelHeight] as? Int else { return false }
        return width > 0 && height > 0 && width <= 8192 && height <= 8192 && width * height <= 16_777_216
    }
}
