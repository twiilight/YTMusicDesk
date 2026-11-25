import AppKit
import CoreDomain
import LyricsService
import SwiftUI
import WebEngine
import WebEnhancements

/// Thin composition root assembling domain configuration, pluggable enhancements,
/// WebKit engine, lyrics & visual experience coordinator, main window, floating lyrics HUD, and menus.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, MenuActionTarget {
    private let configuration: AppConfiguration
    private let enhancementRegistry: EnhancementRegistry
    private var engineController: WebEngineController?
    private var experienceCoordinator: PlayerExperienceCoordinator?
    private var mainWindowController: MainWindowController?
    private var floatingLyricsController: FloatingLyricsWindowController?
    private var menuBuilder: MainMenuBuilder?

    init(
        configuration: AppConfiguration = .standard,
        enhancementRegistry: EnhancementRegistry = .defaultRegistry()
    ) {
        self.configuration = configuration
        self.enhancementRegistry = enhancementRegistry
        super.init()
    }

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        let engine = WebEngineController(
            configuration: configuration,
            navigationPolicy: NavigationPolicy(primaryHost: configuration.homeURL.host ?? "music.youtube.com"),
            injections: enhancementRegistry.compiledInjections()
        )
        self.engineController = engine

        let lyricsProvider = CachedLyricsProvider(
            upstream: LRCLIBLyricsProvider(),
            bundleIdentifier: configuration.bundleIdentifier
        )
        let coordinator = PlayerExperienceCoordinator(lyricsProvider: lyricsProvider)
        self.experienceCoordinator = coordinator

        engine.onPlaybackStateChanged = { [weak coordinator] state in
            coordinator?.sync(with: state)
        }

        let windowController = MainWindowController(
            configuration: configuration,
            engineController: engine,
            coordinator: coordinator
        )
        self.mainWindowController = windowController

        let floatingController = FloatingLyricsWindowController(
            engineController: engine,
            coordinator: coordinator
        )
        self.floatingLyricsController = floatingController
        coordinator.onFloatingLyricsStateChanged = { [weak floatingController] in
            floatingController?.syncPanelState()
        }

        let builder = MainMenuBuilder(appName: configuration.appName, actionTarget: self)
        self.menuBuilder = builder
        NSApp.mainMenu = builder.buildMainMenu()

        windowController.showAndFocus()
        engine.loadHome()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Restore the main window whenever it is hidden, even if the floating lyrics panel is visible.
        if !(mainWindowController?.window?.isVisible ?? false) {
            mainWindowController?.showAndFocus()
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !configuration.hidesWindowOnClose
    }

    // MARK: - MenuActionTarget

    func performReload() { engineController?.reload() }
    func performGoBack() { engineController?.goBack() }
    func performGoForward() { engineController?.goForward() }
    func performGoHome() { engineController?.loadHome() }
    func performZoomIn() { engineController?.zoomIn() }
    func performZoomOut() { engineController?.zoomOut() }
    func performResetZoom() { engineController?.resetZoom() }
    func performCopyCurrentURL() { _ = engineController?.copyCurrentURLToPasteboard() }
    func performOpenInBrowser() { engineController?.openCurrentURLInExternalBrowser() }
    func performToggleFullScreen() { mainWindowController?.toggleFullScreen() }

    func performTogglePlayPause() { engineController?.send(.togglePlayPause) }
    func performPreviousTrack() { engineController?.send(.previousTrack) }
    func performNextTrack() { engineController?.send(.nextTrack) }
    func performToggleLike() { engineController?.send(.toggleLike) }
    func performToggleMute() { engineController?.send(.toggleMute) }

    func performVolumeUp() {
        guard let engine = engineController else { return }
        engine.send(.setVolume(min(1.0, engine.playbackState.volume + 0.1)))
    }

    func performVolumeDown() {
        guard let engine = engineController else { return }
        engine.send(.setVolume(max(0.0, engine.playbackState.volume - 0.1)))
    }

    func performToggleImmersiveLyrics() {
        guard let engine = engineController, let coordinator = experienceCoordinator else { return }
        withAnimation {
            coordinator.toggleImmersive(hasActiveTrack: engine.playbackState.hasActiveTrack)
        }
    }

    func performToggleFloatingLyrics() {
        experienceCoordinator?.toggleFloatingLyrics()
    }

    func performToggleFloatingLyricsLock() {
        experienceCoordinator?.toggleFloatingClickThroughLocked()
    }
}
