import SwiftUI

/// Refined obsidian launch veil that masks the initial web bootstrap with zero white flash.
public struct LaunchSplashView: View {
    @State private var isPulsing = false

    public init() {}

    public var body: some View {
        ZStack {
            ThemeTokens.Colors.canvasObsidian

            // Subtle ambient crimson aura behind the vinyl emblem
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            ThemeTokens.Colors.accentCrimson.opacity(isPulsing ? 0.16 : 0.09),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 140
                    )
                )
                .frame(width: 280, height: 280)
                .blur(radius: 18)

            VStack(spacing: 18) {
                VinylBrandMark()
                    .scaleEffect(isPulsing ? 1.02 : 0.985)

                Text("YouTube Music")
                    .font(.system(size: 16, weight: .medium))
                    .tracking(0.3)
                    .foregroundStyle(ThemeTokens.Colors.titlePrimary)

                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 72, height: 2.5)
                    .overlay(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(ThemeTokens.Colors.accentCrimson.opacity(0.9))
                            .frame(width: 28, height: 2.5)
                            .offset(x: isPulsing ? 44 : 0)
                    }
                    .clipShape(Capsule(style: .continuous))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

private struct VinylBrandMark: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            ThemeTokens.Colors.accentCrimson,
                            Color(red: 0.80, green: 0.02, blue: 0.16)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 72, height: 72)
                .shadow(color: ThemeTokens.Colors.accentCrimson.opacity(0.32), radius: 22, y: 8)

            // Delicate vinyl groove ring
            Circle()
                .strokeBorder(Color.white.opacity(0.24), lineWidth: 1.2)
                .frame(width: 54, height: 54)

            // Inner play ring
            Circle()
                .strokeBorder(Color.white.opacity(0.88), lineWidth: 1.8)
                .frame(width: 34, height: 34)

            Image(systemName: "play.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .offset(x: 1.2)
        }
    }
}
