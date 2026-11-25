import Foundation

/// Pure value representation of window dimensions, keeping `CoreDomain` free of UI frameworks.
public struct WindowDimensions: Sendable, Equatable, Hashable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

/// Centralized, immutable runtime configuration for the application.
public struct AppConfiguration: Sendable, Equatable {
    public let appName: String
    public let bundleIdentifier: String
    public let homeURL: URL
    public let userAgent: String
    public let defaultWindowSize: WindowDimensions
    public let minimumWindowSize: WindowDimensions
    public let windowFrameAutosaveName: String
    public let hidesWindowOnClose: Bool
    public let zoomStep: Double
    public let minZoom: Double
    public let maxZoom: Double

    public init(
        appName: String = "YTMusicDesk",
        bundleIdentifier: String = "com.ytmusicdesk.app",
        homeURL: URL = URL(string: "https://music.youtube.com")!,
        userAgent: String = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15",
        defaultWindowSize: WindowDimensions = WindowDimensions(width: 1280, height: 820),
        minimumWindowSize: WindowDimensions = WindowDimensions(width: 780, height: 540),
        windowFrameAutosaveName: String = "YTMusicDeskMainWindow",
        hidesWindowOnClose: Bool = true,
        zoomStep: Double = 0.1,
        minZoom: Double = 0.7,
        maxZoom: Double = 1.6
    ) {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.homeURL = homeURL
        self.userAgent = userAgent
        self.defaultWindowSize = defaultWindowSize
        self.minimumWindowSize = minimumWindowSize
        self.windowFrameAutosaveName = windowFrameAutosaveName
        self.hidesWindowOnClose = hidesWindowOnClose
        self.zoomStep = zoomStep
        self.minZoom = minZoom
        self.maxZoom = maxZoom
    }

    public static let standard = AppConfiguration()
}
