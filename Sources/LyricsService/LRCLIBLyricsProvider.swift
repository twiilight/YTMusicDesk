import CoreDomain
import Foundation

/// HTTP client querying the open, keyless LRCLIB API with query normalization,
/// strict validation via `LRCLIBCandidateMatcher`, and YouTube Music page text fallback.
public struct LRCLIBLyricsProvider: LyricsProviding {
    private let session: URLSession
    private let baseURL: URL

    public init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://lrclib.net")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    public func fetchLyrics(for track: TrackMetadata, pageFallbackText: String?) async -> LyricsDocument? {
        let query = TrackQueryNormalizer.normalize(track)
        guard !query.title.isEmpty else {
            return makePageFallbackDocument(pageFallbackText)
        }

        // 1. Fast exact lookup via /api/get (still validated against duration & title sanity)
        if let exact = await fetchExact(query: query),
           LRCLIBCandidateMatcher.isAcceptable(exact, for: query),
           let doc = convertRecord(exact, source: "LRCLIB")
        {
            return doc
        }

        // 2. Validated search fallback via /api/search
        if let best = await fetchBestSearchCandidate(query: query),
           let doc = convertRecord(best, source: "LRCLIB")
        {
            return doc
        }

        // 3. Fallback to plain lyrics scraped from visible YouTube Music lyrics panel if available
        return makePageFallbackDocument(pageFallbackText)
    }

    // MARK: - API Calls

    private func fetchExact(query: TrackQueryNormalizer.NormalizedQuery) async -> LRCLIBRecord? {
        guard !query.artist.isEmpty else { return nil }

        var components = URLComponents(url: baseURL.appendingPathComponent("api/get"), resolvingAgainstBaseURL: false)
        var items = [
            URLQueryItem(name: "track_name", value: query.title),
            URLQueryItem(name: "artist_name", value: query.artist)
        ]
        if !query.album.isEmpty {
            items.append(URLQueryItem(name: "album_name", value: query.album))
        }
        if let duration = query.duration {
            items.append(URLQueryItem(name: "duration", value: String(duration)))
        }
        components?.queryItems = items

        guard let url = components?.url else { return nil }
        return await performRequest(url: url, as: LRCLIBRecord.self)
    }

    private func fetchBestSearchCandidate(query: TrackQueryNormalizer.NormalizedQuery) async -> LRCLIBRecord? {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/search"), resolvingAgainstBaseURL: false)
        var items = [URLQueryItem(name: "track_name", value: query.title)]
        if !query.artist.isEmpty {
            items.append(URLQueryItem(name: "artist_name", value: query.artist))
        }
        components?.queryItems = items

        if let url = components?.url,
           let candidates = await performRequest(url: url, as: [LRCLIBRecord].self),
           let best = LRCLIBCandidateMatcher.selectBest(from: candidates, for: query)
        {
            return best
        }

        // Broader q= fallback (e.g., localized artist names) protected by strict matcher gates
        var broadComponents = URLComponents(url: baseURL.appendingPathComponent("api/search"), resolvingAgainstBaseURL: false)
        let combined = [query.title, query.artist].filter { !$0.isEmpty }.joined(separator: " ")
        broadComponents?.queryItems = [URLQueryItem(name: "q", value: combined)]

        if let broadURL = broadComponents?.url,
           let broadCandidates = await performRequest(url: broadURL, as: [LRCLIBRecord].self),
           let best = LRCLIBCandidateMatcher.selectBest(from: broadCandidates, for: query)
        {
            return best
        }

        // Title-only fallback strictly gated by exact title + ±4s duration match
        // (rescues songs where YouTube Music localizes the artist name, e.g., 周杰伦 vs Jay Chou)
        guard query.duration != nil else { return nil }
        var titleOnly = URLComponents(url: baseURL.appendingPathComponent("api/search"), resolvingAgainstBaseURL: false)
        titleOnly?.queryItems = [URLQueryItem(name: "track_name", value: query.title)]

        guard let titleURL = titleOnly?.url,
              let titleCandidates = await performRequest(url: titleURL, as: [LRCLIBRecord].self)
        else {
            return nil
        }

        return LRCLIBCandidateMatcher.selectBest(from: titleCandidates, for: query)
    }

    private func performRequest<T: Decodable>(url: URL, as type: T.Type) async -> T? {
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("YTMusicDesk/1.0 (macOS)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            return nil
        }
    }

    private func convertRecord(_ record: LRCLIBRecord, source: String) -> LyricsDocument? {
        if let syncedRaw = record.syncedLyrics, !syncedRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let lines = LRCParser.parseSynced(syncedRaw)
            if !lines.isEmpty {
                return LyricsDocument(source: source, content: .synced(lines))
            }
        }

        if record.instrumental == true {
            return LyricsDocument(source: source, content: .instrumental)
        }

        if let plainRaw = record.plainLyrics, !plainRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let lines = LRCParser.parsePlain(plainRaw)
            if !lines.isEmpty {
                return LyricsDocument(source: source, content: .plain(lines))
            }
        }

        return nil
    }

    private func makePageFallbackDocument(_ pageFallbackText: String?) -> LyricsDocument? {
        guard let pageFallbackText else { return nil }
        let lines = LRCParser.parsePlain(pageFallbackText)
        guard !lines.isEmpty else { return nil }
        return LyricsDocument(source: "YouTube Music", content: .plain(lines))
    }
}
