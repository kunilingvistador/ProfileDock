import XCTest
import Foundation
import CoreGraphics
import ImageIO
@testable import ProfileDockCore

final class FaviconURLPolicyTests: XCTestCase {
    func testNormalizationPreservesRequestedQueryAndDropsFragment() throws {
        let url = try XCTUnwrap(FaviconDiscovery.websiteURL(" HTTPS://Example.COM.:443/a%2Fb?q=a%2Bb&q=2#private-fragment "))
        XCTAssertEqual(url.absoluteString, "https://example.com/a%2Fb?q=a%2Bb&q=2")
        XCTAssertEqual(FaviconDiscovery.websiteURL("example.com/path")?.absoluteString, "https://example.com/path")
    }

    func testRejectsNonHTTPSCredentialsAndUnexpectedPorts() {
        for value in ["http://example.com", "https://example.com:8443", "https://example.com:80", "https://user@example.com", "https://user:secret@example.com", "file:///tmp/icon.png", "ftp://example.com/icon.png", "data:image/png;base64,a"] {
            XCTAssertNil(FaviconDiscovery.websiteURL(value), value)
        }
    }

    func testRejectsIPLiteralAlternateIPSpellingsAndLocalNames() {
        for host in ["localhost", "localhost.", "a.localhost", "printer.local", "router.internal", "a.home.arpa", "a.lan", "intranet", "127.0.0.1", "127.1", "2130706433", "0177.0.0.1", "0x7f000001", "0x7f.0x0.0x0.0x1", "10.0.0.1", "169.254.169.254", "8.8.8.8", "[::1]", "[::ffff:127.0.0.1]", "[2001:4860:4860::8888]", "a..com", "-a.example.com", "a-.example.com", "a.invalid", "a.test"] {
            XCTAssertNil(FaviconDiscovery.websiteURL("https://" + host + "/icon.png"), host)
        }
    }

    func testOriginPolicyBlocksSubdomainsDowngradeAndLocalRedirects() throws {
        let origin = try XCTUnwrap(URL(string: "https://example.com/start"))
        for allowed in ["https://example.com/icon.png", "https://EXAMPLE.COM:443/new?x=1#ignored"] {
            let url = try XCTUnwrap(URL(string: allowed))
            XCTAssertTrue(FaviconURLPolicy.allowsRedirect(to: url, from: origin, redirectsAlreadyFollowed: 0))
        }
        for blocked in ["https://www.example.com/icon", "https://cdn.example.com/icon", "https://elsewhere.com/icon", "http://example.com/icon", "https://example.com:8443/icon", "https://127.0.0.1/icon", "https://user@example.com/icon"] {
            let url = try XCTUnwrap(URL(string: blocked))
            XCTAssertFalse(FaviconURLPolicy.allowsRedirect(to: url, from: origin, redirectsAlreadyFollowed: 0), blocked)
        }
    }

    func testOnlyServerTrustUsesDefaultAuthenticationHandling() {
        XCTAssertTrue(FaviconURLPolicy.usesDefaultAuthenticationHandling(for: NSURLAuthenticationMethodServerTrust))
        for method in [NSURLAuthenticationMethodDefault, NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodHTTPDigest,
                       NSURLAuthenticationMethodNTLM, NSURLAuthenticationMethodNegotiate, NSURLAuthenticationMethodClientCertificate, "unknown"] {
            XCTAssertFalse(FaviconURLPolicy.usesDefaultAuthenticationHandling(for: method), method)
        }
    }

    func testFourthRedirectIsRejectedEvenWithinOrigin() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/next"))
        for count in 0..<3 { XCTAssertTrue(FaviconURLPolicy.allowsRedirect(to: url, from: url, redirectsAlreadyFollowed: count)) }
        for count in [-1, 3, 4, Int.max] { XCTAssertFalse(FaviconURLPolicy.allowsRedirect(to: url, from: url, redirectsAlreadyFollowed: count)) }
    }

    func testUntrustedHTMLCannotChooseAnotherOriginOrLocalEndpoint() throws {
        let base = try XCTUnwrap(URL(string: "https://example.com/page"))
        let html = """
        <link rel="icon" sizes="1024x1024" href="https://127.0.0.1/private">
        <link rel="icon" sizes="1024x1024" href="https://cdn.example.com/tracker">
        <link rel="icon" sizes="1024x1024" href="http://example.com/insecure">
        <link rel="icon" href="//example.com/icon.png?a=1&amp;b=2#fragment">
        """
        XCTAssertEqual(FaviconDiscovery.candidates(html: html, baseURL: base).map(\.absoluteString), ["https://example.com/icon.png?a=1&b=2"])
    }
}

