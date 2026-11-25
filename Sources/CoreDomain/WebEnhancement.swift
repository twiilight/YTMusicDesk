import Foundation

/// Lifecycle phase at which a script or stylesheet should be injected into the page.
public enum ScriptInjectionTime: Sendable, Equatable {
    case atDocumentStart
    case atDocumentEnd
}

/// Pure, WebKit-independent descriptor of a JavaScript snippet to inject.
public struct WebScriptInjection: Sendable, Equatable {
    public let source: String
    public let injectionTime: ScriptInjectionTime
    public let forMainFrameOnly: Bool

    public init(
        source: String,
        injectionTime: ScriptInjectionTime = .atDocumentEnd,
        forMainFrameOnly: Bool = true
    ) {
        self.source = source
        self.injectionTime = injectionTime
        self.forMainFrameOnly = forMainFrameOnly
    }
}

/// Pure, WebKit-independent descriptor of a CSS stylesheet to inject idempotently.
public struct WebStyleInjection: Sendable, Equatable {
    public let identifier: String
    public let css: String
    public let injectionTime: ScriptInjectionTime
    public let forMainFrameOnly: Bool
    /// Optional host allowlist (e.g. `["music.youtube.com"]`). `nil` applies to all hosts.
    public let allowedHosts: Set<String>?

    public init(
        identifier: String,
        css: String,
        injectionTime: ScriptInjectionTime = .atDocumentStart,
        forMainFrameOnly: Bool = true,
        allowedHosts: Set<String>? = nil
    ) {
        self.identifier = identifier
        self.css = css
        self.injectionTime = injectionTime
        self.forMainFrameOnly = forMainFrameOnly
        self.allowedHosts = allowedHosts.map { Set($0.map { $0.lowercased() }) }
    }

    /// Compiles the CSS into an idempotent, flash-free JavaScript DOM injector.
    public func asJavaScriptInjection() -> WebScriptInjection {
        let escapedID = Self.jsStringLiteral(identifier)
        let escapedCSS = Self.jsStringLiteral(css)
        let hostGuard: String
        if let allowedHosts, !allowedHosts.isEmpty {
            let sorted = allowedHosts.sorted()
            let jsonArray = Self.jsStringArrayLiteral(sorted)
            hostGuard = """
              const allowedHosts = \(jsonArray);
              const host = (window.location && window.location.hostname || '').toLowerCase();
              if (!allowedHosts.includes(host)) { return; }
            """
        } else {
            hostGuard = ""
        }

        let js = """
        (function() {
        \(hostGuard)
          const styleId = \(escapedID);
          const cssText = \(escapedCSS);

          function upsertStyle() {
            const target = document.head || document.documentElement;
            if (!target) {
              return false;
            }
            let styleEl = document.getElementById(styleId);
            if (!styleEl) {
              styleEl = document.createElement('style');
              styleEl.id = styleId;
              styleEl.setAttribute('data-ytm-desktop', 'true');
              target.appendChild(styleEl);
            }
            if (styleEl.textContent !== cssText) {
              styleEl.textContent = cssText;
            }
            return true;
          }

          if (!upsertStyle()) {
            document.addEventListener('DOMContentLoaded', upsertStyle, { once: true });
          }
        })();
        """

        return WebScriptInjection(
            source: js,
            injectionTime: injectionTime,
            forMainFrameOnly: forMainFrameOnly
        )
    }

    private static func jsStringLiteral(_ raw: String) -> String {
        guard
            let data = try? JSONSerialization.data(withJSONObject: [raw], options: []),
            let arrayString = String(data: data, encoding: .utf8),
            arrayString.count >= 2
        else {
            return "\"\""
        }
        return String(arrayString.dropFirst().dropLast())
    }

    private static func jsStringArrayLiteral(_ values: [String]) -> String {
        guard
            let data = try? JSONSerialization.data(withJSONObject: values, options: []),
            let arrayString = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return arrayString
    }
}

/// Extension point for self-contained visual or behavioral enhancements.
/// Future capabilities (e.g., themes, media bridges, shortcuts) conform to this protocol
/// without modifying the web engine or application shell.
public protocol WebEnhancement: Sendable {
    var id: String { get }
    var displayName: String { get }
    var isEnabledByDefault: Bool { get }

    func styleInjections() -> [WebStyleInjection]
    func scriptInjections() -> [WebScriptInjection]
}

public extension WebEnhancement {
    var isEnabledByDefault: Bool { true }

    func styleInjections() -> [WebStyleInjection] { [] }
    func scriptInjections() -> [WebScriptInjection] { [] }

    func compiledInjections() -> [WebScriptInjection] {
        styleInjections().map { $0.asJavaScriptInjection() } + scriptInjections()
    }
}
