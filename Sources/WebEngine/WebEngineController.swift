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
        let ns = WebBridgeContract.jsNamespace
        let script: String

        switch command {
        case .togglePlayPause:
            playbackState.isPlaying.toggle()
            playbackState.sampledUptime = ProcessInfo.processInfo.systemUptime
            script = "window.\(ns) && window.\(ns).dispatch('togglePlayPause');"

        case .nextTrack:
            script = "window.\(ns) && window.\(ns).dispatch('nextTrack');"

        case .previousTrack:
            script = "window.\(ns) && window.\(ns).dispatch('previousTrack');"

        case .seek(let seconds):
            let clamped = min(max(seconds, 0), max(playbackState.duration, 0))
            playbackState.currentTime = clamped
            playbackState.sampledUptime = ProcessInfo.processInfo.systemUptime
            script = "window.\(ns) && window.\(ns).dispatch('seek', \(clamped));"

        case .setVolume(let volume):
            let clamped = min(max(volume, 0), 1)
            playbackState.volume = clamped
            if clamped > 0 { playbackState.isMuted = false }
            script = "window.\(ns) && window.\(ns).dispatch('setVolume', \(clamped));"

        case .toggleMute:
            playbackState.isMuted.toggle()
            script = "window.\(ns) && window.\(ns).dispatch('toggleMute');"

        case .toggleLike:
            playbackState.likeStatus = playbackState.likeStatus == .like ? .indifferent : .like
            script = "window.\(ns) && window.\(ns).dispatch('toggleLike');"

        case .toggleShuffle:
            playbackState.isShuffled.toggle()
            script = "window.\(ns) && window.\(ns).dispatch('toggleShuffle');"

        case .cycleRepeat:
            script = "window.\(ns) && window.\(ns).dispatch('cycleRepeat');"
        }

        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    // MARK: - Bridge Message Decoding

    private func handleBridgePayload(_ body: Any) {
        guard let dict = body as? [String: Any],
              let type = dict["type"] as? String,
              type == "playbackState"
        else {
            return
        }

        let title = (dict["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let artist = (dict["artist"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let album = (dict["album"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let artworkURLString = dict["artworkURL"] as? String
        let artworkURL = artworkURLString.flatMap { URL(string: $0) }
        let videoID = dict["videoID"] as? String

        let isPlaying = dict["isPlaying"] as? Bool ?? false
        let currentTime = (dict["currentTime"] as? NSNumber)?.doubleValue ?? 0
        let duration = (dict["duration"] as? NSNumber)?.doubleValue ?? 0
        let volume = (dict["volume"] as? NSNumber)?.doubleValue ?? playbackState.volume
        let isMuted = dict["isMuted"] as? Bool ?? false
        let isShuffled = dict["isShuffled"] as? Bool ?? false
        let repeatRaw = dict["repeatMode"] as? String ?? "off"
        let repeatMode = RepeatMode(rawValue: repeatRaw) ?? .off
        let likeRaw = dict["likeStatus"] as? String ?? "indifferent"
        let likeStatus = LikeStatus(rawValue: likeRaw) ?? .indifferent
        let hasPrevious = dict["hasPrevious"] as? Bool ?? false
        let hasNext = dict["hasNext"] as? Bool ?? false
        let pageLyricsText = dict["pageLyricsText"] as? String

        let track: TrackMetadata? = title.isEmpty
            ? playbackState.track
            : TrackMetadata(
                title: title,
                artist: artist,
                album: album,
                artworkURL: artworkURL ?? playbackState.track?.artworkURL,
                videoID: videoID,
                duration: duration > 0 ? duration : (playbackState.track?.duration ?? 0)
            )

        playbackState = PlaybackState(
            track: track,
            isPlaying: isPlaying,
            currentTime: max(0, currentTime),
            duration: max(0, duration),
            volume: min(max(volume, 0), 1),
            isMuted: isMuted,
            isShuffled: isShuffled,
            repeatMode: repeatMode,
            likeStatus: likeStatus,
            hasPrevious: hasPrevious,
            hasNext: hasNext,
            pageLyricsText: pageLyricsText,
            sampledUptime: ProcessInfo.processInfo.systemUptime
        )
    }

    // MARK: - Private Helpers

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

        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return
        }
        if nsError.domain == "WebKitErrorDomain" && nsError.code == 102 {
            return
        }

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

        let decision = navigationPolicy.decide(for: request)

        switch decision {
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
        let alert = NSAlert()
        alert.messageText = configuration.appName
        alert.informativeText = message
        alert.alertStyle = .informational
        if let window = webView.window {
            alert.beginSheetModal(for: window) { _ in completionHandler() }
        } else {
            alert.runModal()
            completionHandler()
        }
    }

    public func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping @MainActor (Bool) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = configuration.appName
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        if let window = webView.window {
            alert.beginSheetModal(for: window) { response in
                completionHandler(response == .alertFirstButtonReturn)
            }
        } else {
            completionHandler(alert.runModal() == .alertFirstButtonReturn)
        }
    }

    public func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping @MainActor (String?) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = configuration.appName
        alert.informativeText = prompt
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        textField.stringValue = defaultText ?? ""
        alert.accessoryView = textField

        if let window = webView.window {
            alert.beginSheetModal(for: window) { response in
                completionHandler(response == .alertFirstButtonReturn ? textField.stringValue : nil)
            }
        } else {
            let response = alert.runModal()
            completionHandler(response == .alertFirstButtonReturn ? textField.stringValue : nil)
        }
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
