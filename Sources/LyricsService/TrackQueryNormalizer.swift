import CoreDomain
import Foundation

/// Normalizes YouTube Music track metadata by stripping common video/MV noise suffixes
/// so lyrics providers match songs accurately across English, Chinese, Japanese, and Korean catalogs.
public enum TrackQueryNormalizer {
    public struct NormalizedQuery: Sendable, Equatable {
        public let title: String
        public let artist: String
        public let album: String
        public let duration: Int?
    }

    private static let noisePatterns: [NSRegularExpression] = [
        // Parenthetical/bracketed YouTube video annotations
        try! NSRegularExpression(
            pattern: #"\s*[\(\[【（][^)\]】）]*(official|music\s*video|lyric\s*video|audio|mv|m/v|hd|4k|hq|live|visualizer|remaster(?:ed)?|explicit|clean|topic|完整版|高清|官方|纯享)[^)\]】）]*[\)\]】）]"#,
            options: [.caseInsensitive]
        ),
        // Featuring suffixes that often differ between YouTube and LRCLIB
        try! NSRegularExpression(
            pattern: #"\s*[\(\[]\s*(?:feat\.?|ft\.?|featuring)\s+[^\)\]]+[\)\]]"#,
            options: [.caseInsensitive]
        )
    ]

    public static func normalize(_ track: TrackMetadata) -> NormalizedQuery {
        let cleanedTitle = cleanTitle(track.title)
        let cleanedArtist = cleanArtist(track.artist)
        let cleanedAlbum = track.album.trimmingCharacters(in: .whitespacesAndNewlines)
        let durationSeconds = track.duration > 5 ? Int(track.duration.rounded()) : nil

        return NormalizedQuery(
            title: cleanedTitle.isEmpty ? track.title.trimmingCharacters(in: .whitespacesAndNewlines) : cleanedTitle,
            artist: cleanedArtist,
            album: cleanedAlbum,
            duration: durationSeconds
        )
    }

    public static func cleanTitle(_ raw: String) -> String {
        var result = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for regex in noisePatterns {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }
        return collapseWhitespace(result)
    }

    public static func cleanArtist(_ raw: String) -> String {
        var result = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // YouTube Music bylines sometimes combine "Artist • Album • 2023"
        if let bulletRange = result.range(of: " • ") {
            result = String(result[..<bulletRange.lowerBound])
        }
        // Strip YouTube auto-generated " - Topic" suffix
        if result.lowercased().hasSuffix(" - topic") {
            result = String(result.dropLast(" - topic".count))
        }
        return collapseWhitespace(result)
    }

    private static func collapseWhitespace(_ input: String) -> String {
        input
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
