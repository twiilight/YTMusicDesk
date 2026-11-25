import SwiftUI

/// Slow-drifting Apple Music-inspired ambient color flow synthesized from the active album's palette.
public struct AmbientFlowBackgroundView: View {
    private let palette: ArtworkPalette
    private let isAnimating: Bool

    @State private var driftPhase = false

    public init(palette: ArtworkPalette, isAnimating: Bool) {
        self.palette = palette
        self.isAnimating = isAnimating
    }

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Deep obsidian anchor
                Color(red: 0.03, green: 0.03, blue: 0.045)

                // Primary ambient wash (top-left to center-left)
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                palette.primary.opacity(0.92),
                                palette.primary.opacity(0.32),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: max(w, h) * 0.62
                        )
                    )
                    .frame(width: w * 1.05, height: h * 1.05)
                    .offset(
                        x: driftPhase ? -w * 0.16 : -w * 0.28,
                        y: driftPhase ? -h * 0.12 : -h * 0.24
                    )

                // Secondary deep wash (bottom-right)
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                palette.secondary.opacity(0.95),
                                palette.secondary.opacity(0.35),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: max(w, h) * 0.65
                        )
                    )
                    .frame(width: w * 1.15, height: h * 1.10)
                    .offset(
                        x: driftPhase ? w * 0.22 : w * 0.32,
                        y: driftPhase ? h * 0.24 : h * 0.14
                    )

                // Luminous highlight ribbon (upper-right / lyrics halo)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                palette.highlight.opacity(0.55),
                                palette.highlight.opacity(0.14),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: max(w, h) * 0.52
                        )
                    )
                    .frame(width: w * 0.85, height: w * 0.85)
                    .offset(
                        x: driftPhase ? w * 0.26 : w * 0.12,
                        y: driftPhase ? -h * 0.26 : -h * 0.14
                    )

                // Calibrated dark glass veil preserving effortless white lyric contrast
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.24),
                        Color.black.opacity(0.34),
                        Color.black.opacity(0.46)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .drawingGroup()
            .animation(ThemeTokens.Motion.paletteBlend, value: palette)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
                driftPhase = true
            }
        }
    }
}
