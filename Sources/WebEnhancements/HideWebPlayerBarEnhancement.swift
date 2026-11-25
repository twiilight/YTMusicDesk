import CoreDomain

/// Collapses YouTube Music's built-in bottom player bar visually while keeping its DOM
/// elements mounted and operable for `PlaybackBridgeEnhancement`.
/// Reclaims `--ytmusic-player-bar-height` so the browse canvas meets the native SwiftUI bar cleanly.
public struct HideWebPlayerBarEnhancement: WebEnhancement {
    public let id = "macos.hide-web-player-bar"
    public let displayName = "Hide Built-in Web Player Bar"

    public init() {}

    public func styleInjections() -> [WebStyleInjection] {
        [
            WebStyleInjection(
                identifier: "ytm-desktop-hide-web-player-bar",
                css: Self.stylesheet,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true,
                allowedHosts: ["music.youtube.com"]
            )
        ]
    }

    private static let stylesheet = """
    ytmusic-app,
    ytmusic-app-layout,
    :root {
      --ytmusic-player-bar-height: 0px !important;
    }

    ytmusic-player-bar,
    #player-bar-background.ytmusic-app-layout {
      visibility: hidden !important;
      opacity: 0 !important;
      pointer-events: none !important;
      height: 0px !important;
      min-height: 0px !important;
      max-height: 0px !important;
      overflow: hidden !important;
      border: none !important;
      margin: 0 !important;
      padding: 0 !important;
    }

    ytmusic-app-layout > #content {
      padding-bottom: 16px !important;
    }
    """
}
