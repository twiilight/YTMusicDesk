#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation

/// Generates a bespoke macOS squircle `AppIcon.iconset` using CoreGraphics
/// so the compiled `.app` ships with a crisp, Retina-ready Dock icon.
guard CommandLine.arguments.count == 2 else {
    fputs("Usage: generate-icon.swift <output-iconset-dir>\n", stderr)
    exit(1)
}

let outputDir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

func renderIcon(pixelSize: Int) -> Data {
    let size = CGFloat(pixelSize)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

    guard let ctx = CGContext(
        data: nil,
        width: pixelSize,
        height: pixelSize,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else {
        fatalError("Failed to create CGContext")
    }

    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)

    // macOS icon safe inset (~10% padding for standard Dock visual sizing)
    let inset = size * 0.095
    let cardRect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let cornerRadius = cardRect.width * 0.225
    let squirclePath = CGPath(roundedRect: cardRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    // Soft outer drop shadow
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -size * 0.018),
        blur: size * 0.036,
        color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.45)
    )
    ctx.addPath(squirclePath)
    ctx.setFillColor(CGColor(red: 0.06, green: 0.06, blue: 0.075, alpha: 1.0))
    ctx.fillPath()
    ctx.restoreGState()

    // Clip to squircle for obsidian surface and glow
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()

    // Deep obsidian-charcoal vertical surface gradient
    let bgColors = [
        CGColor(red: 0.125, green: 0.125, blue: 0.15, alpha: 1.0),
        CGColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 1.0)
    ] as CFArray
    if let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(
            bgGradient,
            start: CGPoint(x: size * 0.5, y: cardRect.maxY),
            end: CGPoint(x: size * 0.5, y: cardRect.minY),
            options: []
        )
    }

    let center = CGPoint(x: size * 0.5, y: size * 0.5)

    // Subtle crimson ambient underglow
    let glowColors = [
        CGColor(red: 1.0, green: 0.12, blue: 0.24, alpha: 0.34),
        CGColor(red: 1.0, green: 0.12, blue: 0.24, alpha: 0.0)
    ] as CFArray
    if let glowGradient = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(
            glowGradient,
            startCenter: center,
            startRadius: size * 0.05,
            endCenter: center,
            endRadius: size * 0.42,
            options: []
        )
    }

    // Crisp crimson vinyl disc
    let discRadius = cardRect.width * 0.335
    let discRect = CGRect(
        x: center.x - discRadius,
        y: center.y - discRadius,
        width: discRadius * 2,
        height: discRadius * 2
    )
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -size * 0.012),
        blur: size * 0.04,
        color: CGColor(red: 0.85, green: 0.02, blue: 0.15, alpha: 0.45)
    )
    ctx.addEllipse(in: discRect)
    ctx.clip()

    let discColors = [
        CGColor(red: 1.0, green: 0.19, blue: 0.28, alpha: 1.0),
        CGColor(red: 0.82, green: 0.02, blue: 0.16, alpha: 1.0)
    ] as CFArray
    if let discGradient = CGGradient(colorsSpace: colorSpace, colors: discColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(
            discGradient,
            start: CGPoint(x: discRect.minX, y: discRect.maxY),
            end: CGPoint(x: discRect.maxX, y: discRect.minY),
            options: []
        )
    }
    ctx.restoreGState()

    // Outer delicate vinyl groove
    let grooveRadius = discRadius * 0.77
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.22))
    ctx.setLineWidth(max(1.0, size * 0.008))
    ctx.strokeEllipse(in: CGRect(
        x: center.x - grooveRadius,
        y: center.y - grooveRadius,
        width: grooveRadius * 2,
        height: grooveRadius * 2
    ))

    // Iconic white inner ring
    let innerRingRadius = discRadius * 0.56
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.94))
    ctx.setLineWidth(max(1.2, size * 0.021))
    ctx.strokeEllipse(in: CGRect(
        x: center.x - innerRingRadius,
        y: center.y - innerRingRadius,
        width: innerRingRadius * 2,
        height: innerRingRadius * 2
    ))

    // Optically centered crisp white play glyph
    let triHeight = discRadius * 0.52
    let triWidth = triHeight * 0.86
    let opticalShift = triWidth * 0.11
    let leftX = center.x - triWidth * 0.45 + opticalShift
    let rightX = leftX + triWidth
    let topY = center.y + triHeight * 0.5
    let bottomY = center.y - triHeight * 0.5

    let triangle = CGMutablePath()
    triangle.move(to: CGPoint(x: leftX, y: topY))
    triangle.addLine(to: CGPoint(x: rightX, y: center.y))
    triangle.addLine(to: CGPoint(x: leftX, y: bottomY))
    triangle.closeSubpath()

    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.98))
    ctx.addPath(triangle)
    ctx.fillPath()

    // Top inner glass highlight rim on squircle
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.14))
    ctx.setLineWidth(max(1.0, size * 0.009))
    ctx.addPath(squirclePath)
    ctx.strokePath()

    ctx.restoreGState()

    guard let image = ctx.makeImage() else {
        fatalError("Failed to create CGImage")
    }
    let bitmap = NSBitmapImageRep(cgImage: image)
    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Failed to encode PNG")
    }
    return pngData
}

let iconSpecs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (filename, px) in iconSpecs {
    let data = renderIcon(pixelSize: px)
    try data.write(to: outputDir.appendingPathComponent(filename))
}
