import CoreDomain

/// Subtle desktop ergonomics scoped strictly to `music.youtube.com`:
/// - Prevents accidental text selection on persistent chrome controls (top nav & player bar),
///   while preserving normal selection on search inputs, titles, and lyrics.
/// - Softens top hairline so the native macOS obsidian titlebar blends seamlessly into the page.
public struct ViewportErgonomicsRefinement: WebEnhancement {
    public let id = "macos.viewport-ergonomics"
    public let displayName = "Desktop Viewport Ergonomics"

    public init() {}

    public func styleInjections() -> [WebStyleInjection] {
        [
            WebStyleInjection(
                identifier: "ytm-desktop-viewport-ergonomics",
                css: Self.stylesheet,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true,
                allowedHosts: ["music.youtube.com"]
            )
        ]
    }

    private static let stylesheet = """
    ytmusic-nav-bar,
    ytmusic-player-bar,
    ytmusic-guide-renderer {
      -webkit-user-select: none;
      user-select: none;
    }

    ytmusic-nav-bar input,
    ytmusic-search-box input,
    ytmusic-player-bar .title,
    ytmusic-player-bar .subtitle {
      -webkit-user-select: text;
      user-select: text;
    }

    /* Keep top nav backdrop harmoniously matched with the native obsidian titlebar */
    #nav-bar-background.ytmusic-app-layout {
      background-color: #030303;
    }

    /* Avoid harsh default outlines on mouse clicks while retaining keyboard accessibility */
    :focus:not(:focus-visible) {
      outline: none;
    }
    """
}
