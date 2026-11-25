import CoreDomain

/// Composes and resolves pluggable `WebEnhancement` modules in deterministic registration order.
public struct EnhancementRegistry: Sendable {
    public let enhancements: [any WebEnhancement]
    public let disabledIDs: Set<String>

    public init(
        enhancements: [any WebEnhancement],
        disabledIDs: Set<String> = []
    ) {
        self.enhancements = enhancements
        self.disabledIDs = disabledIDs
    }

    /// Enhancements currently active given default enablement and explicit overrides.
    public var activeEnhancements: [any WebEnhancement] {
        enhancements.filter { enhancement in
            enhancement.isEnabledByDefault && !disabledIDs.contains(enhancement.id)
        }
    }

    /// Flattened script injections ready to be installed into `WKUserContentController`.
    public func compiledInjections() -> [WebScriptInjection] {
        activeEnhancements.flatMap { $0.compiledInjections() }
    }

    /// Default enhancement set combining macOS visual polish, hidden web player bar,
    /// and the bidirectional native playback bridge.
    public static func defaultRegistry(disabledIDs: Set<String> = []) -> EnhancementRegistry {
        EnhancementRegistry(
            enhancements: [
                MacOSChromeRefinement(),
                ViewportErgonomicsRefinement(),
                HideWebPlayerBarEnhancement(),
                PlaybackBridgeEnhancement()
            ],
            disabledIDs: disabledIDs
        )
    }
}
