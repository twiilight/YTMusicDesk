import Foundation

/// Action produced by `NavigationPolicy` for any web navigation event.
public enum NavigationDecision: Sendable, Equatable {
    /// Proceed normally inside the main YouTube Music web view.
    case allowInMainView
    /// Present in a dedicated authentication popup window sharing the same session store.
    case openInAuthPopup
    /// Hand off to the user's default macOS browser or system handler.
    case openInExternalBrowser
    /// Ignore the navigation.
    case cancel
}

/// Framework-agnostic description of a navigation attempt.
public struct NavigationRequest: Sendable, Equatable {
    public let url: URL?
    public let isMainFrame: Bool
    public let isNewWindowRequest: Bool

    public init(url: URL?, isMainFrame: Bool = true, isNewWindowRequest: Bool = false) {
        self.url = url
        self.isMainFrame = isMainFrame
        self.isNewWindowRequest = isNewWindowRequest
    }
}

/// Pure, deterministic routing policy separating YouTube Music content,
/// Google sign-in / consent flows, and external links.
public struct NavigationPolicy: Sendable, Equatable {
    public let primaryHost: String

    private static let authExactHosts: Set<String> = [
        "accounts.google.com",
        "accounts.youtube.com",
        "myaccount.google.com",
        "oauth2.googleapis.com",
        "gds.google.com",
        "families.google.com",
        "consent.youtube.com",
        "consent.google.com"
    ]

    private static let authHostPrefixes: [String] = [
        "accounts.google.",
        "consent.google.",
        "consent.youtube."
    ]

    private static let youtubeMainHosts: Set<String> = [
        "www.youtube.com",
        "youtube.com",
        "m.youtube.com"
    ]

    private static let youtubeAuthPathPrefixes: [String] = [
        "/signin",
        "/signout",
        "/logout",
        "/channel_switcher",
        "/create_channel",
        "/account",
        "/paid_memberships",
        "/musicpremium",
        "/premium",
        "/reauth",
        "/verify",
        "/check_cookie",
        "/set_cookie"
    ]

    public init(primaryHost: String = "music.youtube.com") {
        self.primaryHost = primaryHost.lowercased()
    }

    public func decide(for request: NavigationRequest) -> NavigationDecision {
        // Never interfere with subframes (silent Google session checks, player embeds, etc.).
        if !request.isMainFrame {
            return .allowInMainView
        }

        guard let url = request.url else {
            return request.isNewWindowRequest ? .openInAuthPopup : .cancel
        }

        guard let scheme = url.scheme?.lowercased() else {
            return request.isNewWindowRequest ? .openInAuthPopup : .cancel
        }

        if scheme == "about" || scheme == "blob" || scheme == "data" {
            return request.isNewWindowRequest ? .openInAuthPopup : .allowInMainView
        }

        guard scheme == "https" || scheme == "http" else {
            return .openInExternalBrowser
        }

        guard let host = url.host?.lowercased(), !host.isEmpty else {
            return .cancel
        }

        // Primary YouTube Music surface stays cleanly inside the single main window.
        if host == primaryHost {
            return .allowInMainView
        }

        // Google authentication, 2FA, passkey, and consent surfaces.
        if isAuthHost(host) {
            return request.isNewWindowRequest ? .openInAuthPopup : .allowInMainView
        }

        // Account/session bounce endpoints on www.youtube.com stay inside the app;
        // unrelated video or help links escape cleanly to the user's browser.
        if Self.youtubeMainHosts.contains(host), isYouTubeSessionURL(url) {
            return request.isNewWindowRequest ? .openInAuthPopup : .allowInMainView
        }

        return .openInExternalBrowser
    }

    private func isAuthHost(_ host: String) -> Bool {
        if Self.authExactHosts.contains(host) {
            return true
        }
        return Self.authHostPrefixes.contains { host.hasPrefix($0) }
    }

    private func isYouTubeSessionURL(_ url: URL) -> Bool {
        let path = url.path.lowercased()
        if Self.youtubeAuthPathPrefixes.contains(where: { path.hasPrefix($0) }) {
            return true
        }
        if let query = url.query?.lowercased(), query.contains(primaryHost) {
            return true
        }
        return false
    }
}
