import CoreDomain
import SwiftUI

/// Calm, tasteful recovery surface displayed when the network is unavailable or loading fails.
public struct ErrorStateView: View {
    private let failure: LoadFailure
    private let onRetry: () -> Void
    private let onOpenInBrowser: () -> Void

    public init(
        failure: LoadFailure,
        onRetry: @escaping () -> Void,
        onOpenInBrowser: @escaping () -> Void
    ) {
        self.failure = failure
        self.onRetry = onRetry
        self.onOpenInBrowser = onOpenInBrowser
    }

    public var body: some View {
        ZStack {
            ThemeTokens.Colors.canvasObsidian

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(ThemeTokens.Colors.elevatedSurface)
                        .frame(width: 58, height: 58)
                        .overlay(
                            Circle()
                                .strokeBorder(ThemeTokens.Colors.hairlineStroke, lineWidth: 1)
                        )

                    Image(systemName: failure.isOffline ? "wifi.slash" : "exclamationmark.triangle")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(ThemeTokens.Colors.titleMuted)
                }

                VStack(spacing: 8) {
                    Text(failure.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ThemeTokens.Colors.titlePrimary)

                    Text(failure.message)
                        .font(.system(size: 13))
                        .foregroundStyle(ThemeTokens.Colors.bodySecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)
                }

                HStack(spacing: 10) {
                    Button(action: onRetry) {
                        Text(LocalizedCopy.retryButton)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(ThemeTokens.Colors.accentCrimson)
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: onOpenInBrowser) {
                        Text(LocalizedCopy.openInBrowserButton)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(ThemeTokens.Colors.titlePrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(ThemeTokens.Colors.elevatedSurface)
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .strokeBorder(ThemeTokens.Colors.hairlineStroke, lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
            .padding(32)
        }
    }
}
