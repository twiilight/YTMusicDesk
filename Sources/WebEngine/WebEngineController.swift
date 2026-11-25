import AppKit
import CoreDomain
import Observation
import SwiftUI
import WebKit

/// Coordinates the `WKWebView` lifecycle, navigation policy enforcement, OAuth popups,
/// reactive `WebPageState`, and bidirectional `PlaybackControlling` bridge.
@MainActor
@Observable
public final class WebEngineController: NSObject, BrowserControlling, PlaybackControlling {
    public private(set) var state = WebPageState()
    public private(set) var playbackState = PlaybackState()

    public let configuration: AppConfiguration
    public let navigationPolicy: NavigationPolicy

    /// Invoked whenever a decoded playback snapshot arrives from the web bridge,
    /// allowing higher layers to react independently of SwiftUI view lifecycles.
    @ObservationIgnored
    public var onPlaybackStateChanged: (@MainActor (PlaybackState) -> Void)?

    let webView: YouTubeMusicWebView

    @ObservationIgnored
    private var observations: [NSKeyValueObservation] = []

    @ObservationIgnored
    private var authPopups: [AuthPopupWindowController] = []

    @ObservationIgnored
    private var bridgeReceiver: BridgeMessageReceiver?

    public init(
        configuration: AppConfiguration = .standard,
        navigationPolicy: NavigationPolicy = NavigationPolicy(),
        injections: [WebScriptInjection] = []
    ) {
        self.configuration = configuration
        self.navigationPolicy = navigationPolicy

        let receiver = BridgeMessageReceiver()
        self.bridgeReceiver = receiver
        self.webView = WebEngineFactory.makeWebView(
            configuration: configuration,
            injections: injections,
            messageHandler: receiver
        )
        super.init()

        receiver.onMessage = { [weak self] payload in
            self?.handleBridgePayload(payload)
        }

        webView.navigationDelegate = self
        webView.uiDelegate = self
        installObservers()
    }

    deinit {
        observations.forEach { $0.invalidate() }
    }

    // MARK: - BrowserControlling

    public func loadHome() {
        load(url: configuration.homeURL)
    }

    public func load(url: URL) {
        state.loadFailure = nil
        let request = URLRequest(
            url: url,
            cachePolicy: .useProtocolCachePolicy,
            timeoutInterval: 30
        )
        webView.load(request)
    }

    public func reload() {
        state.loadFailure = nil
        if webView.url != nil {
            webView.reload()
        } else {
            loadHome()
        }
    }

    public func goBack() {
        if webView.canGoBack {
            webView.goBack()
        }
    }

    public func goForward() {
        if webView.canGoForward {
            webView.goForward()
        }
    }

    public func zoomIn() {
        applyZoom(state.pageZoom + configuration.zoomStep)
    }

    public func zoomOut() {
        applyZoom(state.pageZoom - configuration.zoomStep)
    }

    public func resetZoom() {
        applyZoom(1.0)
    }

    @discardableResult
    public func copyCurrentURLToPasteboard() -> Bool {
        let targetURL = webView.url ?? state.currentURL ?? configuration.homeURL
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(targetURL.absoluteString, forType: .string)
    }

    public func openCurrentURLInExternalBrowser() {
        let targetURL = webView.url ?? state.currentURL ?? configuration.homeURL
        NSWorkspace.shared.open(targetURL)
    }

    // MARK: - PlaybackControlling

    public func send(_ command: PlaybackCommand) {
        let encoded = PlaybackBridgeCodec.encode(command: command, currentState: playbackState)
        playbackState = encoded.optimisticState
        webView.evaluateJavaScript(encoded.javascript, completionHandler: nil)
    }

    // MARK: - Private Helpers

    private func handleBridgePayload(_ body: Any) {
        guard let nextState = PlaybackBridgeCodec.decodePlaybackState(
            from: body,
            previous: playbackState
        ) else {
            return
        }
        playbackState = nextState
        onPlaybackStateChanged?(nextState)
    }

    private func applyZoom(_ proposed: Double) {
        let clamped = min(max(proposed, configuration.minZoom), configuration.maxZoom)
        let rounded = (clamped * 100).rounded() / 100
        webView.pageZoom = rounded
        state.pageZoom = rounded
    }

