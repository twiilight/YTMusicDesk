import CoreDomain
import DesignSystem
import Foundation
import Observation

/// Coordinates artwork visual palette extraction, asynchronous lyrics loading,
/// immersive Now Playing presentation, and floating desktop lyrics state.
/// Depends strictly on `CoreDomain` protocols rather than concrete lyrics implementations.
@MainActor
@Observable
public final class PlayerExperienceCoordinator {
    public let artworkStore = ArtworkVisualStore()
    public private(set) var lyricsState: LyricsLoadState = .idle
    public var isImmersivePresented = false
    public private(set) var isFloatingLyricsVisible = false
    public private(set) var floatingPreferences: FloatingLyricsPreferences
    public var isFloatingPanelHovered = false

    @ObservationIgnored
    public var onFloatingLyricsStateChanged: (() -> Void)?

    @ObservationIgnored
    private let lyricsProvider: any LyricsProviding

    @ObservationIgnored
    private let defaults: UserDefaults

    @ObservationIgnored
    private var activeTrackKey: String?

    @ObservationIgnored
    private var lastQueriedDuration: Int = 0

    @ObservationIgnored
    private var lyricsTask: Task<Void, Never>?

    private enum DefaultsKey {
        static let floatingFontSize = "YTMusicDesk.floatingLyrics.fontSize"
    }

    public init(
        lyricsProvider: any LyricsProviding,
        defaults: UserDefaults = .standard
    ) {
        self.lyricsProvider = lyricsProvider
        self.defaults = defaults
        let savedSize = defaults.double(forKey: DefaultsKey.floatingFontSize)
        self.floatingPreferences = FloatingLyricsPreferences(
            fontSize: savedSize > 0 ? savedSize : 24,
            isClickThroughLocked: false
        )
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
        let roundedDuration = track.duration > 5 ? Int(track.duration.rounded()) : 0
        let trackChanged = key != activeTrackKey
        let durationSettledLater = !trackChanged
            && lastQueriedDuration == 0
            && roundedDuration > 5
            && lyricsState == .unavailable
        let gainedPageFallback = !trackChanged
            && lyricsState == .unavailable
            && !(playbackState.pageLyricsText?.isEmpty ?? true)

        guard trackChanged || durationSettledLater || gainedPageFallback else { return }

        activeTrackKey = key
        lastQueriedDuration = roundedDuration
        fetchLyrics(
            for: track,
            pageFallbackText: playbackState.pageLyricsText,
            settleDelayNanoseconds: trackChanged ? 180_000_000 : 0
        )
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
            await provider.invalidateCache(for: track)
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

    // MARK: - Floating Desktop Lyrics

    public func toggleFloatingLyrics() {
        isFloatingLyricsVisible.toggle()
        if !isFloatingLyricsVisible {
            isFloatingPanelHovered = false
        }
        onFloatingLyricsStateChanged?()
    }

    public func hideFloatingLyrics() {
        guard isFloatingLyricsVisible else { return }
        isFloatingLyricsVisible = false
        isFloatingPanelHovered = false
        onFloatingLyricsStateChanged?()
    }

    public func increaseFloatingFontSize() {
        floatingPreferences.increaseFontSize()
        defaults.set(floatingPreferences.fontSize, forKey: DefaultsKey.floatingFontSize)
    }

    public func decreaseFloatingFontSize() {
        floatingPreferences.decreaseFontSize()
        defaults.set(floatingPreferences.fontSize, forKey: DefaultsKey.floatingFontSize)
    }

    public func setFloatingClickThroughLocked(_ locked: Bool) {
        floatingPreferences.isClickThroughLocked = locked
        if locked {
            isFloatingPanelHovered = false
        }
        onFloatingLyricsStateChanged?()
    }

    public func toggleFloatingClickThroughLocked() {
        setFloatingClickThroughLocked(!floatingPreferences.isClickThroughLocked)
    }

    // MARK: - Private

    private func fetchLyrics(
        for track: TrackMetadata,
        pageFallbackText: String?,
        settleDelayNanoseconds: UInt64 = 0
    ) {
        lyricsTask?.cancel()
        lyricsState = .loading(track)

        let provider = lyricsProvider
        let expectedKey = track.identityKey

        lyricsTask = Task { [weak self] in
            if settleDelayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: settleDelayNanoseconds)
                guard !Task.isCancelled else { return }
            }
            let doc = await provider.fetchLyrics(for: track, pageFallbackText: pageFallbackText)
            guard !Task.isCancelled, let self, self.activeTrackKey == expectedKey else { return }
            self.lyricsState = doc.map { .loaded($0) } ?? .unavailable
        }
    }
}
