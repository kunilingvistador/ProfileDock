import AppKit
import Darwin
import ProfileDockCore

enum IconService {
    /// Decode one bounded frame and drop source metadata before AppKit sees it.
    static func loadImage(from url: URL) throws -> NSImage {
        guard url.isFileURL else { throw IconError.invalidImage }
        // User-selected links to ordinary photos are allowed, but a named pipe
        // or device must never block the main actor during an image import.
        let descriptor = Darwin.open(url.path, O_RDONLY | O_NONBLOCK | O_CLOEXEC)
        guard descriptor >= 0 else { throw IconError.invalidImage }
        var info = stat()
        guard fstat(descriptor, &info) == 0, info.st_mode & S_IFMT == S_IFREG,
              info.st_size >= 0, info.st_size <= 16_000_000 else {
            Darwin.close(descriptor)
            throw IconError.invalidImage
        }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: 16_000_001) ?? Data()
        return try image(from: data)
    }

    static func image(from data: Data) throws -> NSImage {
        do {
            let png = try SafeIconImage.png(from: data)
            guard let image = NSImage(data: png) else { throw IconError.invalidImage }
            return image
        } catch {
            throw IconError.invalidImage
        }
    }

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
        case .invalidURL: return L("Use an HTTPS website name such as example.com, without a login, IP address or custom port.", "Введите HTTPS-адрес сайта, например example.com, без логина, IP-адреса или нестандартного порта.")
        case .downloadFailed: return L("No downloadable site icon was found. You can choose an image from a file instead.", "Не удалось скачать значок сайта. Можно выбрать изображение из файла.")
        case .tooLarge: return L("The image is too large (maximum 8 MB).", "Изображение слишком большое (максимум 8 МБ).")
        }
    }
}
