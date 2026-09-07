import AppKit
import ProfileDockCore

enum IconService {
    static func png(_ image: NSImage, size: Int) throws -> Data {
        guard image.size.width > 0, image.size.height > 0,
              let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { throw IconError.invalidImage }
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
        context.imageInterpolation = .high
        NSColor.clear.setFill(); NSRect(x: 0, y: 0, width: size, height: size).fill(using: .copy)
        let factor = min(CGFloat(size) / image.size.width, CGFloat(size) / image.size.height)
        let width = image.size.width * factor, height = image.size.height * factor
        image.draw(in: NSRect(x: (CGFloat(size) - width) / 2, y: (CGFloat(size) - height) / 2, width: width, height: height),
                   from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw IconError.invalidImage }
        return data
    }

    static func defaultIcon(name: String, id: UUID) -> NSImage {
        let image = NSImage(size: NSSize(width: 512, height: 512))
        image.lockFocus()
        let colors: [NSColor] = [.systemIndigo, .systemTeal, .systemOrange, .systemPink, .systemBlue, .systemPurple]
        let color = colors[Int(id.uuid.0) % colors.count]
        color.setFill()
        NSBezierPath(roundedRect: NSRect(x: 32, y: 32, width: 448, height: 448), xRadius: 106, yRadius: 106).fill()
        let letter = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased() as NSString
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 260, weight: .semibold), .foregroundColor: NSColor.white]
        let size = letter.size(withAttributes: attributes)
        letter.draw(at: NSPoint(x: (512-size.width)/2, y: (512-size.height)/2 + 5), withAttributes: attributes)
        image.unlockFocus(); return image
    }

    /// Native ICNS with PNG representations. No runtime developer tools needed.
    static func icns(_ image: NSImage) throws -> Data {
        var chunks = Data()
        for (type, size) in [("icp4",16),("icp5",32),("icp6",64),("ic07",128),("ic08",256),("ic09",512)] {
            let body = try png(image, size: size)
            chunks.append(contentsOf: type.utf8)
            var length = UInt32(body.count + 8).bigEndian
            withUnsafeBytes(of: &length) { chunks.append(contentsOf: $0) }
            chunks.append(body)
        }
        var result = Data("icns".utf8); var length = UInt32(chunks.count + 8).bigEndian
        withUnsafeBytes(of: &length) { result.append(contentsOf: $0) }
        result.append(chunks); return result
    }
}

enum IconError: LocalizedError {
    case invalidImage, invalidURL, downloadFailed, tooLarge
    var errorDescription: String? {
        switch self {
        case .invalidImage: return L("Choose a supported image such as PNG, JPEG or ICO.", "Выберите изображение PNG, JPEG или ICO.")
        case .invalidURL: return L("Enter a website address, for example example.com.", "Введите адрес сайта, например example.com.")
        case .downloadFailed: return L("No downloadable site icon was found. You can choose an image from a file instead.", "Не удалось скачать значок сайта. Можно выбрать изображение из файла.")
        case .tooLarge: return L("The image is too large (maximum 8 MB).", "Изображение слишком большое (максимум 8 МБ).")
        }
    }
}
