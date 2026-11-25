import AppKit
import CoreDomain
import DesignSystem
import SwiftUI
import WebEngine

/// Manages the singleton immersive macOS window, unified obsidian titlebar toolbar,
/// frame persistence, and close-to-hide background playback behavior.
@MainActor
final class MainWindowController: NSWindowController, NSWindowDelegate, NSToolbarDelegate {
    private let configuration: AppConfiguration
    private let engineController: WebEngineController

    private enum ToolbarItemID {
        static let navCluster = NSToolbarItem.Identifier("ytm.navCluster")
        static let pageTitle = NSToolbarItem.Identifier("ytm.pageTitle")
        static let zoomBadge = NSToolbarItem.Identifier("ytm.zoomBadge")
    }

    init(
        configuration: AppConfiguration,
        engineController: WebEngineController,
        coordinator: PlayerExperienceCoordinator
    ) {
        self.configuration = configuration
        self.engineController = engineController

        let initialRect = NSRect(
            x: 0,
            y: 0,
            width: configuration.defaultWindowSize.width,
            height: configuration.defaultWindowSize.height
        )

        let window = NSWindow(
            contentRect: initialRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = configuration.appName
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unifiedCompact
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(srgbRed: 3.0 / 255.0, green: 3.0 / 255.0, blue: 3.0 / 255.0, alpha: 1.0)
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.minSize = NSSize(
            width: configuration.minimumWindowSize.width,
            height: configuration.minimumWindowSize.height
        )
        window.collectionBehavior.insert(.fullScreenPrimary)

        let hostingController = NSHostingController(
            rootView: MainContentView(
                engineController: engineController,
                coordinator: coordinator
            )
        )
        window.contentViewController = hostingController

        super.init(window: window)

        window.delegate = self
        configureToolbar(on: window)

        if !window.setFrameUsingName(configuration.windowFrameAutosaveName) {
            window.center()
        }
        window.setFrameAutosaveName(configuration.windowFrameAutosaveName)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func showAndFocus() {
        guard let window else { return }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func toggleFullScreen() {
        window?.toggleFullScreen(nil)
    }

    // MARK: - Toolbar Setup

    private func configureToolbar(on window: NSWindow) {
        let toolbar = NSToolbar(identifier: "YoutubeMusicUnifiedToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.showsBaselineSeparator = false
        window.toolbar = toolbar
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            ToolbarItemID.navCluster,
            .flexibleSpace,
            ToolbarItemID.pageTitle,
            ToolbarItemID.zoomBadge
        ]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            ToolbarItemID.navCluster,
            .flexibleSpace,
            ToolbarItemID.pageTitle,
            .flexibleSpace,
            ToolbarItemID.zoomBadge
        ]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case ToolbarItemID.navCluster:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.isBordered = false
            item.isNavigational = true
            let hostingView = NSHostingView(rootView: NavClusterAdapterView(controller: engineController))
            hostingView.frame = NSRect(x: 0, y: 0, width: 84, height: 24)
            item.view = hostingView
            return item

        case ToolbarItemID.pageTitle:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.isBordered = false
            let hostingView = DraggablePassThroughHostingView(
                rootView: TitleAdapterView(controller: engineController)
            )
            hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 22)
            item.view = hostingView
            return item

        case ToolbarItemID.zoomBadge:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.isBordered = false
            let hostingView = NSHostingView(rootView: ZoomBadgeAdapterView(controller: engineController))
            hostingView.frame = NSRect(x: 0, y: 0, width: 84, height: 24)
            item.view = hostingView
            return item

        default:
            return nil
        }
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard configuration.hidesWindowOnClose else {
            return true
        }
        // Hide the window without releasing or interrupting active audio playback.
        sender.orderOut(nil)
        return false
    }
}

// MARK: - Reactive Toolbar Adapters

private struct NavClusterAdapterView: View {
    let controller: WebEngineController

    var body: some View {
        TitlebarNavClusterView(
            canGoBack: controller.state.canGoBack,
            canGoForward: controller.state.canGoForward,
            isLoading: controller.state.isLoading && controller.state.hasCompletedInitialLoad,
            onGoBack: { controller.goBack() },
            onGoForward: { controller.goForward() },
            onReload: { controller.reload() }
        )
    }
}

private struct TitleAdapterView: View {
    let controller: WebEngineController

    var body: some View {
        TitlebarTitleView(title: controller.state.displayTitle)
    }
}

private struct ZoomBadgeAdapterView: View {
    let controller: WebEngineController

    var body: some View {
        TitlebarZoomBadgeView(
            zoom: controller.state.pageZoom,
            onResetZoom: { controller.resetZoom() }
        )
    }
}

/// Ensures clicking or dragging on the centered title text behaves identically
/// to dragging any empty region of the native macOS titlebar.
private final class DraggablePassThroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
