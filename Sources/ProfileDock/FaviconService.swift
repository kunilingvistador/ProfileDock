import Foundation
import ProfileDockCore

struct FaviconService {
    func fetch(website: String) async throws -> Data {
        try Task.checkCancellation()
        guard let url = FaviconDiscovery.websiteURL(website) else { throw IconError.invalidURL }
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil; config.httpShouldSetCookies = false
        config.urlCredentialStorage = nil; config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 12; config.timeoutIntervalForResource = 25
        let session = URLSession(configuration: config, delegate: FaviconSessionDelegate(origin: url), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        // Bounds retained response bytes across the page and every candidate.
        // Transport headers, redirects, and URLSession's buffers are additional.
        var remainingBytes = 10_000_000
        var candidates: [URL] = []
        do {
            let (data, finalURL) = try await download(url, origin: url, session: session, limit: 2_000_000, remainingBytes: &remainingBytes)
            try Task.checkCancellation()
            if let png = try? SafeIconImage.png(from: data, inputByteLimit: 2_000_000) {
                try Task.checkCancellation(); return png
            }
            if let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) {
                candidates = FaviconDiscovery.candidates(html: html, baseURL: finalURL)
            }
        } catch {
            try Task.checkCancellation()
            // A page failure can still have a usable same-origin /favicon.ico.
        }
        candidates = Array(candidates.prefix(6))
        if let fallback = URL(string: "/favicon.ico", relativeTo: url)?.absoluteURL,
           !candidates.contains(fallback) {
            // Reserve one of the six attempts for the conventional fallback.
            candidates = Array(candidates.prefix(5)); candidates.append(fallback)
        }
        for candidate in candidates {
            try Task.checkCancellation()
            guard remainingBytes > 0 else { throw IconError.tooLarge }
            do {
                let (data, _) = try await download(candidate, origin: url, session: session, limit: 8_000_000, remainingBytes: &remainingBytes)
                try Task.checkCancellation()
                let png = try SafeIconImage.png(from: data, inputByteLimit: 8_000_000)
                try Task.checkCancellation(); return png
            } catch {
                try Task.checkCancellation()
            }
        }
        throw IconError.downloadFailed
    }

    private func download(_ url: URL, origin: URL, session: URLSession, limit: Int, remainingBytes: inout Int) async throws -> (Data, URL) {
        try Task.checkCancellation()
        guard let url = FaviconURLPolicy.requestURL(url), FaviconURLPolicy.sameOrigin(url, as: origin) else { throw IconError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue(FaviconSessionDelegate.userAgent, forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await session.bytes(for: request)
        // Stop the transfer on early body/size/error exits, before trying another
        // candidate. Invalidating the session only at the end would be too late.
        defer { bytes.task.cancel() }
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let responseURL = response.url, let finalURL = FaviconURLPolicy.requestURL(responseURL),
              FaviconURLPolicy.sameOrigin(finalURL, as: origin) else { throw IconError.downloadFailed }
        guard response.expectedContentLength <= min(limit, remainingBytes) else { throw IconError.tooLarge }
        var data = Data()
        for try await byte in bytes {
            guard data.count < limit, remainingBytes > 0 else { throw IconError.tooLarge }
            if data.count % 4096 == 0 { try Task.checkCancellation() }
            data.append(byte); remainingBytes -= 1
        }
        try Task.checkCancellation()
        return (data, finalURL)
    }
}

/// Redirect destinations are approved before URLSession sends the next GET.
private final class FaviconSessionDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    static let userAgent = "ProfileDock/0.1 (site icon request)"
    private let origin: URL
    private let lock = NSLock()
    private var followed: [Int: Int] = [:]

    init(origin: URL) { self.origin = origin }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        answer(challenge, completionHandler: completionHandler)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        answer(challenge, completionHandler: completionHandler)
    }

    private func answer(_ challenge: URLAuthenticationChallenge,
                        completionHandler: (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Keep normal server certificate/hostname validation. Never manufacture
        // a trust credential or ask the system to supply HTTP/SSO/client auth.
        let useDefault = FaviconURLPolicy.usesDefaultAuthenticationHandling(for: challenge.protectionSpace.authenticationMethod)
        completionHandler(useDefault ? .performDefaultHandling : .cancelAuthenticationChallenge, nil)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        lock.lock()
        let count = followed[task.taskIdentifier, default: 0]
        guard let destination = request.url, let normalized = FaviconURLPolicy.requestURL(destination),
              FaviconURLPolicy.allowsRedirect(to: normalized, from: origin, redirectsAlreadyFollowed: count) else {
            lock.unlock(); completionHandler(nil); return
        }
        followed[task.taskIdentifier] = count + 1
        lock.unlock()
        // The downloader only sends GETs. No credentials, Cookie, or Referer
        // need to be carried into a redirect request.
        var approved = URLRequest(url: normalized)
        approved.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        completionHandler(approved)
    }
}
