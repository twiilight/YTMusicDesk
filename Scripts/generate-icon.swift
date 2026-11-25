#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation

/// Generates the original Obsidian Vinyl Waveform macOS squircle `AppIcon.iconset`
/// using CoreGraphics so the compiled `.app` ships with a crisp, Retina-ready Dock icon.
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

    // macOS icon safe inset (~9.5% padding for authentic Dock optical sizing)
    let inset = size * 0.095
    let cardRect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let cornerRadius = cardRect.width * 0.225
    let squirclePath = CGPath(roundedRect: cardRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    let center = CGPoint(x: cardRect.midX, y: cardRect.midY)

    // Outer macOS Dock drop shadow
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -size * 0.018),
        blur: size * 0.036,
        color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.48)
    )
    ctx.addPath(squirclePath)
    ctx.setFillColor(CGColor(red: 0.035, green: 0.035, blue: 0.048, alpha: 1.0))
    ctx.fillPath()
    ctx.restoreGState()

    // Clip to squircle for obsidian surface, vinyl disc, and waveform
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()

    // Deep obsidian-plum vertical surface gradient
    let bgColors = [
        CGColor(red: 0.12, green: 0.11, blue: 0.145, alpha: 1.0),
        CGColor(red: 0.035, green: 0.035, blue: 0.048, alpha: 1.0)
    ] as CFArray
    if let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(
            bgGradient,
            start: CGPoint(x: cardRect.midX, y: cardRect.maxY),
            end: CGPoint(x: cardRect.midX, y: cardRect.minY),
            options: []
        )
    }

    // Satin obsidian vinyl disc
    let discR = cardRect.width * 0.39
    let discRect = CGRect(x: center.x - discR, y: center.y - discR, width: discR * 2, height: discR * 2)
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -size * 0.012),
        blur: size * 0.035,
        color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.65)
    )
    ctx.addEllipse(in: discRect)
    ctx.setFillColor(CGColor(red: 0.075, green: 0.075, blue: 0.095, alpha: 1.0))
    ctx.fillPath()
    ctx.restoreGState()

    // Diagonal satin specular reflection on vinyl surface
    ctx.saveGState()
    ctx.addEllipse(in: discRect)
    ctx.clip()
    let sheenColors = [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.0),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.085),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.0),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.045),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.0)
    ] as CFArray
    if let sheenGrad = CGGradient(colorsSpace: colorSpace, colors: sheenColors, locations: [0.0, 0.28, 0.50, 0.72, 1.0]) {
        ctx.drawLinearGradient(
            sheenGrad,
            start: CGPoint(x: discRect.minX, y: discRect.maxY),
            end: CGPoint(x: discRect.maxX, y: discRect.minY),
            options: []
        )
    }
    ctx.restoreGState()

    // Delicate concentric vinyl micro-grooves (skip finest grooves at tiny 16px size for clarity)
    let grooveRatios: [CGFloat] = pixelSize >= 64 ? [0.94, 0.85, 0.76, 0.67] : [0.94]
    for ratio in grooveRatios {
        let r = discR * ratio
        ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: ratio == 0.94 ? 0.13 : 0.065))
        ctx.setLineWidth(max(0.75, size * 0.0032))
        ctx.strokeEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
    }

    // Warm crimson-amber ambient aura behind waveform
    let glowColors = [
        CGColor(red: 1.0, green: 0.22, blue: 0.36, alpha: 0.44),
        CGColor(red: 0.90, green: 0.14, blue: 0.34, alpha: 0.14),
        CGColor(red: 1.0, green: 0.20, blue: 0.36, alpha: 0.0)
    ] as CFArray
    if let glowGrad = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 0.45, 1.0]) {
        ctx.drawRadialGradient(
            glowGrad,
            startCenter: center,
            startRadius: size * 0.02,
            endCenter: center,
            endRadius: cardRect.width * 0.44,
            options: []
        )
    }

    // 5 sculpted luminous waveform bars (coral-amber -> vivid crimson -> deep rose)
    let barHeights: [CGFloat] = [0.22, 0.42, 0.54, 0.36, 0.19]
    let barWidth = cardRect.width * 0.068
    let barGap = cardRect.width * 0.044
    let totalW = CGFloat(barHeights.count) * barWidth + CGFloat(barHeights.count - 1) * barGap
    let startX = center.x - totalW / 2

    let barColors = [
        CGColor(red: 1.0, green: 0.64, blue: 0.38, alpha: 1.0),
        CGColor(red: 1.0, green: 0.20, blue: 0.34, alpha: 1.0),
        CGColor(red: 0.80, green: 0.08, blue: 0.32, alpha: 1.0)
    ] as CFArray
    let barGrad = CGGradient(colorsSpace: colorSpace, colors: barColors, locations: [0.0, 0.52, 1.0])

    for (index, hRatio) in barHeights.enumerated() {
        let h = cardRect.height * hRatio
        let x = startX + CGFloat(index) * (barWidth + barGap)
        let y = center.y - h / 2
        let barRect = CGRect(x: x, y: y, width: barWidth, height: h)
        let barPath = CGPath(roundedRect: barRect, cornerWidth: barWidth / 2, cornerHeight: barWidth / 2, transform: nil)

        ctx.saveGState()
        ctx.setShadow(
            offset: .zero,
            blur: size * 0.032,
            color: CGColor(red: 1.0, green: 0.24, blue: 0.38, alpha: 0.65)
        )
        ctx.addPath(barPath)
        ctx.setFillColor(CGColor(red: 1.0, green: 0.22, blue: 0.36, alpha: 1.0))
        ctx.fillPath()
        ctx.restoreGState()

        if let barGrad {
            ctx.saveGState()
            ctx.addPath(barPath)
            ctx.clip()
            ctx.drawLinearGradient(
                barGrad,
                start: CGPoint(x: center.x, y: center.y + cardRect.height * 0.27),
                end: CGPoint(x: center.x, y: center.y - cardRect.height * 0.27),
                options: []
            )
            ctx.restoreGState()
        }
    }

    ctx.restoreGState()

    // Subtle top specular glass highlight rim on squircle
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()
    let rimColors = [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.24),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.06),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.02)
    ] as CFArray
    if let rimGrad = CGGradient(colorsSpace: colorSpace, colors: rimColors, locations: [0.0, 0.35, 1.0]) {
        ctx.setLineWidth(max(1.0, size * 0.008))
        ctx.addPath(squirclePath)
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        ctx.drawLinearGradient(
            rimGrad,
            start: CGPoint(x: cardRect.midX, y: cardRect.maxY),
            end: CGPoint(x: cardRect.midX, y: cardRect.minY),
            options: []
        )
    }
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
