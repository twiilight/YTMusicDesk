import CoreDomain
import WebKit

/// Breaks the strong retain cycle caused by `WKUserContentController.add(_:name:)`.
@MainActor
final class WeakScriptMessageProxy: NSObject, WKScriptMessageHandler {
    private weak var target: (any WKScriptMessageHandler)?

    init(target: any WKScriptMessageHandler) {
        self.target = target
        super.init()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}

/// Constructs configured `YouTubeMusicWebView` instances from domain configuration
/// and compiled `WebScriptInjection` payloads.
@MainActor
public enum WebEngineFactory {
    public static func makeWebView(
        configuration: AppConfiguration,
        injections: [WebScriptInjection],
        messageHandler: (any WKScriptMessageHandler)? = nil
    ) -> YouTubeMusicWebView {
        let webConfig = WKWebViewConfiguration()
        webConfig.websiteDataStore = .default()
        webConfig.mediaTypesRequiringUserActionForPlayback = []
        webConfig.preferences.isElementFullscreenEnabled = true
        webConfig.defaultWebpagePreferences.allowsContentJavaScript = true

        let contentController = WKUserContentController()
        if let messageHandler {
            contentController.add(
                WeakScriptMessageProxy(target: messageHandler),
                name: WebBridgeContract.messageHandlerName
            )
        }

        for injection in injections {
            let timing: WKUserScriptInjectionTime = switch injection.injectionTime {
            case .atDocumentStart: .atDocumentStart
            case .atDocumentEnd: .atDocumentEnd
            }
            let script = WKUserScript(
                source: injection.source,
                injectionTime: timing,
                forMainFrameOnly: injection.forMainFrameOnly
            )
            contentController.addUserScript(script)
        }
        webConfig.userContentController = contentController

        let webView = YouTubeMusicWebView(frame: .zero, configuration: webConfig)
        webView.customUserAgent = configuration.userAgent
        return webView
    }
}