    private func installObservers() {
        observations = [
            webView.observe(\.title, options: [.new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.syncFromWebView() }
            },
            webView.observe(\.url, options: [.new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.syncFromWebView() }
            },
            webView.observe(\.isLoading, options: [.new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.syncFromWebView() }
            },
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.syncFromWebView() }
            },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.syncFromWebView() }
            },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.syncFromWebView() }
            }
        ]
    }

    private func syncFromWebView() {
        state.rawTitle = webView.title ?? ""
        state.currentURL = webView.url
        state.isLoading = webView.isLoading
        state.estimatedProgress = webView.estimatedProgress
        state.canGoBack = webView.canGoBack
        state.canGoForward = webView.canGoForward
    }

    private func handleNavigationError(_ error: Error) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return }
        if nsError.domain == "WebKitErrorDomain" && nsError.code == 102 { return }

        let isOffline = nsError.domain == NSURLErrorDomain && (
            nsError.code == NSURLErrorNotConnectedToInternet ||
            nsError.code == NSURLErrorNetworkConnectionLost ||
            nsError.code == NSURLErrorCannotFindHost ||
            nsError.code == NSURLErrorCannotConnectToHost ||
            nsError.code == NSURLErrorTimedOut
        )

        let failingURL = nsError.userInfo[NSURLErrorFailingURLErrorKey] as? URL
            ?? state.currentURL
            ?? configuration.homeURL

        let prefersChinese = Locale.preferredLanguages.first?.hasPrefix("zh") ?? false
        let title: String
        let message: String
        if isOffline {
            title = prefersChinese ? "无法连接到 YouTube Music" : "Unable to Reach YouTube Music"
            message = prefersChinese
                ? "请检查你的网络连接或代理设置，然后重试。"
                : "Check your internet connection or proxy settings and try again."
        } else {
            title = prefersChinese ? "页面加载失败" : "Page Failed to Load"
            message = nsError.localizedDescription
        }

        state.loadFailure = LoadFailure(
            title: title,
            message: message,
            failingURL: failingURL,
            isOffline: isOffline
        )
    }

    private func openAuthPopup(with configuration: WKWebViewConfiguration) -> WKWebView {
        let popup = AuthPopupWindowController(
            configuration: configuration,
            userAgent: self.configuration.userAgent,
            parentWindow: webView.window
        ) { [weak self] closedController in
            self?.authPopups.removeAll { $0 === closedController }
        }
        authPopups.append(popup)
        popup.present()
        return popup.webView
    }
}

// MARK: - Internal Bridge Receiver

@MainActor
private final class BridgeMessageReceiver: NSObject, WKScriptMessageHandler {
    var onMessage: ((Any) -> Void)?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == WebBridgeContract.messageHandlerName else { return }
        onMessage?(message.body)
    }
}

// MARK: - WKNavigationDelegate

extension WebEngineController: WKNavigationDelegate {
    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
        let isNewWindow = navigationAction.targetFrame == nil
        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
        let request = NavigationRequest(
            url: navigationAction.request.url,
            isMainFrame: isMainFrame,
            isNewWindowRequest: isNewWindow
        )

        switch navigationPolicy.decide(for: request) {
        case .allowInMainView:
            if isNewWindow {
                webView.load(navigationAction.request)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }

        case .openInAuthPopup:
            decisionHandler(.allow)

        case .openInExternalBrowser:
            if let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
            }
            decisionHandler(.cancel)

        case .cancel:
            decisionHandler(.cancel)
        }
    }

    public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        state.loadFailure = nil
        syncFromWebView()
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        state.loadFailure = nil
        state.hasCompletedInitialLoad = true
        syncFromWebView()
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        syncFromWebView()
        handleNavigationError(error)
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        syncFromWebView()
        handleNavigationError(error)
    }

    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        reload()
    }
}

// MARK: - WKUIDelegate

extension WebEngineController: WKUIDelegate {
    public func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        let request = NavigationRequest(
            url: navigationAction.request.url,
            isMainFrame: true,
            isNewWindowRequest: true
        )

        switch navigationPolicy.decide(for: request) {
        case .openInAuthPopup:
            return openAuthPopup(with: configuration)

        case .allowInMainView:
            webView.load(navigationAction.request)
            return nil

        case .openInExternalBrowser:
            if let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
            }
            return nil

        case .cancel:
            return nil
        }
    }

    public func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping @MainActor () -> Void
    ) {
        WebDialogPresenter.presentAlert(
            title: configuration.appName,
            message: message,
            window: webView.window,
            completion: completionHandler
        )
    }

    public func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping @MainActor (Bool) -> Void
    ) {
        WebDialogPresenter.presentConfirm(
            title: configuration.appName,
            message: message,
            window: webView.window,
            completion: completionHandler
        )
    }

    public func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping @MainActor (String?) -> Void
    ) {
        WebDialogPresenter.presentPrompt(
            title: configuration.appName,
            prompt: prompt,
            defaultText: defaultText,
            window: webView.window,
            completion: completionHandler
        )
    }
}

// MARK: - SwiftUI Bridge

/// Encapsulated SwiftUI container that hosts `WebEngineController`'s underlying `WKWebView`.
public struct WebViewSurface: NSViewRepresentable {
    private let controller: WebEngineController

    public init(controller: WebEngineController) {
        self.controller = controller
    }

    public func makeNSView(context: Context) -> YouTubeMusicWebView {
        controller.webView
    }

    public func updateNSView(_ nsView: YouTubeMusicWebView, context: Context) {}
}
