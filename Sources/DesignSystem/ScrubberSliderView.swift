import SwiftUI

/// Sleek Apple Music-inspired interactive scrubber & volume slider with hover expansion
/// and drag-preview support that never fights live playback ticks.
public struct ScrubberSliderView: View {
    private let value: Double
    private let range: ClosedRange<Double>
    private let isEnabled: Bool
    private let restingHeight: CGFloat
    private let activeHeight: CGFloat
    private let onChanged: ((Double) -> Void)?
    private let onCommit: (Double) -> Void

    @State private var isHovered = false
    @State private var isDragging = false
    @State private var dragValue: Double?

    public init(
        value: Double,
        in range: ClosedRange<Double> = 0...1,
        isEnabled: Bool = true,
        restingHeight: CGFloat = 3.5,
        activeHeight: CGFloat = 5.5,
        onChanged: ((Double) -> Void)? = nil,
        onCommit: @escaping (Double) -> Void
    ) {
        self.value = value
        self.range = range
        self.isEnabled = isEnabled
        self.restingHeight = restingHeight
        self.activeHeight = activeHeight
        self.onChanged = onChanged
        self.onCommit = onCommit
    }

    public var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let span = max(range.upperBound - range.lowerBound, 0.0001)
            let displayed = dragValue ?? value
            let normalized = CGFloat(min(max((displayed - range.lowerBound) / span, 0), 1))
            let barHeight = (isHovered || isDragging) && isEnabled ? activeHeight : restingHeight
            let thumbSize = activeHeight + 5

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(isEnabled ? 0.18 : 0.08))
                    .frame(height: barHeight)

                Capsule(style: .continuous)
                    .fill(Color.white.opacity(isEnabled ? ((isHovered || isDragging) ? 0.96 : 0.78) : 0.22))
                    .frame(width: max(0, width * normalized), height: barHeight)

                if (isHovered || isDragging) && isEnabled {
                    Circle()
                        .fill(Color.white)
                        .frame(width: thumbSize, height: thumbSize)
                        .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                        .offset(x: max(0, min(width - thumbSize, width * normalized - thumbSize / 2)))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        guard isEnabled else { return }
                        isDragging = true
                        let ratio = min(max(gesture.location.x / width, 0), 1)
                        let nextValue = range.lowerBound + ratio * span
                        dragValue = nextValue
                        onChanged?(nextValue)
                    }
                    .onEnded { gesture in
                        guard isEnabled else { return }
                        let ratio = min(max(gesture.location.x / width, 0), 1)
                        let finalValue = range.lowerBound + ratio * span
                        dragValue = nil
                        isDragging = false
                        onCommit(finalValue)
                    }
            )
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.14)) {
                    isHovered = hovering
                }
            }
        }
        .frame(height: max(16, activeHeight + 10))
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

/// Formats playback seconds into crisp `m:ss` or `h:mm:ss` labels.
public enum PlaybackTimeFormatter {
    public static func string(from seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}
