import Foundation

/// Decouples UI chrome, menus, and lifecycle controllers from the underlying WebKit engine.
@MainActor
public protocol BrowserControlling: AnyObject {
    var state: WebPageState { get }

    func loadHome()
    func load(url: URL)
    func reload()
    func goBack()
    func goForward()
    func zoomIn()
    func zoomOut()
    func resetZoom()
    @discardableResult
    func copyCurrentURLToPasteboard() -> Bool
    func openCurrentURLInExternalBrowser()
}
