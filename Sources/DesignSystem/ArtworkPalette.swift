import AppKit
import CoreGraphics
import Observation
import SwiftUI

/// Harmonious 3-tone ambient palette extracted from the active track's album artwork.
public struct ArtworkPalette: Sendable, Equatable {
    public let primary: Color
    public let secondary: Color
    public let highlight: Color

    public init(primary: Color, secondary: Color, highlight: Color) {
        self.primary = primary
        self.secondary = secondary
        self.highlight = highlight
    }

    public static let obsidianDefault = ArtworkPalette(
        primary: Color(red: 0.42, green: 0.11, blue: 0.18),
        secondary: Color(red: 0.12, green: 0.14, blue: 0.24),
        highlight: Color(red: 0.65, green: 0.18, blue: 0.26)
    )
}

/// Fetches, caches, and extracts harmonious ambient color palettes from album artwork URLs.
@MainActor
@Observable
public final class ArtworkVisualStore {
    public private(set) var currentImage: NSImage?
    public private(set) var palette: ArtworkPalette = .obsidianDefault

    @ObservationIgnored
    private var loadedURL: URL?

    @ObservationIgnored
    private var fetchTask: Task<Void, Never>?

    @ObservationIgnored
    private var cache: [URL: (image: NSImage, palette: ArtworkPalette)] = [:]

    @ObservationIgnored
    private var insertionOrder: [URL] = []

    private let maxCachedItems = 36

    public init() {}

    public func update(artworkURL: URL?) {
        guard artworkURL != loadedURL else { return }
        loadedURL = artworkURL
        fetchTask?.cancel()

        guard let artworkURL else {
            currentImage = nil
            palette = .obsidianDefault
            return
        }

        if let hit = cache[artworkURL] {
            currentImage = hit.image
            palette = hit.palette
            return
        }

        fetchTask = Task { [weak self] in
            guard let data = await Self.downloadImageData(from: artworkURL),
                  !Task.isCancelled,
                  let image = NSImage(data: data)
            else {
                return
            }

            let extracted = Self.extractPalette(from: image)
            guard !Task.isCancelled else { return }

            self?.store(image: image, palette: extracted, for: artworkURL)
            self?.currentImage = image
            self?.palette = extracted
        }
    }

    private func store(image: NSImage, palette: ArtworkPalette, for url: URL) {
        cache[url] = (image, palette)
        insertionOrder.removeAll { $0 == url }
        insertionOrder.append(url)
        if insertionOrder.count > maxCachedItems, let oldest = insertionOrder.first {
            insertionOrder.removeFirst()
            cache.removeValue(forKey: oldest)
        }
    }

