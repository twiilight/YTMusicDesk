import CoreDomain
import SwiftUI

/// Frameless, single-line desktop floating lyrics HUD.
/// Rests as pure high-contrast floating typography with dual-layer shadow and blooms
/// into a frosted glass control capsule on hover without shifting the lyric baseline.
public struct FloatingLyricsView: View {
    private let playbackState: PlaybackState
    private let lyricsState: LyricsLoadState
    private let preferences: FloatingLyricsPreferences
    private let artworkStore: ArtworkVisualStore
    private let externalHover: Bool
    private let onCommand: (PlaybackCommand) -> Void
    private let onDecreaseFont: () -> Void
    private let onIncreaseFont: () -> Void
    private let onLockClickThrough: () -> Void
    private let onClose: () -> Void

    @State private var localHovered = false

    private var showsChrome: Bool {
        (externalHover || localHovered) && !preferences.isClickThroughLocked
    }

    public init(
        playbackState: PlaybackState,
        lyricsState: LyricsLoadState,
        preferences: FloatingLyricsPreferences,
        artworkStore: ArtworkVisualStore,
        externalHover: Bool = false,
        onCommand: @escaping (PlaybackCommand) -> Void,
        onDecreaseFont: @escaping () -> Void,
        onIncreaseFont: @escaping () -> Void,
        onLockClickThrough: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.playbackState = playbackState
        self.lyricsState = lyricsState
        self.preferences = preferences
        self.artworkStore = artworkStore
        self.externalHover = externalHover
        self.onCommand = onCommand
        self.onDecreaseFont = onDecreaseFont
        self.onIncreaseFont = onIncreaseFont
        self.onLockClickThrough = onLockClickThrough
        self.onClose = onClose
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: playbackState.isPlaying ? 0.08 : 1.0)) { _ in
            let liveTime = playbackState.interpolatedTime(at: ProcessInfo.processInfo.systemUptime)
            let snapshot = FloatingLyricsDisplayResolver.resolve(
                playbackState: playbackState,
                lyricsState: lyricsState,
                at: liveTime,
                prefersChinese: LocalizedCopy.prefersChinese
            )

            VStack(spacing: 4) {
                hoverControlBar
                    .opacity(showsChrome ? 1 : 0)
                    .allowsHitTesting(showsChrome)

                lyricLineStage(snapshot: snapshot)
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(hoverCapsuleBackdrop)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .animation(.easeOut(duration: 0.18), value: showsChrome)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.18)) {
                    localHovered = hovering
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Frosted Hover Backdrop

    private var hoverCapsuleBackdrop: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0.06, green: 0.06, blue: 0.08).opacity(0.66))

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.82)

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            artworkStore.palette.primary.opacity(0.26),
                            artworkStore.palette.secondary.opacity(0.14),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.75)
        }
        .shadow(color: Color.black.opacity(0.42), radius: 18, y: 6)
        .opacity(showsChrome ? 1 : 0)
        .animation(.easeOut(duration: 0.18), value: showsChrome)
    }

    // MARK: - Hover Micro-Control Bar

    private var hoverControlBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.42))
                .padding(.trailing, 4)

            HUDIconButton(
                systemName: "backward.fill",
                size: 11,
                isEnabled: playbackState.hasActiveTrack,
                tooltip: LocalizedCopy.previousTooltip
            ) {
                onCommand(.previousTrack)
            }

            HUDIconButton(
                systemName: playbackState.isPlaying ? "pause.fill" : "play.fill",
                size: 12,
                isEnabled: playbackState.hasActiveTrack,
                tooltip: LocalizedCopy.playTooltip
            ) {
                onCommand(.togglePlayPause)
            }

            HUDIconButton(
                systemName: "forward.fill",
                size: 11,
                isEnabled: playbackState.hasActiveTrack && playbackState.hasNext,
                tooltip: LocalizedCopy.nextTooltip
            ) {
                onCommand(.nextTrack)
            }

            dividerPipe

            HUDIconButton(
                systemName: "textformat.size.smaller",
                size: 11,
                isEnabled: preferences.fontSize > FloatingLyricsPreferences.minFontSize,
                tooltip: LocalizedCopy.floatingFontSmallerTooltip,
                action: onDecreaseFont
            )

            HUDIconButton(
                systemName: "textformat.size.larger",
                size: 11,
                isEnabled: preferences.fontSize < FloatingLyricsPreferences.maxFontSize,
                tooltip: LocalizedCopy.floatingFontLargerTooltip,
                action: onIncreaseFont
            )

            dividerPipe

            HUDIconButton(
                systemName: "lock.open",
                size: 11,
                isEnabled: true,
                tooltip: LocalizedCopy.floatingLockTooltip,
                action: onLockClickThrough
            )

            HUDIconButton(
                systemName: "xmark",
                size: 10.5,
                isEnabled: true,
                tooltip: LocalizedCopy.floatingCloseTooltip,
                action: onClose
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.28))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
                )
        )
        .frame(height: 26)
    }

    private var dividerPipe: some View {
        Rectangle()
            .fill(Color.white.opacity(0.14))
            .frame(width: 1, height: 11)
            .padding(.horizontal, 2)
    }

    // MARK: - Single-Line Floating Typography Stage

    private func lyricLineStage(snapshot: FloatingLyricSnapshot) -> some View {
        let baseOpacity: Double = {
            if !snapshot.isActiveLyric {
                return playbackState.isPlaying ? 0.84 : 0.68
            }
            return playbackState.isPlaying ? 0.98 : 0.76
        }()

        return ZStack {
            Text(snapshot.text)
                .id(snapshot.id)
                .font(.system(size: preferences.fontSize, weight: .bold))
                .foregroundStyle(Color.white.opacity(baseOpacity))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .multilineTextAlignment(.center)
                // Tight dark contour shadow + soft ambient shadow for effortless readability on any wallpaper
                .shadow(color: Color.black.opacity(0.92), radius: 2.2, x: 0, y: 1)
                .shadow(color: Color.black.opacity(0.68), radius: 10, x: 0, y: 3)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 6)),
                        removal: .opacity.combined(with: .offset(y: -6))
                    )
                )
        }
        .frame(maxWidth: .infinity, minHeight: 46, maxHeight: 56)
        .animation(.easeOut(duration: 0.28), value: snapshot.id)
        .animation(.easeOut(duration: 0.20), value: playbackState.isPlaying)
    }
}

private struct HUDIconButton: View {
    let systemName: String
    let size: CGFloat
    let isEnabled: Bool
    let tooltip: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(
                    !isEnabled
                        ? Color.white.opacity(0.24)
                        : (isHovered ? Color.white : Color.white.opacity(0.78))
                )
                .frame(width: 24, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isHovered && isEnabled ? Color.white.opacity(0.14) : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .help(tooltip)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}
