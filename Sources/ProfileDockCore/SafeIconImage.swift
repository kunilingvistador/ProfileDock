import Foundation
import ImageIO

public enum SafeIconImageError: Error, Equatable {
    case invalidImage, inputTooLarge, dimensionsTooLarge
}

/// Decodes a bounded raster representation and writes a fresh PNG without
/// copying source metadata. Callers must pass these bytes, not the original,
/// to NSImage so it cannot choose a different, unchecked representation.
public enum SafeIconImage {
    public static func png(from data: Data, inputByteLimit: Int = 16_000_000) throws -> Data {
        guard inputByteLimit > 0, data.count <= inputByteLimit else { throw SafeIconImageError.inputTooLarge }
        guard !data.isEmpty,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            throw SafeIconImageError.invalidImage
        }
        let count = CGImageSourceGetCount(source)
        guard (1...64).contains(count) else { throw SafeIconImageError.invalidImage }
        var selectedIndex = 0, selectedPixels = 0
        for index in 0..<count {
            guard let info = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
                  let width = info[kCGImagePropertyPixelWidth] as? Int,
                  let height = info[kCGImagePropertyPixelHeight] as? Int,
                  width > 0, height > 0 else { throw SafeIconImageError.invalidImage }
            guard width <= 8192, height <= 8192, width * height <= 16_777_216 else {
                throw SafeIconImageError.dimensionsTooLarge
            }
            if width * height > selectedPixels { selectedIndex = index; selectedPixels = width * height }
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 512,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, selectedIndex, options as CFDictionary),
              image.width > 0, image.height > 0, image.width <= 512, image.height <= 512 else {
            throw SafeIconImageError.invalidImage
        }
        let result = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(result as CFMutableData, "public.png" as CFString, 1, nil) else {
            throw SafeIconImageError.invalidImage
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw SafeIconImageError.invalidImage }
        return result as Data
    }
}