    private static func downloadImageData(from url: URL) async -> Data? {
        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            return data
        } catch {
            return nil
        }
    }

    /// Downsamples artwork to a 28x28 bitmap and scores hue buckets for vibrancy and legibility
    /// so ambient gradients stay rich while preserving crisp white typography contrast.
    private static func extractPalette(from image: NSImage) -> ArtworkPalette {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return .obsidianDefault
        }

        let sampleSize = 28
        let bytesPerPixel = 4
        let bytesPerRow = sampleSize * bytesPerPixel
        var rawBytes = [UInt8](repeating: 0, count: sampleSize * bytesPerRow)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &rawBytes,
            width: sampleSize,
            height: sampleSize,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return .obsidianDefault
        }

        ctx.interpolationQuality = .medium
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))

        struct Bucket {
            var count: Double = 0
            var rSum: Double = 0
            var gSum: Double = 0
            var bSum: Double = 0
            var weightSum: Double = 0
        }

        // 12 hue buckets (30 degrees each) + 1 low-saturation bucket
        var buckets = Array(repeating: Bucket(), count: 13)

        for index in stride(from: 0, to: rawBytes.count, by: 4) {
            let r = Double(rawBytes[index]) / 255.0
            let g = Double(rawBytes[index + 1]) / 255.0
            let b = Double(rawBytes[index + 2]) / 255.0
            let a = Double(rawBytes[index + 3]) / 255.0
            guard a > 0.5 else { continue }

            let maxC = max(r, g, b)
            let minC = min(r, g, b)
            let delta = maxC - minC
            let saturation = maxC > 0 ? delta / maxC : 0
            let brightness = maxC

            // Ignore near-black and near-white clipping regions
            guard brightness > 0.08, !(brightness > 0.94 && saturation < 0.12) else { continue }

            let bucketIndex: Int
            if saturation < 0.16 {
                bucketIndex = 12
            } else {
                var hue: Double = 0
                if delta > 0 {
                    if maxC == r {
                        hue = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
                    } else if maxC == g {
                        hue = (b - r) / delta + 2
                    } else {
                        hue = (r - g) / delta + 4
                    }
                    hue *= 60
                    if hue < 0 { hue += 360 }
                }
                bucketIndex = min(11, Int(hue / 30.0))
            }

            // Favor vivid, mid-luminance colors that create lush Apple Music ambience
            let vibrancyWeight = 0.35 + saturation * 1.65 * (1.0 - abs(brightness - 0.52))
            buckets[bucketIndex].count += 1
            buckets[bucketIndex].rSum += r * vibrancyWeight
            buckets[bucketIndex].gSum += g * vibrancyWeight
            buckets[bucketIndex].bSum += b * vibrancyWeight
            buckets[bucketIndex].weightSum += vibrancyWeight
        }

        let rankedColors: [NSColor] = buckets
            .enumerated()
            .filter { $0.element.weightSum > 0.5 }
            .sorted { lhs, rhs in
                // Prefer chromatic buckets over pure gray unless artwork is monochrome
                let lhsBonus = lhs.offset == 12 ? 0.35 : 1.0
                let rhsBonus = rhs.offset == 12 ? 0.35 : 1.0
                return (lhs.element.weightSum * lhsBonus) > (rhs.element.weightSum * rhsBonus)
            }
            .map { _, bucket in
                NSColor(
                    srgbRed: bucket.rSum / bucket.weightSum,
                    green: bucket.gSum / bucket.weightSum,
                    blue: bucket.bSum / bucket.weightSum,
                    alpha: 1.0
                )
            }

        guard let first = rankedColors.first else {
            return .obsidianDefault
        }

        let second = rankedColors.count > 1 ? rankedColors[1] : shiftedHue(first, by: 0.09)
        let third = rankedColors.count > 2 ? rankedColors[2] : shiftedHue(first, by: -0.07)

        return ArtworkPalette(
            primary: calibratedColor(first, minSat: 0.38, maxSat: 0.78, minBri: 0.28, maxBri: 0.54),
            secondary: calibratedColor(second, minSat: 0.32, maxSat: 0.72, minBri: 0.16, maxBri: 0.38),
            highlight: calibratedColor(third, minSat: 0.42, maxSat: 0.82, minBri: 0.36, maxBri: 0.62)
        )
    }

    private static func calibratedColor(
        _ nsColor: NSColor,
        minSat: CGFloat,
        maxSat: CGFloat,
        minBri: CGFloat,
        maxBri: CGFloat
    ) -> Color {
        guard let hsb = nsColor.usingColorSpace(.sRGB) else {
            return Color(nsColor: nsColor)
        }
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        hsb.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        let clampedS = s < 0.08 ? s : min(max(s, minSat), maxSat)
        let clampedB = min(max(b, minBri), maxBri)
        return Color(hue: Double(h), saturation: Double(clampedS), brightness: Double(clampedB))
    }

    private static func shiftedHue(_ nsColor: NSColor, by delta: CGFloat) -> NSColor {
        guard let hsb = nsColor.usingColorSpace(.sRGB) else { return nsColor }
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        hsb.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let nextH = (h + delta).truncatingRemainder(dividingBy: 1.0)
        return NSColor(
            hue: nextH < 0 ? nextH + 1.0 : nextH,
            saturation: s,
            brightness: b,
            alpha: 1.0
        )
    }
}
