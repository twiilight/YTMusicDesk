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
            let major = max(w, h)

            ZStack {
                // Deep obsidian anchor
                Color(red: 0.03, green: 0.03, blue: 0.045)

                // Primary ambient wash (top-left to center-left) — endRadius strictly within circle bounds to avoid clipping seams
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                palette.primary.opacity(0.88),
                                palette.primary.opacity(0.30),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 12,
                            endRadius: major * 0.56
                        )
                    )
                    .frame(width: major * 1.15, height: major * 1.15)
                    .offset(
                        x: driftPhase ? -w * 0.18 : -w * 0.28,
                        y: driftPhase ? -h * 0.14 : -h * 0.24
                    )

                // Secondary deep wash (bottom-right)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                palette.secondary.opacity(0.92),
                                palette.secondary.opacity(0.32),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 12,
                            endRadius: major * 0.58
                        )
                    )
                    .frame(width: major * 1.2, height: major * 1.2)
                    .offset(
                        x: driftPhase ? w * 0.20 : w * 0.30,
                        y: driftPhase ? h * 0.26 : h * 0.16
                    )

                // Luminous highlight ribbon (upper-right / lyrics halo)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                palette.highlight.opacity(0.50),
                                palette.highlight.opacity(0.14),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 8,
                            endRadius: major * 0.44
                        )
                    )
                    .frame(width: major * 0.92, height: major * 0.92)
                    .offset(
                        x: driftPhase ? w * 0.24 : w * 0.12,
                        y: driftPhase ? -h * 0.24 : -h * 0.12
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
