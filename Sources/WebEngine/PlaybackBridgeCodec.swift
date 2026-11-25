import CoreDomain
import Foundation

/// Pure codec translating between JavaScript bridge messages and domain `PlaybackState`/`PlaybackCommand`.
/// Isolated from `WKWebView` so wire decoding and command serialization are directly unit-testable.
public enum PlaybackBridgeCodec {
    public struct EncodedCommand: Sendable, Equatable {
        public let javascript: String
        public let optimisticState: PlaybackState
    }

    public static func decodePlaybackState(
        from body: Any,
        previous: PlaybackState,
        sampledUptime: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) -> PlaybackState? {
        guard let dict = body as? [String: Any],
              let type = dict["type"] as? String,
              type == "playbackState"
        else {
            return nil
        }

        let title = (dict["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let artist = (dict["artist"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let album = (dict["album"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let artworkURLString = dict["artworkURL"] as? String
        let artworkURL = artworkURLString.flatMap { URL(string: $0) }
        let videoID = dict["videoID"] as? String

        let isPlaying = dict["isPlaying"] as? Bool ?? false
        let currentTime = (dict["currentTime"] as? NSNumber)?.doubleValue ?? 0
        let duration = (dict["duration"] as? NSNumber)?.doubleValue ?? 0
        let volume = (dict["volume"] as? NSNumber)?.doubleValue ?? previous.volume
        let isMuted = dict["isMuted"] as? Bool ?? false
        let isShuffled = dict["isShuffled"] as? Bool ?? false
        let repeatRaw = dict["repeatMode"] as? String ?? "off"
        let repeatMode = RepeatMode(rawValue: repeatRaw) ?? .off
        let likeRaw = dict["likeStatus"] as? String ?? "indifferent"
        let likeStatus = LikeStatus(rawValue: likeRaw) ?? .indifferent
        let hasPrevious = dict["hasPrevious"] as? Bool ?? false
        let hasNext = dict["hasNext"] as? Bool ?? false
        let pageLyricsText = dict["pageLyricsText"] as? String

        let isSameTrack: Bool = {
            guard let prev = previous.track else { return false }
            if let videoID, !videoID.isEmpty, let prevID = prev.videoID, !prevID.isEmpty {
                return videoID == prevID && prev.title.caseInsensitiveCompare(title) == .orderedSame
            }
            return prev.title.caseInsensitiveCompare(title) == .orderedSame
                && prev.artist.caseInsensitiveCompare(artist) == .orderedSame
        }()

        let track: TrackMetadata? = title.isEmpty
            ? previous.track
            : TrackMetadata(
                title: title,
                artist: artist,
                album: album,
                artworkURL: artworkURL ?? (isSameTrack ? previous.track?.artworkURL : nil),
                videoID: videoID,
                duration: duration > 0 ? duration : (isSameTrack ? (previous.track?.duration ?? 0) : 0)
            )

        return PlaybackState(
            track: track,
            isPlaying: isPlaying,
            currentTime: max(0, currentTime),
            duration: max(0, duration),
            volume: min(max(volume, 0), 1),
            isMuted: isMuted,
            isShuffled: isShuffled,
            repeatMode: repeatMode,
            likeStatus: likeStatus,
            hasPrevious: hasPrevious,
            hasNext: hasNext,
            pageLyricsText: pageLyricsText,
            sampledUptime: sampledUptime
        )
    }

    public static func encode(
        command: PlaybackCommand,
        currentState: PlaybackState,
        sampledUptime: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) -> EncodedCommand {
        let ns = WebBridgeContract.jsNamespace
        var nextState = currentState
        let script: String

        switch command {
        case .togglePlayPause:
            nextState.isPlaying.toggle()
            nextState.sampledUptime = sampledUptime
            script = "window.\(ns) && window.\(ns).dispatch('togglePlayPause');"

        case .nextTrack:
            script = "window.\(ns) && window.\(ns).dispatch('nextTrack');"

        case .previousTrack:
            script = "window.\(ns) && window.\(ns).dispatch('previousTrack');"

        case .seek(let seconds):
            let clamped = min(max(seconds, 0), max(currentState.duration, 0))
            nextState.currentTime = clamped
            nextState.sampledUptime = sampledUptime
            script = "window.\(ns) && window.\(ns).dispatch('seek', \(clamped));"

        case .setVolume(let volume):
            let clamped = min(max(volume, 0), 1)
            nextState.volume = clamped
            if clamped > 0 { nextState.isMuted = false }
            script = "window.\(ns) && window.\(ns).dispatch('setVolume', \(clamped));"

        case .toggleMute:
            nextState.isMuted.toggle()
            script = "window.\(ns) && window.\(ns).dispatch('toggleMute');"

        case .toggleLike:
            nextState.likeStatus = currentState.likeStatus == .like ? .indifferent : .like
            script = "window.\(ns) && window.\(ns).dispatch('toggleLike');"

        case .toggleShuffle:
            nextState.isShuffled.toggle()
            script = "window.\(ns) && window.\(ns).dispatch('toggleShuffle');"

        case .cycleRepeat:
            script = "window.\(ns) && window.\(ns).dispatch('cycleRepeat');"
        }

        return EncodedCommand(javascript: script, optimisticState: nextState)
    }
}
