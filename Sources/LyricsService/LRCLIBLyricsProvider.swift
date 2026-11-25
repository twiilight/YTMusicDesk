import CoreDomain
import Foundation

/// Fetches synced/plain lyrics from the open, keyless LRCLIB API with automatic
/// query normalization, fuzzy search fallback, and optional YouTube Music page text fallback.
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

        // 1. Fast exact lookup via /api/get
        if let exact = await fetchExact(query: query),
           let doc = convertRecord(exact, source: "LRCLIB")
        {
            return doc
        }

        // 2. Fuzzy search fallback via /api/search with duration & synced-lyrics scoring
        if let best = await fetchBestSearchCandidate(query: query),
           let doc = convertRecord(best, source: "LRCLIB")
        {
            return doc
        }

        // 3. Fallback to plain lyrics scraped from YouTube Music page if available
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
           let best = pickBestCandidate(from: candidates, query: query)
        {
            return best
        }

        // Broader q= fallback when artist formatting differs (e.g. localized artist name)
        var broadComponents = URLComponents(url: baseURL.appendingPathComponent("api/search"), resolvingAgainstBaseURL: false)
        let combined = [query.title, query.artist].filter { !$0.isEmpty }.joined(separator: " ")
        broadComponents?.queryItems = [URLQueryItem(name: "q", value: combined)]

        guard let broadURL = broadComponents?.url,
              let broadCandidates = await performRequest(url: broadURL, as: [LRCLIBRecord].self)
        else {
            return nil
        }

        return pickBestCandidate(from: broadCandidates, query: query)
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

    // MARK: - Candidate Scoring

    private func pickBestCandidate(
        from candidates: [LRCLIBRecord],
        query: TrackQueryNormalizer.NormalizedQuery
    ) -> LRCLIBRecord? {
        guard !candidates.isEmpty else { return nil }

        let targetTitle = query.title.lowercased()
        let targetArtist = query.artist.lowercased()

        let scored: [(record: LRCLIBRecord, score: Double)] = candidates.compactMap { candidate in
            let hasSynced = !(candidate.syncedLyrics?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            let hasPlain = !(candidate.plainLyrics?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            let isInstrumental = candidate.instrumental ?? false
            guard hasSynced || hasPlain || isInstrumental else { return nil }

            var score: Double = 0
            if hasSynced { score += 50 }
            else if hasPlain { score += 15 }
            else if isInstrumental { score += 10 }

            let candTitle = (candidate.trackName ?? "").lowercased()
            if candTitle == targetTitle {
                score += 35
            } else if candTitle.contains(targetTitle) || targetTitle.contains(candTitle) {
                score += 18
            }

            let candArtist = (candidate.artistName ?? "").lowercased()
            if !targetArtist.isEmpty {
                if candArtist == targetArtist {
                    score += 25
                } else if candArtist.contains(targetArtist) || targetArtist.contains(candArtist) {
                    score += 14
                }
            }

            if let targetDuration = query.duration, let candDuration = candidate.duration {
                let diff = abs(Double(targetDuration) - candDuration)
                if diff <= 3 {
                    score += 25
                } else if diff <= 8 {
                    score += 14
                } else if diff <= 15 {
                    score += 5
                } else if diff > 35 {
                    score -= 30
                }
            }

            return (candidate, score)
        }

        return scored.max(by: { $0.score < $1.score })?.record
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

private struct LRCLIBRecord: Decodable {
    let trackName: String?
    let artistName: String?
    let albumName: String?
    let duration: Double?
    let instrumental: Bool?
    let plainLyrics: String?
    let syncedLyrics: String?
}
