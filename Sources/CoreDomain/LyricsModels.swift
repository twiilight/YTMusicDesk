import Foundation

/// A single timestamped lyric line.
public struct LyricLine: Sendable, Equatable, Hashable, Identifiable, Codable {
    public let id: Int
    public let startTime: TimeInterval
    public let text: String

    public init(id: Int, startTime: TimeInterval, text: String) {
        self.id = id
        self.startTime = startTime
        self.text = text
    }
}

/// Representation of a track's resolved lyrics payload.
public enum LyricsContent: Sendable, Equatable, Codable {
    case synced([LyricLine])
    case plain([String])
    case instrumental
}

/// Complete resolved lyrics document along with provenance.
public struct LyricsDocument: Sendable, Equatable, Codable {
    public let source: String
    public let content: LyricsContent

    public init(source: String, content: LyricsContent) {
        self.source = source
        self.content = content
    }
}

/// Observable loading lifecycle for the currently playing track's lyrics.
public enum LyricsLoadState: Sendable, Equatable {
    case idle
    case loading(TrackMetadata)
    case loaded(LyricsDocument)
    case unavailable
}

/// Pure synchronization engine computing the active lyric index for any timestamp.
public enum LyricsSyncEngine {
    /// Returns the index of the latest lyric line whose `startTime <= time + leadOffset`.
    /// Uses binary search so 60/120Hz frame updates stay O(log n).
    public static func activeLineIndex(
        in lines: [LyricLine],
        at time: TimeInterval,
        leadOffset: TimeInterval = 0.22
    ) -> Int? {
        guard !lines.isEmpty else { return nil }
        let target = time + leadOffset
        if target < lines[0].startTime {
            return nil
        }

        var low = 0
        var high = lines.count - 1
        var answer = 0

        while low <= high {
            let mid = low + (high - low) / 2
            if lines[mid].startTime <= target {
                answer = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return answer
    }
}

/// Abstraction for pluggable lyrics sources (LRCLIB, page fallback, future providers).
public protocol LyricsProviding: Sendable {
    func fetchLyrics(for track: TrackMetadata, pageFallbackText: String?) async -> LyricsDocument?
}
