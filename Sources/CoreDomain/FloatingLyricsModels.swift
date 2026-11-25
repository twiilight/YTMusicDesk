import Foundation

/// User preferences governing the frameless floating desktop lyrics HUD.
public struct FloatingLyricsPreferences: Sendable, Equatable, Codable {
    public static let minFontSize: Double = 18
    public static let maxFontSize: Double = 36
    public static let fontSizeStep: Double = 2

    public var fontSize: Double
    public var isClickThroughLocked: Bool

    public init(
        fontSize: Double = 24,
        isClickThroughLocked: Bool = false
    ) {
        self.fontSize = Self.clampFontSize(fontSize)
        self.isClickThroughLocked = isClickThroughLocked
    }

    public mutating func increaseFontSize() {
        fontSize = Self.clampFontSize(fontSize + Self.fontSizeStep)
    }

    public mutating func decreaseFontSize() {
        fontSize = Self.clampFontSize(fontSize - Self.fontSizeStep)
    }

    public static func clampFontSize(_ value: Double) -> Double {
        min(max(value, minFontSize), maxFontSize)
    }
}

/// Resolved single-line payload displayed by the minimal floating desktop lyrics HUD.
public struct FloatingLyricSnapshot: Sendable, Equatable {
    public let id: String
    public let text: String
    public let isActiveLyric: Bool

    public init(id: String, text: String, isActiveLyric: Bool) {
        self.id = id
        self.text = text
        self.isActiveLyric = isActiveLyric
    }
}

/// Pure resolver choosing the single line to present in the floating lyrics bar
/// across synced lyrics, song intros, instrumental tracks, and fallback states.
public enum FloatingLyricsDisplayResolver {
    public static func resolve(
        playbackState: PlaybackState,
        lyricsState: LyricsLoadState,
        at time: TimeInterval,
        prefersChinese: Bool = false
    ) -> FloatingLyricSnapshot {
        guard let track = playbackState.track, playbackState.hasActiveTrack else {
            return FloatingLyricSnapshot(
                id: "idle",
                text: "YTMusicDesk",
                isActiveLyric: false
            )
        }

        let trackFallback = formattedTrackBanner(track)

        switch lyricsState {
        case .loaded(let document):
            switch document.content {
            case .synced(let lines):
                if let activeIndex = LyricsSyncEngine.activeLineIndex(in: lines, at: time),
                   lines.indices.contains(activeIndex)
                {
                    let line = lines[activeIndex]
                    return FloatingLyricSnapshot(
                        id: "\(track.identityKey)#\(line.id)",
                        text: line.text,
                        isActiveLyric: true
                    )
                }
                return FloatingLyricSnapshot(
                    id: "\(track.identityKey)#intro",
                    text: trackFallback,
                    isActiveLyric: false
                )

            case .instrumental:
                let tag = prefersChinese ? "纯音乐" : "Instrumental"
                return FloatingLyricSnapshot(
                    id: "\(track.identityKey)#instrumental",
                    text: "♪ \(track.title) · \(tag)",
                    isActiveLyric: false
                )

            case .plain:
                return FloatingLyricSnapshot(
                    id: "\(track.identityKey)#plain",
                    text: trackFallback,
                    isActiveLyric: false
                )
            }

        case .idle, .loading, .unavailable:
            return FloatingLyricSnapshot(
                id: "\(track.identityKey)#fallback",
                text: trackFallback,
                isActiveLyric: false
            )
        }
    }

    private static func formattedTrackBanner(_ track: TrackMetadata) -> String {
        if track.artist.isEmpty {
            return "♪ \(track.title)"
        }
        return "♪ \(track.title) — \(track.artist)"
    }
}
