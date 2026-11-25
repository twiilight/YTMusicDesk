import CoreDomain
import CryptoKit
import Foundation

/// Actor-isolated decorator adding fast in-memory + disk caching in front of any `LyricsProviding`.
public actor CachedLyricsProvider: LyricsProviding {
    private let upstream: any LyricsProviding
    private let cacheDirectory: URL
    private var memoryCache: [String: LyricsDocument] = [:]

    public init(
        upstream: any LyricsProviding = LRCLIBLyricsProvider(),
        bundleIdentifier: String = AppConfiguration.standard.bundleIdentifier
    ) {
        self.upstream = upstream
        let baseCache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        self.cacheDirectory = baseCache
            .appendingPathComponent(bundleIdentifier, isDirectory: true)
            .appendingPathComponent("LyricsCache", isDirectory: true)
    }

    public func fetchLyrics(for track: TrackMetadata, pageFallbackText: String?) async -> LyricsDocument? {
        let key = track.identityKey

        if let hit = memoryCache[key] {
            return hit
        }

        if let diskHit = loadFromDisk(key: key) {
            memoryCache[key] = diskHit
            return diskHit
        }

        let resolved = await upstream.fetchLyrics(for: track, pageFallbackText: pageFallbackText)
        if let resolved {
            memoryCache[key] = resolved
            saveToDisk(resolved, key: key)
        }
        return resolved
    }

    public func invalidateCache(for track: TrackMetadata) {
        let key = track.identityKey
        memoryCache.removeValue(forKey: key)
        let url = cacheFileURL(for: key)
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Disk Persistence

    private func loadFromDisk(key: String) -> LyricsDocument? {
        let url = cacheFileURL(for: key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(LyricsDocument.self, from: data)
    }

    private func saveToDisk(_ document: LyricsDocument, key: String) {
        do {
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(document)
            try data.write(to: cacheFileURL(for: key), options: .atomic)
        } catch {
            // Caching failure is non-fatal; lyrics remain available in memory.
        }
    }

    private func cacheFileURL(for key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8))
        let filename = digest.map { String(format: "%02x", $0) }.joined()
        return cacheDirectory.appendingPathComponent("\(filename).json")
    }
}
