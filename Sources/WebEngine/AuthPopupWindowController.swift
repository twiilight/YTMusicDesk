import AppKit
import CoreDomain
import WebKit

/// Presents an isolated, session-sharing native macOS window for Google Sign-In / OAuth popups.
/// Automatically dismisses when the OAuth flow invokes `window.close()`.
@MainActor
final class AuthPopupWindowController: NSWindowController, NSWindowDelegate, WKUIDelegate, WKNavigationDelegate {
    let webView: WKWebView
    private let onClose: (AuthPopupWindowController) -> Void
    private var titleObservation: NSKeyValueObservation?
    private var hasNotifiedClose = false

    init(
        configuration: WKWebViewConfiguration,
        userAgent: String,
        parentWindow: NSWindow?,
        onClose: @escaping (AuthPopupWindowController) -> Void
    ) {
        self.onClose = onClose

        let popupWebView = WKWebView(frame: NSRect(x: 0, y: 0, width: 500, height: 660), configuration: configuration)
        popupWebView.customUserAgent = userAgent
        self.webView = popupWebView

        let popupWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 660),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        popupWindow.title = "Google Sign-In"
        popupWindow.isReleasedWhenClosed = false
        popupWindow.contentView = popupWebView
        popupWindow.minSize = NSSize(width: 400, height: 500)

        if let parentWindow {
            let parentFrame = parentWindow.frame
            let originX = parentFrame.midX - popupWindow.frame.width / 2
            let originY = parentFrame.midY - popupWindow.frame.height / 2
            popupWindow.setFrameOrigin(NSPoint(x: originX, y: originY))
        } else {
            popupWindow.center()
        }

        super.init(window: popupWindow)

        popupWindow.delegate = self
        popupWebView.uiDelegate = self
        popupWebView.navigationDelegate = self

        titleObservation = popupWebView.observe(\.title, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self, let nextTitle = self.webView.title, !nextTitle.isEmpty else { return }
                self.window?.title = nextTitle
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func present() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - WKUIDelegate

    func webViewDidClose(_ webView: WKWebView) {
        window?.close()
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        titleObservation?.invalidate()
        titleObservation = nil
        webView.uiDelegate = nil
        webView.navigationDelegate = nil
        if !hasNotifiedClose {
            hasNotifiedClose = true
            onClose(self)
        }
    }
}
