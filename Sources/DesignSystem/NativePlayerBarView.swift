import AppKit
import CoreDomain
import SwiftUI

/// Bespoke Apple Music-inspired frosted glass bottom player bar replacing YouTube Music's
/// built-in web bar with native macOS typography, ambient artwork tint, and tactile controls.
public struct NativePlayerBarView: View {
    private let playbackState: PlaybackState
    private let artworkStore: ArtworkVisualStore
    private let isImmersiveOpen: Bool
    private let isFloatingLyricsOpen: Bool
    private let onCommand: (PlaybackCommand) -> Void
    private let onToggleImmersive: () -> Void
    private let onToggleFloatingLyrics: () -> Void

    @State private var scrubbingTime: TimeInterval?

    public init(
        playbackState: PlaybackState,
        artworkStore: ArtworkVisualStore,
        isImmersiveOpen: Bool,
        isFloatingLyricsOpen: Bool = false,
        onCommand: @escaping (PlaybackCommand) -> Void,
        onToggleImmersive: @escaping () -> Void,
        onToggleFloatingLyrics: @escaping () -> Void = {}
    ) {
        self.playbackState = playbackState
        self.artworkStore = artworkStore
        self.isImmersiveOpen = isImmersiveOpen
        self.isFloatingLyricsOpen = isFloatingLyricsOpen
        self.onCommand = onCommand
        self.onToggleImmersive = onToggleImmersive
        self.onToggleFloatingLyrics = onToggleFloatingLyrics
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: playbackState.isPlaying ? 0.08 : 1.0)) { _ in
            let liveTime = scrubbingTime ?? playbackState.interpolatedTime(at: ProcessInfo.processInfo.systemUptime)

            ZStack(alignment: .top) {
                // Frosted obsidian surface with delicate ambient tint from active artwork
                barBackdrop

                HStack(spacing: 20) {
                    leadingTrackSection
                        .frame(maxWidth: .infinity, alignment: .leading)

                    centerTransportSection(liveTime: liveTime)
                        .frame(maxWidth: 480)

                    trailingUtilitySection
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 18)
                .frame(maxHeight: .infinity)

                // Top luminous glass edge
                Rectangle()
                    .fill(ThemeTokens.Colors.glassHighlight)
                    .frame(height: 0.5)
            }
            .frame(height: ThemeTokens.Metrics.playerBarHeight)
        }
    }

    // MARK: - Backdrop

    private var barBackdrop: some View {
        ZStack {
            ThemeTokens.Colors.playerBarBase
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.62)

            if playbackState.hasActiveTrack {
                LinearGradient(
                    colors: [
                        artworkStore.palette.primary.opacity(0.28),
                        artworkStore.palette.secondary.opacity(0.14),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .animation(ThemeTokens.Motion.paletteBlend, value: artworkStore.palette)
            }
        }
    }

    // MARK: - Leading Track Identity

    @ViewBuilder
    private var leadingTrackSection: some View {
        if let track = playbackState.track, playbackState.hasActiveTrack {
            HStack(spacing: 12) {
                ArtworkThumbnailButton(
                    image: artworkStore.currentImage,
                    palette: artworkStore.palette,
                    isImmersiveOpen: isImmersiveOpen,
                    action: onToggleImmersive
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ThemeTokens.Colors.titlePrimary)
                        .lineLimit(1)

                    if !track.artist.isEmpty {
                        Text(track.artist)
                            .font(.system(size: 11.5, weight: .regular))
                            .foregroundStyle(ThemeTokens.Colors.bodySecondary)
                            .lineLimit(1)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture(perform: onToggleImmersive)

                BarIconButton(
                    systemName: playbackState.likeStatus == .like ? "heart.fill" : "heart",
                    size: 13,
                    tint: playbackState.likeStatus == .like
                        ? ThemeTokens.Colors.accentCrimson
                        : ThemeTokens.Colors.chromeControlRest,
                    hoverTint: playbackState.likeStatus == .like
                        ? ThemeTokens.Colors.accentCrimson
                        : ThemeTokens.Colors.chromeControlHover,
                    tooltip: LocalizedCopy.likeTooltip
                ) {
                    onCommand(.toggleLike)
                }
            }
        } else {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 44, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(ThemeTokens.Colors.hairlineStroke, lineWidth: 0.75)
                        )
                    Image(systemName: "music.note")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.32))
                }

                Text(LocalizedCopy.idleTrackPlaceholder)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(ThemeTokens.Colors.titleMuted)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Center Transport & Scrubber

    private func centerTransportSection(liveTime: TimeInterval) -> some View {
        let enabled = playbackState.hasActiveTrack
        let duration = max(playbackState.duration, 0)

        return VStack(spacing: 4) {
            HStack(spacing: 16) {
                BarIconButton(
                    systemName: "shuffle",
                    size: 12.5,
                    tint: playbackState.isShuffled ? .white : ThemeTokens.Colors.chromeControlRest,
                    isActiveDot: playbackState.isShuffled,
                    isEnabled: enabled,
                    tooltip: LocalizedCopy.shuffleTooltip
                ) {
                    onCommand(.toggleShuffle)
                }

                BarIconButton(
                    systemName: "backward.fill",
                    size: 15,
                    tint: Color.white.opacity(0.86),
                    isEnabled: enabled && (playbackState.hasPrevious || liveTime > 3),
                    tooltip: LocalizedCopy.previousTooltip
                ) {
                    onCommand(.previousTrack)
                }

                PlayPauseCircleButton(
                    isPlaying: playbackState.isPlaying,
                    isEnabled: enabled,
                    diameter: 34,
                    iconSize: 13.5,
                    tooltip: LocalizedCopy.playTooltip
                ) {
                    onCommand(.togglePlayPause)
                }

                BarIconButton(
                    systemName: "forward.fill",
                    size: 15,
                    tint: Color.white.opacity(0.86),
                    isEnabled: enabled && playbackState.hasNext,
                    tooltip: LocalizedCopy.nextTooltip
                ) {
                    onCommand(.nextTrack)
                }

                BarIconButton(
                    systemName: playbackState.repeatMode == .one ? "repeat.1" : "repeat",
                    size: 12.5,
                    tint: playbackState.repeatMode != .off ? .white : ThemeTokens.Colors.chromeControlRest,
                    isActiveDot: playbackState.repeatMode != .off,
                    isEnabled: enabled,
                    tooltip: LocalizedCopy.repeatTooltip
                ) {
                    onCommand(.cycleRepeat)
                }
            }

            HStack(spacing: 9) {
                Text(PlaybackTimeFormatter.string(from: liveTime))
                    .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                    .foregroundStyle(ThemeTokens.Colors.titleMuted)
                    .frame(minWidth: 36, alignment: .trailing)

                ScrubberSliderView(
                    value: liveTime,
                    in: 0...max(duration, 1),
                    isEnabled: enabled && duration > 0,
                    restingHeight: 3.5,
                    activeHeight: 5.5,
                    onChanged: { preview in
                        scrubbingTime = preview
                    },
                    onCommit: { target in
                        scrubbingTime = nil
                        onCommand(.seek(target))
                    }
                )

                Text(PlaybackTimeFormatter.string(from: duration))
                    .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                    .foregroundStyle(ThemeTokens.Colors.titleMuted)
                    .frame(minWidth: 36, alignment: .leading)
            }
        }
    }

    // MARK: - Trailing Volume & Lyrics

    private var trailingUtilitySection: some View {
        HStack(spacing: 12) {
            HStack(spacing: 7) {
                BarIconButton(
                    systemName: volumeSymbolName,
                    size: 13,
                    tint: ThemeTokens.Colors.chromeControlRest,
                    tooltip: LocalizedCopy.muteTooltip
                ) {
                    onCommand(.toggleMute)
                }

                ScrubberSliderView(
                    value: playbackState.isMuted ? 0 : playbackState.volume,
                    in: 0...1,
                    isEnabled: true,
                    restingHeight: 3,
                    activeHeight: 4.5,
                    onChanged: { nextVol in
                        onCommand(.setVolume(nextVol))
                    },
                    onCommit: { finalVol in
                        onCommand(.setVolume(finalVol))
                    }
                )
                .frame(width: 76)
            }

            HStack(spacing: 6) {
                UtilityPillToggleButton(
                    activeSymbol: "captions.bubble.fill",
                    inactiveSymbol: "captions.bubble",
                    tooltip: LocalizedCopy.floatingLyricsTooltip,
                    isActive: isFloatingLyricsOpen,
                    isEnabled: true,
                    action: onToggleFloatingLyrics
                )

                UtilityPillToggleButton(
                    activeSymbol: "quote.bubble.fill",
                    inactiveSymbol: "quote.bubble",
                    tooltip: LocalizedCopy.lyricsTooltip,
                    isActive: isImmersiveOpen,
                    isEnabled: playbackState.hasActiveTrack,
                    action: onToggleImmersive
                )
            }
        }
    }

    private var volumeSymbolName: String {
        if playbackState.isMuted || playbackState.volume <= 0.01 {
            return "speaker.slash.fill"
        } else if playbackState.volume < 0.35 {
            return "speaker.wave.1.fill"
        } else if playbackState.volume < 0.72 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }
}

