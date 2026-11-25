import AppKit
import WebKit

/// Thin `WKWebView` subclass providing native macOS dark backdrop defaults
/// and clean extensibility without leaking WebKit internals to higher layers.
@MainActor
public final class YouTubeMusicWebView: WKWebView {
    public override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        configureDefaults()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func configureDefaults() {
        allowsBackForwardNavigationGestures = true
        allowsMagnification = false
        underPageBackgroundColor = NSColor(srgbRed: 3.0 / 255.0, green: 3.0 / 255.0, blue: 3.0 / 255.0, alpha: 1.0)
        #if DEBUG
        isInspectable = true
        #endif
    }
}
