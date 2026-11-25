import Foundation

/// Structured representation of a recoverable web loading error.
public struct LoadFailure: Sendable, Equatable {
    public let title: String
    public let message: String
    public let failingURL: URL?
    public let isOffline: Bool

    public init(title: String, message: String, failingURL: URL?, isOffline: Bool) {
        self.title = title
        self.message = message
        self.failingURL = failingURL
        self.isOffline = isOffline
    }
}

/// Immutable snapshot of the active YouTube Music web session state observed by UI chrome.
public struct WebPageState: Sendable, Equatable {
    public var currentURL: URL?
    public var rawTitle: String
    public var isLoading: Bool
    public var estimatedProgress: Double
    public var hasCompletedInitialLoad: Bool
    public var canGoBack: Bool
    public var canGoForward: Bool
    public var pageZoom: Double
    public var loadFailure: LoadFailure?

    public init(
        currentURL: URL? = nil,
        rawTitle: String = "",
        isLoading: Bool = true,
        estimatedProgress: Double = 0.0,
        hasCompletedInitialLoad: Bool = false,
        canGoBack: Bool = false,
        canGoForward: Bool = false,
        pageZoom: Double = 1.0,
        loadFailure: LoadFailure? = nil
    ) {
        self.currentURL = currentURL
        self.rawTitle = rawTitle
        self.isLoading = isLoading
        self.estimatedProgress = estimatedProgress
        self.hasCompletedInitialLoad = hasCompletedInitialLoad
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.pageZoom = pageZoom
        self.loadFailure = loadFailure
    }

    /// Clean title suitable for display in the integrated macOS titlebar.
    public var displayTitle: String {
        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "YouTube Music" else {
            return "YTMusicDesk"
        }

        let suffix = " - YouTube Music"
        if trimmed.hasSuffix(suffix) {
            let stripped = String(trimmed.dropLast(suffix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !stripped.isEmpty {
                return stripped
            }
        }

        return trimmed
    }

    /// Whether the launch splash screen should still mask initial page bootstrap.
    public var showsLaunchSplash: Bool {
        !hasCompletedInitialLoad && loadFailure == nil
    }
}
