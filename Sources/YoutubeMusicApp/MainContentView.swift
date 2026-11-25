import CoreDomain
import DesignSystem
import SwiftUI
import WebEngine

/// Root SwiftUI composition combining the obsidian top backdrop, progress seam,
/// YouTube Music browse surface, docked native Apple Music-style player bar,
/// expandable ambient scrolling lyrics view, launch splash, and error recovery state.
struct MainContentView: View {
    let engineController: WebEngineController
    let coordinator: PlayerExperienceCoordinator

    var body: some View {
        ZStack {
            // Extends seamlessly behind the transparent unified macOS titlebar
            ThemeTokens.Colors.canvasObsidian
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TitlebarProgressSeamView(
                    progress: engineController.state.estimatedProgress,
                    isLoading: engineController.state.isLoading
                )

                ZStack {
                    // Primary browsing canvas + docked native frosted player bar
                    VStack(spacing: 0) {
                        WebViewSurface(controller: engineController)

                        NativePlayerBarView(
                            playbackState: engineController.playbackState,
                            artworkStore: coordinator.artworkStore,
                            isImmersiveOpen: coordinator.isImmersivePresented,
                            isFloatingLyricsOpen: coordinator.isFloatingLyricsVisible,
                            onCommand: { engineController.send($0) },
                            onToggleImmersive: {
                                withAnimation(ThemeTokens.Motion.immersiveToggle) {
                                    coordinator.toggleImmersive(
                                        hasActiveTrack: engineController.playbackState.hasActiveTrack
                                    )
                                }
                            },
                            onToggleFloatingLyrics: {
                                coordinator.toggleFloatingLyrics()
                            }
                        )
                    }

                    // Expandable Apple Music-inspired ambient Now Playing & Synced Lyrics showcase
                    if coordinator.isImmersivePresented {
                        ImmersiveNowPlayingView(
                            playbackState: engineController.playbackState,
                            lyricsState: coordinator.lyricsState,
                            artworkStore: coordinator.artworkStore,
                            onCommand: { engineController.send($0) },
                            onRetryLyrics: {
                                coordinator.retryLyrics(for: engineController.playbackState)
                            },
                            onClose: {
                                withAnimation(ThemeTokens.Motion.immersiveToggle) {
                                    coordinator.dismissImmersive()
                                }
                            }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(2)
                        .background(
                            Button("") {
                                withAnimation(ThemeTokens.Motion.immersiveToggle) {
                                    coordinator.dismissImmersive()
                                }
                            }
                            .keyboardShortcut(.escape, modifiers: [])
                            .opacity(0)
                            .allowsHitTesting(false)
                        )
                    }

                    if engineController.state.showsLaunchSplash {
                        LaunchSplashView()
                            .transition(.opacity)
                            .zIndex(3)
                    }

                    if let failure = engineController.state.loadFailure {
                        ErrorStateView(
                            failure: failure,
                            onRetry: { engineController.reload() },
                            onOpenInBrowser: { engineController.openCurrentURLInExternalBrowser() }
                        )
                        .transition(.opacity)
                        .zIndex(4)
                    }
                }
            }
            .ignoresSafeArea(edges: [.bottom, .leading, .trailing])
        }
        .animation(ThemeTokens.Motion.splashFadeOut, value: engineController.state.showsLaunchSplash)
        .animation(ThemeTokens.Motion.immersiveToggle, value: coordinator.isImmersivePresented)
        .animation(.easeOut(duration: 0.22), value: engineController.state.loadFailure != nil)
        .preferredColorScheme(.dark)
    }
}