// MARK: - Supporting Subviews

private struct ArtworkThumbnailButton: View {
    let image: NSImage?
    let palette: ArtworkPalette
    let isImmersiveOpen: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(ThemeTokens.Colors.elevatedSurface)
                    Image(systemName: "music.note")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.4))
                }

                if isHovered {
                    Color.black.opacity(0.42)
                    Image(systemName: isImmersiveOpen ? "chevron.down" : "chevron.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8.5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.75)
            )
            .shadow(color: palette.primary.opacity(0.32), radius: 10, y: 3)
        }
        .buttonStyle(.plain)
        .help(LocalizedCopy.lyricsTooltip)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isHovered = hovering
            }
        }
    }
}

struct PlayPauseCircleButton: View {
    let isPlaying: Bool
    let isEnabled: Bool
    let diameter: CGFloat
    let iconSize: CGFloat
    let tooltip: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(isEnabled ? (isHovered ? 1.0 : 0.92) : 0.18))
                    .frame(width: diameter, height: diameter)
                    .shadow(color: .black.opacity(0.28), radius: 8, y: 3)

                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundStyle(isEnabled ? Color.black.opacity(0.92) : Color.white.opacity(0.35))
                    .offset(x: isPlaying ? 0 : 1.0)
            }
            .scaleEffect(isHovered && isEnabled ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .help(tooltip)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isHovered = hovering
            }
        }
    }
}