final class SafeIconImageTests: XCTestCase {
    private func raster(width: Int, height: Int) throws -> CGImage {
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                              bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.3, green: 0.4, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try XCTUnwrap(context.makeImage())
    }

    private func encoded(_ images: [CGImage], type: String = "public.tiff", properties: [CFString: Any]? = nil) throws -> Data {
        let output = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(output as CFMutableData, type as CFString, images.count, nil))
        for image in images { CGImageDestinationAddImage(destination, image, properties as CFDictionary?) }
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return output as Data
    }

    func testThumbnailIsFreshSingleFramePNGWithoutSourceEXIFOrGPS() throws {
        let metadata: [CFString: Any] = [
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2026:09:08 12:00:00"],
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 37.0, kCGImagePropertyGPSLatitudeRef: "N",
                                          kCGImagePropertyGPSLongitude: 122.0, kCGImagePropertyGPSLongitudeRef: "W"],
        ]
        let input = try encoded([raster(width: 1024, height: 768)], type: "public.jpeg", properties: metadata)
        let original = try XCTUnwrap(CGImageSourceCreateWithData(input as CFData, nil))
        let originalInfo = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(original, 0, nil) as? [CFString: Any])
        XCTAssertNotNil(originalInfo[kCGImagePropertyGPSDictionary])
        let originalEXIF = originalInfo[kCGImagePropertyExifDictionary] as? [CFString: Any]
        XCTAssertNotNil(originalEXIF?[kCGImagePropertyExifDateTimeOriginal])
        let output = try SafeIconImage.png(from: input)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(output as CFData, nil))
        XCTAssertEqual(CGImageSourceGetType(source) as String?, "public.png")
        XCTAssertEqual(CGImageSourceGetCount(source), 1)
        let info = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        XCTAssertEqual(info[kCGImagePropertyPixelWidth] as? Int, 512)
        XCTAssertEqual(info[kCGImagePropertyPixelHeight] as? Int, 384)
        // ImageIO can synthesize technical EXIF properties such as pixel size
        // and color space for the new PNG. Original photo metadata is absent.
        let exif = info[kCGImagePropertyExifDictionary] as? [CFString: Any]
        XCTAssertNil(exif?[kCGImagePropertyExifDateTimeOriginal])
        XCTAssertNil(info[kCGImagePropertyGPSDictionary])
    }

    func testAllRepresentationsAreCheckedBeforeDecoding() throws {
        let input = try encoded([raster(width: 16, height: 16), raster(width: 9000, height: 1)])
        let original = try XCTUnwrap(CGImageSourceCreateWithData(input as CFData, nil))
        XCTAssertEqual(CGImageSourceGetCount(original), 2)
        XCTAssertThrowsError(try SafeIconImage.png(from: input)) { XCTAssertEqual($0 as? SafeIconImageError, .dimensionsTooLarge) }
    }

    func testBestBoundedRepresentationBecomesOnlyOutputFrame() throws {
        let input = try encoded([raster(width: 16, height: 16), raster(width: 1024, height: 768)])
        let output = try SafeIconImage.png(from: input)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(output as CFData, nil))
        XCTAssertEqual(CGImageSourceGetCount(source), 1)
        let info = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        XCTAssertEqual(info[kCGImagePropertyPixelWidth] as? Int, 512)
    }

    func testRejectsInputSizeInvalidDataAndExcessiveFrameCount() throws {
        XCTAssertThrowsError(try SafeIconImage.png(from: Data(repeating: 0, count: 5), inputByteLimit: 4)) { XCTAssertEqual($0 as? SafeIconImageError, .inputTooLarge) }
        XCTAssertThrowsError(try SafeIconImage.png(from: Data("not an image".utf8)))
        let input = try encoded(Array(repeating: raster(width: 1, height: 1), count: 65))
        XCTAssertThrowsError(try SafeIconImage.png(from: input)) { XCTAssertEqual($0 as? SafeIconImageError, .invalidImage) }
    }
}
