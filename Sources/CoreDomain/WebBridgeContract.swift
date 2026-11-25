import Foundation

/// Shared contract constants connecting `WebEnhancements` and `WebEngine` through `CoreDomain`
/// without creating a direct dependency between them.
public enum WebBridgeContract {
    public static let messageHandlerName = "ytmDesktopBridge"
    public static let jsNamespace = "__ytmDesktop"
}
