import CoreDomain

/// Restrained macOS visual polish scoped strictly to `music.youtube.com`:
/// - Eliminates initial white flash by locking the obsidian canvas before first paint.
/// - Disables awkward document rubber-band overscroll outside the app viewport.
/// - Refines scrollbars, Retina typography smoothing, and text selection highlight.
public struct MacOSChromeRefinement: WebEnhancement {
    public let id = "macos.chrome-refinement"
    public let displayName = "macOS Chrome Refinement"

    public init() {}

    public func styleInjections() -> [WebStyleInjection] {
        [
            WebStyleInjection(
                identifier: "ytm-desktop-macos-chrome",
                css: Self.stylesheet,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true,
                allowedHosts: ["music.youtube.com"]
            )
        ]
    }

    private static let stylesheet = """
    :root {
      color-scheme: dark;
    }

    html,
    body {
      background-color: #030303 !important;
      overscroll-behavior: none !important;
      -webkit-font-smoothing: antialiased;
      -moz-osx-font-smoothing: grayscale;
    }

    ::selection {
      background: rgba(255, 45, 85, 0.34);
      color: #ffffff;
    }

    /* Sleek macOS-inspired dark scrollbars */
    ::-webkit-scrollbar {
      width: 8px;
      height: 8px;
      background: transparent;
    }

    ::-webkit-scrollbar-track {
      background: transparent;
    }

    ::-webkit-scrollbar-thumb {
      background: rgba(255, 255, 255, 0.16);
      border-radius: 999px;
      border: 2px solid transparent;
      background-clip: content-box;
    }

    ::-webkit-scrollbar-thumb:hover {
      background: rgba(255, 255, 255, 0.30);
      border: 2px solid transparent;
      background-clip: content-box;
    }

    ::-webkit-scrollbar-corner {
      background: transparent;
    }
    """
}
