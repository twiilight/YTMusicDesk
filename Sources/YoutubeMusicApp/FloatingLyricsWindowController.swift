import AppKit
import CoreDomain
import DesignSystem
import SwiftUI
import WebEngine

/// Manages the non-activating, borderless floating desktop lyrics `NSPanel`.
/// Remains visible across Spaces and full-screen apps without ever stealing keyboard focus,
/// and supports activeAlways mouse hover tracking even while another application is frontmost.
@MainActor
final class FloatingLyricsWindowController: NSWindowController {
    private static let frameAutosaveName = "YTMusicDeskFloatingLyricsPanel"
    private static let defaultSize = NSSize(width: 780, height: 108)

    private let engineController: WebEngineController
    private let coordinator: PlayerExperienceCoordinator
    private let floatingPanel: FloatingLyricsPanel

    init(
        engineController: WebEngineController,
        coordinator: PlayerExperienceCoordinator
    ) {
        self.engineController = engineController
        self.coordinator = coordinator

        let panel = FloatingLyricsPanel(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.acceptsMouseMovedEvents = true
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        let rootView = FloatingLyricsAdapterView(
            engineController: engineController,
            coordinator: coordinator
        )
        let hostingView = AlwaysTrackingHostingView(rootView: rootView) { [weak coordinator] hovering in
            coordinator?.isFloatingPanelHovered = hovering
        }
        hostingView.frame = NSRect(origin: .zero, size: Self.defaultSize)
        panel.contentView = hostingView

        self.floatingPanel = panel
        super.init(window: panel)

        if !panel.setFrameUsingName(Self.frameAutosaveName) {
            positionAtDefaultScreenBottom(panel)
        }
        panel.setFrameAutosaveName(Self.frameAutosaveName)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func syncPanelState() {
        floatingPanel.ignoresMouseEvents = coordinator.floatingPreferences.isClickThroughLocked

        if coordinator.isFloatingLyricsVisible {
            if !floatingPanel.isVisible {
                floatingPanel.orderFrontRegardless()
            }
        } else {
            floatingPanel.orderOut(nil)
        }
    }

    private func positionAtDefaultScreenBottom(_ panel: NSPanel) {
        let visibleFrame = NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let originX = visibleFrame.midX - Self.defaultSize.width / 2
        let originY = visibleFrame.minY + 34
        panel.setFrame(
            NSRect(x: originX, y: originY, width: Self.defaultSize.width, height: Self.defaultSize.height),
            display: false
        )
    }
}

// MARK: - Non-Activating Borderless Panel

private final class FloatingLyricsPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - Active-Always Hover Tracking Hosting View

private final class AlwaysTrackingHostingView<Content: View>: NSHostingView<Content> {
    private let onHoverChanged: @MainActor (Bool) -> Void
    private var hoverTrackingArea: NSTrackingArea?

    init(rootView: Content, onHoverChanged: @escaping @MainActor (Bool) -> Void) {
        self.onHoverChanged = onHoverChanged
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @available(*, unavailable)
    required init(rootView: Content) {
        fatalError("Use init(rootView:onHoverChanged:)")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onHoverChanged(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onHoverChanged(false)
    }
}

// MARK: - Reactive SwiftUI Adapter

private struct FloatingLyricsAdapterView: View {
    let engineController: WebEngineController
    let coordinator: PlayerExperienceCoordinator

    var body: some View {
        FloatingLyricsView(
            playbackState: engineController.playbackState,
            lyricsState: coordinator.lyricsState,
            preferences: coordinator.floatingPreferences,
            artworkStore: coordinator.artworkStore,
            externalHover: coordinator.isFloatingPanelHovered,
            onCommand: { engineController.send($0) },
            onDecreaseFont: { coordinator.decreaseFloatingFontSize() },
            onIncreaseFont: { coordinator.increaseFloatingFontSize() },
            onLockClickThrough: { coordinator.setFloatingClickThroughLocked(true) },
            onClose: { coordinator.hideFloatingLyrics() }
        )
    }
}
