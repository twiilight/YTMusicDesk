import SwiftUI

/// Refined obsidian launch veil featuring the original Vinyl Waveform emblem
/// so startup masks the initial web bootstrap with zero white flash.
public struct LaunchSplashView: View {
    @State private var isPulsing = false

    public init() {}

    public var body: some View {
        ZStack {
            ThemeTokens.Colors.canvasObsidian

            // Subtle ambient crimson aura behind the vinyl waveform emblem
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            ThemeTokens.Colors.accentCrimson.opacity(isPulsing ? 0.16 : 0.08),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 145
                    )
                )
                .frame(width: 290, height: 290)
                .blur(radius: 18)

            VStack(spacing: 18) {
                VinylWaveformMark(isPulsing: isPulsing)

                Text("YTMusicDesk")
                    .font(.system(size: 16, weight: .medium))
                    .tracking(0.3)
                    .foregroundStyle(ThemeTokens.Colors.titlePrimary)

                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 72, height: 2.5)
                    .overlay(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.64, blue: 0.38),
                                        ThemeTokens.Colors.accentCrimson
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 28, height: 2.5)
                            .offset(x: isPulsing ? 44 : 0)
                    }
                    .clipShape(Capsule(style: .continuous))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

private struct VinylWaveformMark: View {
    let isPulsing: Bool

    private let restingHeights: [CGFloat] = [16, 30, 40, 26, 14]
    private let pulsingHeights: [CGFloat] = [20, 36, 32, 34, 18]

    var body: some View {
        ZStack {
            // Satin obsidian vinyl disc
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.11, blue: 0.14),
                            Color(red: 0.05, green: 0.05, blue: 0.065)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 78, height: 78)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                )
                .shadow(color: ThemeTokens.Colors.accentCrimson.opacity(0.26), radius: 22, y: 8)

            Circle()
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.8)
                .frame(width: 64, height: 64)

            Circle()
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.8)
                .frame(width: 52, height: 52)

            // 5 Luminous amber-to-crimson waveform bars
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.64, blue: 0.38),
                                    ThemeTokens.Colors.accentCrimson,
                                    Color(red: 0.80, green: 0.08, blue: 0.32)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(
                            width: 5,
                            height: isPulsing ? pulsingHeights[index] : restingHeights[index]
                        )
                        .shadow(color: ThemeTokens.Colors.accentCrimson.opacity(0.55), radius: 6)
                }
            }
        }
    }
}
