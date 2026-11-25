import Foundation

public enum RepeatMode: String, Sendable, Equatable, Codable {
    case off
    case all
    case one
}

public enum LikeStatus: String, Sendable, Equatable, Codable {
    case indifferent
    case like
    case dislike
}

/// Immutable descriptor of the currently active track in YouTube Music.
public struct TrackMetadata: Sendable, Equatable, Hashable, Codable {
    public let title: String
    public let artist: String
    public let album: String
    public let artworkURL: URL?
    public let videoID: String?
    public let duration: TimeInterval

    public init(
        title: String,
        artist: String,
        album: String = "",
        artworkURL: URL? = nil,
        videoID: String? = nil,
        duration: TimeInterval = 0
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkURL = artworkURL
        self.videoID = videoID
        self.duration = duration
    }

    /// Stable identity key combining video ID with normalized title & artist
    /// so metadata settling after a track transition always triggers a fresh lyrics sync.
    public var identityKey: String {
        let normTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let videoID, !videoID.isEmpty {
            return "v:\(videoID)|\(normTitle)|\(normArtist)"
        }
        return "t:\(normTitle)|\(normArtist)"
    }
}

/// Real-time playback state bridged from the underlying YouTube Music media element and controls.
public struct PlaybackState: Sendable, Equatable {
    public var track: TrackMetadata?
    public var isPlaying: Bool
    public var currentTime: TimeInterval
    public var duration: TimeInterval
    public var volume: Double
    public var isMuted: Bool
    public var isShuffled: Bool
    public var repeatMode: RepeatMode
    public var likeStatus: LikeStatus
    public var hasPrevious: Bool
    public var hasNext: Bool
    public var pageLyricsText: String?
    /// Monotonic system uptime when `currentTime` was sampled, enabling smooth 60/120fps interpolation.
    public var sampledUptime: TimeInterval

    public init(
        track: TrackMetadata? = nil,
        isPlaying: Bool = false,
        currentTime: TimeInterval = 0,
        duration: TimeInterval = 0,
        volume: Double = 1.0,
        isMuted: Bool = false,
        isShuffled: Bool = false,
        repeatMode: RepeatMode = .off,
        likeStatus: LikeStatus = .indifferent,
        hasPrevious: Bool = false,
        hasNext: Bool = false,
        pageLyricsText: String? = nil,
        sampledUptime: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) {
        self.track = track
        self.isPlaying = isPlaying
        self.currentTime = currentTime
        self.duration = duration
        self.volume = volume
        self.isMuted = isMuted
        self.isShuffled = isShuffled
        self.repeatMode = repeatMode
        self.likeStatus = likeStatus
        self.hasPrevious = hasPrevious
        self.hasNext = hasNext
        self.pageLyricsText = pageLyricsText
        self.sampledUptime = sampledUptime
    }

    public var hasActiveTrack: Bool {
        guard let track else { return false }
        return !track.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Computes interpolated playback position at a given monotonic uptime for fluid UI/lyrics motion.
    public func interpolatedTime(at uptime: TimeInterval) -> TimeInterval {
        guard isPlaying, duration > 0 else {
            return min(max(currentTime, 0), max(duration, 0))
        }
        let elapsed = max(0, uptime - sampledUptime)
        return min(max(currentTime + elapsed, 0), duration)
    }
}

/// Commands dispatched from native macOS controls down to the YouTube Music playback engine.
public enum PlaybackCommand: Sendable, Equatable {
    case togglePlayPause
    case nextTrack
    case previousTrack
    case seek(TimeInterval)
    case setVolume(Double)
    case toggleMute
    case toggleLike
    case toggleShuffle
    case cycleRepeat
}

/// Decouples native playback UI & menus from `WebEngine`.
@MainActor
public protocol PlaybackControlling: AnyObject {
    var playbackState: PlaybackState { get }

    func send(_ command: PlaybackCommand)
}
