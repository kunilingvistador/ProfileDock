#!/usr/bin/env swift
// Original ProfileDock icon, drawn entirely with AppKit. No external assets.
import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: make-app-icon.swift OUTPUT.iconset\n", stderr)
    exit(2)
}

let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
}

func rounded(_ rect: NSRect, radius: CGFloat, fill: NSColor) {
    fill.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func drawIcon() {
    let backdrop = NSBezierPath(roundedRect: NSRect(x: 56, y: 56, width: 912, height: 912),
                               xRadius: 210, yRadius: 210)
    NSGradient(starting: color(0.30, 0.30, 0.84), ending: color(0.12, 0.14, 0.40))!
        .draw(in: backdrop, angle: -70)

    // Three independent windows, with one deliberately brought to the front.
    rounded(NSRect(x: 329, y: 374, width: 486, height: 386), radius: 66,
            fill: color(0.69, 0.65, 1.0))
    rounded(NSRect(x: 276, y: 323, width: 486, height: 386), radius: 66,
            fill: color(0.42, 0.65, 1.0))

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0.025, 0.045, 0.15, 0.32)
    shadow.shadowOffset = NSSize(width: 0, height: -18)
    shadow.shadowBlurRadius = 27
    shadow.set()
    rounded(NSRect(x: 208, y: 250, width: 496, height: 395), radius: 69,
            fill: color(0.975, 0.98, 1.0))
    NSGraphicsContext.restoreGraphicsState()

    let divider = NSBezierPath()
    divider.move(to: NSPoint(x: 234, y: 551))
    divider.line(to: NSPoint(x: 678, y: 551))
    divider.lineWidth = 5
    color(0.87, 0.89, 0.96).setStroke()
    divider.stroke()

    for index in 0..<3 {
        let tone = index == 0 ? color(0.42, 0.39, 0.88) : color(0.76, 0.77, 0.88)
        tone.setFill()
        NSBezierPath(ovalIn: NSRect(x: 252 + index * 41, y: 584, width: 22, height: 22)).fill()
    }
    rounded(NSRect(x: 253, y: 303, width: 108, height: 199), radius: 26,
            fill: color(0.87, 0.88, 0.98))
    rounded(NSRect(x: 387, y: 411, width: 269, height: 91), radius: 24,
            fill: color(0.40, 0.38, 0.84))
    rounded(NSRect(x: 387, y: 303, width: 121, height: 83), radius: 23,
            fill: color(0.75, 0.79, 0.98))
    rounded(NSRect(x: 532, y: 303, width: 124, height: 83), radius: 23,
            fill: color(0.82, 0.84, 0.98))
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels,
            pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
            let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            fatalError("Could not allocate icon canvas")
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        context.cgContext.clear(CGRect(x: 0, y: 0, width: pixels, height: pixels))
        context.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        drawIcon()
        NSGraphicsContext.restoreGraphicsState()
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            fatalError("Could not encode icon PNG")
        }
        let suffix = scale == 2 ? "@2x" : ""
        try png.write(to: destination.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
    }
}
