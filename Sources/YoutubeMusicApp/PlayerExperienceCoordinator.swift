import CoreDomain
import DesignSystem
import Foundation
import LyricsService
import Observation

/// Coordinates artwork visual palette extraction, asynchronous lyrics loading,
/// and immersive Now Playing presentation while keeping views declarative and decoupled.
@MainActor
@Observable
public final class PlayerExperienceCoordinator {
    public let artworkStore = ArtworkVisualStore()
    public private(set) var lyricsState: LyricsLoadState = .idle
    public var isImmersivePresented = false

    @ObservationIgnored
    private let lyricsProvider: any LyricsProviding

    @ObservationIgnored
    private var activeTrackKey: String?

    @ObservationIgnored
    private var lyricsTask: Task<Void, Never>?

    public init(lyricsProvider: any LyricsProviding = CachedLyricsProvider()) {
        self.lyricsProvider = lyricsProvider
    }

    public func sync(with playbackState: PlaybackState) {
        artworkStore.update(artworkURL: playbackState.track?.artworkURL)

        guard let track = playbackState.track, playbackState.hasActiveTrack else {
            if activeTrackKey != nil {
                activeTrackKey = nil
                lyricsTask?.cancel()
                lyricsState = .idle
            }
            return
        }

        let key = track.identityKey
        let trackChanged = key != activeTrackKey
        let gainedPageFallback = lyricsState == .unavailable
            && !(playbackState.pageLyricsText?.isEmpty ?? true)

        guard trackChanged || gainedPageFallback else { return }

        activeTrackKey = key
        fetchLyrics(for: track, pageFallbackText: playbackState.pageLyricsText)
    }

    public func retryLyrics(for playbackState: PlaybackState) {
        guard let track = playbackState.track, playbackState.hasActiveTrack else { return }
        activeTrackKey = track.identityKey
        lyricsTask?.cancel()
        lyricsState = .loading(track)

        let provider = lyricsProvider
        let fallbackText = playbackState.pageLyricsText
        let expectedKey = track.identityKey

        lyricsTask = Task { [weak self] in
            if let cached = provider as? CachedLyricsProvider {
                await cached.invalidateCache(for: track)
            }
            let doc = await provider.fetchLyrics(for: track, pageFallbackText: fallbackText)
            guard !Task.isCancelled, let self, self.activeTrackKey == expectedKey else { return }
            self.lyricsState = doc.map { .loaded($0) } ?? .unavailable
        }
    }

    public func toggleImmersive(hasActiveTrack: Bool) {
        if isImmersivePresented {
            isImmersivePresented = false
        } else if hasActiveTrack {
            isImmersivePresented = true
        }
    }

    public func dismissImmersive() {
        isImmersivePresented = false
    }

    // MARK: - Private

    private func fetchLyrics(for track: TrackMetadata, pageFallbackText: String?) {
        lyricsTask?.cancel()
        lyricsState = .loading(track)

        let provider = lyricsProvider
        let expectedKey = track.identityKey

        lyricsTask = Task { [weak self] in
            let doc = await provider.fetchLyrics(for: track, pageFallbackText: pageFallbackText)
            guard !Task.isCancelled, let self, self.activeTrackKey == expectedKey else { return }
            self.lyricsState = doc.map { .loaded($0) } ?? .unavailable
        }
    }
}
