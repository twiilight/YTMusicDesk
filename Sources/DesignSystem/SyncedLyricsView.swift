import CoreDomain
import SwiftUI

/// Apple Music-inspired synced lyrics view with progressive depth-of-field blur,
/// spring auto-centering, hover unblur, and click-to-seek on every line.
public struct SyncedLyricsView: View {
    private let loadState: LyricsLoadState
    private let currentTime: TimeInterval
    private let onSeek: (TimeInterval) -> Void
    private let onRetry: () -> Void

    @State private var isHoveringLyrics = false
    @State private var hoveredLineID: Int?
    @State private var lastManualInteraction = Date.distantPast

    public init(
        loadState: LyricsLoadState,
        currentTime: TimeInterval,
        onSeek: @escaping (TimeInterval) -> Void,
        onRetry: @escaping () -> Void
    ) {
        self.loadState = loadState
        self.currentTime = currentTime
        self.onSeek = onSeek
        self.onRetry = onRetry
    }

    public var body: some View {
        switch loadState {
        case .idle:
            emptyPlaceholder(
                symbol: "quote.bubble",
                title: LocalizedCopy.idleTrackPlaceholder,
                subtitle: nil,
                showRetry: false
            )

        case .loading:
            loadingSkeletonView

        case .unavailable:
            emptyPlaceholder(
                symbol: "quote.bubble",
                title: LocalizedCopy.lyricsUnavailableTitle,
                subtitle: LocalizedCopy.lyricsUnavailableSubtitle,
                showRetry: true
            )

        case .loaded(let document):
            switch document.content {
            case .synced(let lines):
                syncedLinesView(lines: lines, source: document.source)

            case .plain(let paragraphs):
                plainLyricsView(lines: paragraphs, source: document.source)

            case .instrumental:
                emptyPlaceholder(
                    symbol: "waveform",
                    title: LocalizedCopy.lyricsInstrumentalTitle,
                    subtitle: nil,
                    showRetry: false
                )
            }
        }
    }

    // MARK: - Synced Scrolling Lyrics

    private func syncedLinesView(lines: [LyricLine], source: String) -> some View {
        let activeIndex = LyricsSyncEngine.activeLineIndex(in: lines, at: currentTime)

        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 22) {
                    Color.clear.frame(height: 110)

                    ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                        let isActive = activeIndex == index
                        let distance = activeIndex.map { abs(index - $0) } ?? index
                        let isPast = activeIndex.map { index < $0 } ?? false
                        let isLineHovered = hoveredLineID == line.id

                        Button {
                            lastManualInteraction = .distantPast
                            onSeek(line.startTime)
                        } label: {
                            Text(line.text)
                                .font(.system(size: isActive ? 27 : 24, weight: .bold))
                                .lineSpacing(5)
                                .multilineTextAlignment(.leading)
                                .foregroundStyle(lineColor(isActive: isActive, isPast: isPast, isHovered: isLineHovered))
                                .shadow(
                                    color: isActive ? Color.white.opacity(0.18) : Color.clear,
                                    radius: isActive ? 14 : 0
                                )
                                .blur(radius: lineBlur(distance: distance, isActive: isActive))
                                .scaleEffect(isActive ? 1.02 : 1.0, anchor: .leading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(isLineHovered ? Color.white.opacity(0.08) : Color.clear)
                                )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .id(line.id)
                        .onHover { hovering in
                            withAnimation(.easeOut(duration: 0.14)) {
                                hoveredLineID = hovering ? line.id : (hoveredLineID == line.id ? nil : hoveredLineID)
                            }
                        }
                        .animation(.easeOut(duration: 0.30), value: isActive)
                        .animation(.easeOut(duration: 0.22), value: isHoveringLyrics)
                    }

                    Text("Lyrics · \(source)")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.28))
                        .padding(.horizontal, 14)
                        .padding(.top, 26)

                    Color.clear.frame(height: 220)
                }
                .padding(.horizontal, 16)
            }
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.24)) {
                    isHoveringLyrics = hovering
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 8).onChanged { _ in
                    lastManualInteraction = Date()
                }
            )
            .onChange(of: activeIndex) { _, newIndex in
                guard let newIndex,
                      lines.indices.contains(newIndex),
                      Date().timeIntervalSince(lastManualInteraction) > 3.2
                else {
                    return
                }
                let targetID = lines[newIndex].id
                withAnimation(ThemeTokens.Motion.lyricScroll) {
                    proxy.scrollTo(targetID, anchor: UnitPoint(x: 0.5, y: 0.36))
                }
            }
            .onAppear {
                if let activeIndex, lines.indices.contains(activeIndex) {
                    proxy.scrollTo(lines[activeIndex].id, anchor: UnitPoint(x: 0.5, y: 0.36))
                }
            }
            .mask(verticalEdgeFadeMask)
        }
    }

    // MARK: - Plain Static Lyrics

    private func plainLyricsView(lines: [String], source: String) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text(LocalizedCopy.plainLyricsBadge)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.56))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .padding(.top, 36)
                    .padding(.bottom, 8)

                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: 21, weight: .semibold))
                        .lineSpacing(5)
                        .foregroundStyle(Color.white.opacity(0.84))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text("Lyrics · \(source)")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.28))
                    .padding(.top, 20)
                    .padding(.bottom, 120)
            }
            .padding(.horizontal, 26)
        }
        .mask(verticalEdgeFadeMask)
    }

    // MARK: - Loading & Empty States

    private var loadingSkeletonView: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()
            ForEach(0..<5, id: \.self) { index in
                let widths: [CGFloat] = [260, 340, 220, 310, 180]
                SkeletonLyricCapsule(width: widths[index % widths.count], delay: Double(index) * 0.14)
            }
            Spacer()
        }
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func emptyPlaceholder(
        symbol: String,
        title: String,
        subtitle: String?,
        showRetry: Bool
    ) -> some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.36))

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.82))

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.46))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }

            if showRetry {
                Button(action: onRetry) {
                    Text(LocalizedCopy.retryLyricsButton)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.86))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.10))
                                .overlay(
                                    Capsule(style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.75)
                                )
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    // MARK: - Helpers

    private func lineColor(isActive: Bool, isPast: Bool, isHovered: Bool) -> Color {
        if isActive {
            return Color.white.opacity(0.98)
        }
        if isHovered {
            return Color.white.opacity(0.86)
        }
        if isHoveringLyrics {
            return Color.white.opacity(isPast ? 0.44 : 0.56)
        }
        return Color.white.opacity(isPast ? 0.24 : 0.36)
    }

    private func lineBlur(distance: Int, isActive: Bool) -> CGFloat {
        if isActive || isHoveringLyrics {
            return 0
        }
        switch distance {
        case 0: return 0
        case 1: return 0.5
        case 2: return 1.0
        default: return 1.5
        }
    }

    private var verticalEdgeFadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .black, location: 0.11),
                .init(color: .black, location: 0.86),
                .init(color: .clear, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct SkeletonLyricCapsule: View {
    let width: CGFloat
    let delay: Double

    @State private var bright = false

    var body: some View {
        Capsule(style: .continuous)
            .fill(Color.white.opacity(bright ? 0.18 : 0.07))
            .frame(width: width, height: 22)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.1).delay(delay).repeatForever(autoreverses: true)) {
                    bright = true
                }
            }
    }
}
