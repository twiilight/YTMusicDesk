import AppKit
import CoreDomain
import SwiftUI

/// Full-window Apple Music-inspired Now Playing & Synced Lyrics showcase with dynamic
/// artwork-extracted fluid background, hero album cover, tactile controls, and scrolling lyrics.
public struct ImmersiveNowPlayingView: View {
    private let playbackState: PlaybackState
    private let lyricsState: LyricsLoadState
    private let artworkStore: ArtworkVisualStore
    private let onCommand: (PlaybackCommand) -> Void
    private let onRetryLyrics: () -> Void
    private let onClose: () -> Void

    @State private var scrubbingTime: TimeInterval?

    public init(
        playbackState: PlaybackState,
        lyricsState: LyricsLoadState,
        artworkStore: ArtworkVisualStore,
        onCommand: @escaping (PlaybackCommand) -> Void,
        onRetryLyrics: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.playbackState = playbackState
        self.lyricsState = lyricsState
        self.artworkStore = artworkStore
        self.onCommand = onCommand
        self.onRetryLyrics = onRetryLyrics
        self.onClose = onClose
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: playbackState.isPlaying ? 0.04 : 0.8)) { _ in
            let liveTime = scrubbingTime ?? playbackState.interpolatedTime(at: ProcessInfo.processInfo.systemUptime)

            ZStack(alignment: .topTrailing) {
                AmbientFlowBackgroundView(
                    palette: artworkStore.palette,
                    isAnimating: playbackState.isPlaying
                )

                GeometryReader { geo in
                    let isCompact = geo.size.width < 820

                    if isCompact {
                        VStack(spacing: 16) {
                            compactHeader(liveTime: liveTime)
                                .padding(.horizontal, 28)
                                .padding(.top, 26)

                            SyncedLyricsView(
                                loadState: lyricsState,
                                currentTime: liveTime,
                                onSeek: { onCommand(.seek($0)) },
                                onRetry: onRetryLyrics
                            )
                        }
                    } else {
                        HStack(spacing: 0) {
                            leftArtworkDeck(liveTime: liveTime, containerHeight: geo.size.height)
                                .frame(width: min(max(geo.size.width * 0.43, 350), 460))
                                .padding(.leading, 36)
                                .padding(.trailing, 18)

                            SyncedLyricsView(
                                loadState: lyricsState,
                                currentTime: liveTime,
                                onSeek: { onCommand(.seek($0)) },
                                onRetry: onRetryLyrics
                            )
                            .padding(.trailing, 28)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }

                // Subtle top-right dismiss capsule
                CollapseOverlayButton(action: onClose)
                    .padding(.top, 16)
                    .padding(.trailing, 18)
            }
        }
    }

    // MARK: - Wide Layout Left Deck

    private func leftArtworkDeck(liveTime: TimeInterval, containerHeight: CGFloat) -> some View {
        let artworkDimension = min(330, max(210, containerHeight * 0.42))
        let duration = max(playbackState.duration, 0)

        return VStack(spacing: 0) {
            Spacer(minLength: 18)

            heroArtwork(size: artworkDimension)

            Spacer(minLength: 24).frame(maxHeight: 34)

            // Title, Artist & Like
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(playbackState.track?.title ?? "YTMusicDesk")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.96))
                        .lineLimit(1)

                    if let artist = playbackState.track?.artist, !artist.isEmpty {
                        Text(artistSubtitle(artist: artist, album: playbackState.track?.album ?? ""))
                            .font(.system(size: 14.5, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.64))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                BarIconButton(
                    systemName: playbackState.likeStatus == .like ? "heart.fill" : "heart",
                    size: 16,
                    tint: playbackState.likeStatus == .like
                        ? ThemeTokens.Colors.accentCrimson
                        : Color.white.opacity(0.62),
                    hoverTint: playbackState.likeStatus == .like
                        ? ThemeTokens.Colors.accentCrimson
                        : .white,
                    tooltip: LocalizedCopy.likeTooltip
                ) {
                    onCommand(.toggleLike)
                }
            }
            .frame(maxWidth: artworkDimension)

            // Scrubber
            VStack(spacing: 5) {
                ScrubberSliderView(
                    value: liveTime,
                    in: 0...max(duration, 1),
                    isEnabled: playbackState.hasActiveTrack && duration > 0,
                    restingHeight: 4.5,
                    activeHeight: 6.5,
                    onChanged: { scrubbingTime = $0 },
                    onCommit: { target in
                        scrubbingTime = nil
                        onCommand(.seek(target))
                    }
                )

                HStack {
                    Text(PlaybackTimeFormatter.string(from: liveTime))
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(Color.white.opacity(0.54))
                    Spacer()
                    Text(PlaybackTimeFormatter.string(from: duration))
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(Color.white.opacity(0.54))
                }
            }
            .frame(maxWidth: artworkDimension)
            .padding(.top, 18)

            // Transport Controls
            HStack(spacing: 22) {
                BarIconButton(
                    systemName: "shuffle",
                    size: 14,
                    tint: playbackState.isShuffled ? .white : Color.white.opacity(0.54),
                    isActiveDot: playbackState.isShuffled,
                    tooltip: LocalizedCopy.shuffleTooltip
                ) {
                    onCommand(.toggleShuffle)
                }

                BarIconButton(
                    systemName: "backward.fill",
                    size: 20,
                    tint: Color.white.opacity(0.90),
                    isEnabled: playbackState.hasPrevious || liveTime > 3,
                    tooltip: LocalizedCopy.previousTooltip
                ) {
                    onCommand(.previousTrack)
                }

                PlayPauseCircleButton(
                    isPlaying: playbackState.isPlaying,
                    isEnabled: playbackState.hasActiveTrack,
                    diameter: 48,
                    iconSize: 18,
                    tooltip: LocalizedCopy.playTooltip
                ) {
                    onCommand(.togglePlayPause)
                }

                BarIconButton(
                    systemName: "forward.fill",
                    size: 20,
                    tint: Color.white.opacity(0.90),
                    isEnabled: playbackState.hasNext,
                    tooltip: LocalizedCopy.nextTooltip
                ) {
                    onCommand(.nextTrack)
                }

                BarIconButton(
                    systemName: playbackState.repeatMode == .one ? "repeat.1" : "repeat",
                    size: 14,
                    tint: playbackState.repeatMode != .off ? .white : Color.white.opacity(0.54),
                    isActiveDot: playbackState.repeatMode != .off,
                    tooltip: LocalizedCopy.repeatTooltip
                ) {
                    onCommand(.cycleRepeat)
                }
            }
            .padding(.top, 18)

            // Volume Rail
            HStack(spacing: 10) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.white.opacity(0.46))

                ScrubberSliderView(
                    value: playbackState.isMuted ? 0 : playbackState.volume,
                    in: 0...1,
                    isEnabled: true,
                    restingHeight: 3.5,
                    activeHeight: 5,
                    onChanged: { onCommand(.setVolume($0)) },
                    onCommit: { onCommand(.setVolume($0)) }
                )

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.white.opacity(0.46))
            }
            .frame(maxWidth: artworkDimension)
            .padding(.top, 18)

            Spacer(minLength: 20)
        }
    }

    // MARK: - Narrow Window Compact Header

    private func compactHeader(liveTime: TimeInterval) -> some View {
        HStack(spacing: 14) {
            heroArtwork(size: 64)

            VStack(alignment: .leading, spacing: 3) {
                Text(playbackState.track?.title ?? "YTMusicDesk")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if let artist = playbackState.track?.artist, !artist.isEmpty {
                    Text(artist)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.64))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                BarIconButton(
                    systemName: "backward.fill",
                    size: 14,
                    tint: .white.opacity(0.88),
                    isEnabled: playbackState.hasPrevious || liveTime > 3,
                    tooltip: LocalizedCopy.previousTooltip
                ) {
                    onCommand(.previousTrack)
                }

                PlayPauseCircleButton(
                    isPlaying: playbackState.isPlaying,
                    isEnabled: playbackState.hasActiveTrack,
                    diameter: 34,
                    iconSize: 13,
                    tooltip: LocalizedCopy.playTooltip
                ) {
                    onCommand(.togglePlayPause)
                }

                BarIconButton(
                    systemName: "forward.fill",
                    size: 14,
                    tint: .white.opacity(0.88),
                    isEnabled: playbackState.hasNext,
                    tooltip: LocalizedCopy.nextTooltip
                ) {
                    onCommand(.nextTrack)
                }
            }
            .padding(.trailing, 42)
        }
    }

    // MARK: - Hero Artwork

    private func heroArtwork(size: CGFloat) -> some View {
        let cornerRadius = size > 120 ? 18.0 : 10.0

        return ZStack {
            if let image = artworkStore.currentImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.28, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.32))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(
            color: artworkStore.palette.primary.opacity(playbackState.isPlaying ? 0.55 : 0.28),
            radius: playbackState.isPlaying ? 36 : 18,
            y: playbackState.isPlaying ? 18 : 8
        )
        .shadow(color: Color.black.opacity(0.45), radius: 20, y: 12)
        .scaleEffect(size > 120 ? (playbackState.isPlaying ? 1.0 : 0.935) : 1.0)
        .animation(ThemeTokens.Motion.artworkPulse, value: playbackState.isPlaying)
    }

    private func artistSubtitle(artist: String, album: String) -> String {
        if album.isEmpty || album.caseInsensitiveCompare(artist) == .orderedSame {
            return artist
        }
        return "\(artist) — \(album)"
    }
}

private struct CollapseOverlayButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.down")
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(Color.white.opacity(isHovered ? 0.96 : 0.68))
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(Color.white.opacity(isHovered ? 0.16 : 0.09))
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.75)
                        )
                )
        }
        .buttonStyle(.plain)
        .help(LocalizedCopy.collapseNowPlayingTooltip)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isHovered = hovering
            }
        }
    }
}