struct BarIconButton: View {
    let systemName: String
    let size: CGFloat
    let tint: Color
    var hoverTint: Color = .white
    var isActiveDot: Bool = false
    var isEnabled: Bool = true
    let tooltip: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemName)
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(isEnabled ? (isHovered ? hoverTint : tint) : ThemeTokens.Colors.chromeControlDisabled)
                    .frame(width: 26, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isHovered && isEnabled ? ThemeTokens.Colors.chromeHoverPlate : Color.clear)
                    )

                Circle()
                    .fill(isActiveDot && isEnabled ? Color.white : Color.clear)
                    .frame(width: 3.5, height: 3.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .help(tooltip)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isHovered = hovering
            }
        }
    }
}

private struct UtilityPillToggleButton: View {
    let activeSymbol: String
    let inactiveSymbol: String
    let tooltip: String
    let isActive: Bool
    let isEnabled: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: isActive ? activeSymbol : inactiveSymbol)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(
                    !isEnabled
                        ? ThemeTokens.Colors.chromeControlDisabled
                        : (isActive ? Color.black.opacity(0.9) : (isHovered ? .white : ThemeTokens.Colors.chromeControlRest))
                )
                .frame(width: 32, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            isActive && isEnabled
                                ? Color.white.opacity(0.92)
                                : (isHovered && isEnabled ? ThemeTokens.Colors.chromeHoverPlate : Color.white.opacity(0.05))
                        )
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .help(tooltip)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
