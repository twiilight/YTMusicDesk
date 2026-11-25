import CoreDomain
import SwiftUI

/// Restrained macOS navigation cluster (Back, Forward, Reload) crafted for the unified obsidian titlebar.
public struct TitlebarNavClusterView: View {
    private let canGoBack: Bool
    private let canGoForward: Bool
    private let isLoading: Bool
    private let onGoBack: () -> Void
    private let onGoForward: () -> Void
    private let onReload: () -> Void

    public init(
        canGoBack: Bool,
        canGoForward: Bool,
        isLoading: Bool,
        onGoBack: @escaping () -> Void,
        onGoForward: @escaping () -> Void,
        onReload: @escaping () -> Void
    ) {
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.isLoading = isLoading
        self.onGoBack = onGoBack
        self.onGoForward = onGoForward
        self.onReload = onReload
    }

    public var body: some View {
        HStack(spacing: 2) {
            ChromeIconButton(
                systemName: "chevron.left",
                tooltip: LocalizedCopy.backTooltip,
                isEnabled: canGoBack,
                action: onGoBack
            )
            ChromeIconButton(
                systemName: "chevron.right",
                tooltip: LocalizedCopy.forwardTooltip,
                isEnabled: canGoForward,
                action: onGoForward
            )
            ChromeIconButton(
                systemName: "arrow.clockwise",
                tooltip: LocalizedCopy.reloadTooltip,
                isEnabled: true,
                isLoading: isLoading,
                action: onReload
            )
        }
        .frame(height: ThemeTokens.Metrics.chromeButtonHeight)
    }
}

/// Quiet centered track/page title displayed in the unified obsidian titlebar.
public struct TitlebarTitleView: View {
    private let title: String

    public init(title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(ThemeTokens.Colors.titleMuted)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: 420)
            .allowsHitTesting(false)
    }
}

/// Subtle zoom-level reset pill shown only when the user has zoomed away from 100%.
public struct TitlebarZoomBadgeView: View {
    private let zoom: Double
    private let onResetZoom: () -> Void

    public init(zoom: Double, onResetZoom: @escaping () -> Void) {
        self.zoom = zoom
        self.onResetZoom = onResetZoom
    }

    public var body: some View {
        HStack {
            Spacer(minLength: 0)
            if abs(zoom - 1.0) > 0.01 {
                ZoomBadgeButton(zoom: zoom, action: onResetZoom)
            }
        }
        .frame(width: 82, height: ThemeTokens.Metrics.chromeButtonHeight)
    }
}

/// Whisper-quiet seam divider and crimson loading progress hairline separating titlebar and web canvas.
public struct TitlebarProgressSeamView: View {
    private let progress: Double
    private let isLoading: Bool

    public init(progress: Double, isLoading: Bool) {
        self.progress = progress
        self.isLoading = isLoading
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(ThemeTokens.Colors.hairlineStroke)
                .frame(height: 0.5)

            ProgressHairline(
                progress: progress,
                isVisible: isLoading && progress > 0.02 && progress < 0.99
            )
        }
        .frame(height: 1.5)
        .background(ThemeTokens.Colors.canvasObsidian)
    }
}

private struct ChromeIconButton: View {
    let systemName: String
    let tooltip: String
    let isEnabled: Bool
    var isLoading: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(foregroundColor)
                .frame(
                    width: ThemeTokens.Metrics.chromeButtonWidth,
                    height: ThemeTokens.Metrics.chromeButtonHeight
                )
                .background(
                    RoundedRectangle(cornerRadius: ThemeTokens.Metrics.chromeCornerRadius, style: .continuous)
                        .fill(isHovered && isEnabled ? ThemeTokens.Colors.chromeHoverPlate : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .help(tooltip)
        .onHover { hovering in
            withAnimation(ThemeTokens.Motion.chromeHover) {
                isHovered = hovering
            }
        }
        .opacity(isLoading ? 0.72 : 1.0)
    }

    private var foregroundColor: Color {
        if !isEnabled {
            return ThemeTokens.Colors.chromeControlDisabled
        }
        return isHovered ? ThemeTokens.Colors.chromeControlHover : ThemeTokens.Colors.chromeControlRest
    }
}

private struct ZoomBadgeButton: View {
    let zoom: Double
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text("\(Int((zoom * 100).rounded()))%")
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(isHovered ? ThemeTokens.Colors.chromeControlHover : ThemeTokens.Colors.titleMuted)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    Capsule(style: .continuous)
                        .fill(ThemeTokens.Colors.chromeHoverPlate.opacity(isHovered ? 1.4 : 0.85))
                )
        }
        .buttonStyle(.plain)
        .help(LocalizedCopy.resetZoomTooltip)
        .onHover { hovering in
            withAnimation(ThemeTokens.Motion.chromeHover) {
                isHovered = hovering
            }
        }
    }
}

private struct ProgressHairline: View {
    let progress: Double
    let isVisible: Bool

    var body: some View {
        GeometryReader { geometry in
            let clamped = min(max(progress, 0.0), 1.0)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            ThemeTokens.Colors.accentCrimson,
                            ThemeTokens.Colors.accentVermilion
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: geometry.size.width * clamped, height: 1.5)
                .animation(ThemeTokens.Motion.progressSmooth, value: clamped)
        }
        .frame(height: 1.5)
        .opacity(isVisible ? 1 : 0)
        .animation(.easeOut(duration: 0.25), value: isVisible)
        .allowsHitTesting(false)
    }
}
