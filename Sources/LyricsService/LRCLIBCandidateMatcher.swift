import CoreDomain
import Foundation

/// Public representation of a single LRCLIB record for transparent matching and unit testing.
public struct LRCLIBRecord: Sendable, Equatable, Decodable {
    public let trackName: String?
    public let artistName: String?
    public let albumName: String?
    public let duration: Double?
    public let instrumental: Bool?
    public let plainLyrics: String?
    public let syncedLyrics: String?

    public init(
        trackName: String? = nil,
        artistName: String? = nil,
        albumName: String? = nil,
        duration: Double? = nil,
        instrumental: Bool? = nil,
        plainLyrics: String? = nil,
        syncedLyrics: String? = nil
    ) {
        self.trackName = trackName
        self.artistName = artistName
        self.albumName = albumName
        self.duration = duration
        self.instrumental = instrumental
        self.plainLyrics = plainLyrics
        self.syncedLyrics = syncedLyrics
    }
}

/// Pure, IO-free candidate validator preventing false-positive lyrics from unrelated songs.
public enum LRCLIBCandidateMatcher {
    private enum TitleMatchTier {
        case none
        case tokenOverlap
        case strongContainment
        case exact
    }

    public static func selectBest(
        from candidates: [LRCLIBRecord],
        for query: TrackQueryNormalizer.NormalizedQuery
    ) -> LRCLIBRecord? {
        candidates
            .compactMap { candidate -> (record: LRCLIBRecord, score: Double)? in
                guard let score = score(candidate: candidate, query: query) else { return nil }
                return (candidate, score)
            }
            .max(by: { $0.score < $1.score })?
            .record
    }

    public static func isAcceptable(
        _ candidate: LRCLIBRecord,
        for query: TrackQueryNormalizer.NormalizedQuery
    ) -> Bool {
        score(candidate: candidate, query: query) != nil
    }

    private static func score(
        candidate: LRCLIBRecord,
        query: TrackQueryNormalizer.NormalizedQuery
    ) -> Double? {
        let hasSynced = !(candidate.syncedLyrics?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let hasPlain = !(candidate.plainLyrics?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let isInstrumental = candidate.instrumental ?? false
        guard hasSynced || hasPlain || isInstrumental else { return nil }

        // Gate 1: Strict title relevance
        let rawCandidateTitle = candidate.trackName ?? ""
        let cleanedCandidateTitle = TrackQueryNormalizer.cleanTitle(rawCandidateTitle)
        let titleTier = evaluateTitleMatch(
            target: query.title,
            candidateRaw: rawCandidateTitle,
            candidateCleaned: cleanedCandidateTitle
        )
        guard titleTier != .none else { return nil }

        // Gate 2: Duration sanity check when both durations are known
        var durationDiff: Double?
        if let targetDur = query.duration, targetDur > 10, let candDur = candidate.duration, candDur > 10 {
            let diff = abs(Double(targetDur) - candDur)
            guard diff <= 15.0 else { return nil }
            durationDiff = diff
        }

        // Gate 3: Artist verification (with narrow localized-artist escape hatch:
        // exact title + duration within ±4s, e.g., 周杰伦 vs Jay Chou on the same track)
        let hasTargetArtist = !query.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let artistMatches = !hasTargetArtist || matchesArtist(
            target: query.artist,
            candidate: candidate.artistName ?? ""
        )

        if !artistMatches {
            let localizedEscapeHatch = (titleTier == .exact) && (durationDiff.map { $0 <= 4.0 } ?? false)
            guard localizedEscapeHatch else { return nil }
        }

        // Rank validated candidates (prefer synced lyrics, exact title/artist, tightest duration)
        var total: Double = 0
        switch titleTier {
        case .exact: total += 60
        case .strongContainment: total += 38
        case .tokenOverlap: total += 26
        case .none: return nil
        }

        if artistMatches && hasTargetArtist {
            total += 40
        }

        if let diff = durationDiff {
            if diff <= 2.0 { total += 30 }
            else if diff <= 5.0 { total += 20 }
            else if diff <= 10.0 { total += 10 }
        }

        if hasSynced { total += 24 }
        else if hasPlain { total += 8 }
        else if isInstrumental { total += 6 }

        return total
    }

    private static func evaluateTitleMatch(
        target: String,
        candidateRaw: String,
        candidateCleaned: String
    ) -> TitleMatchTier {
        let targetCanon = canonical(target)
        let targetCompact = compact(targetCanon)
        guard !targetCompact.isEmpty else { return .none }

        for candidateVariant in [candidateCleaned, candidateRaw] {
            let candCanon = canonical(candidateVariant)
            let candCompact = compact(candCanon)
            guard !candCompact.isEmpty else { continue }

            if candCanon == targetCanon || candCompact == targetCompact {
                return .exact
            }
        }

        let candCanon = canonical(candidateCleaned.isEmpty ? candidateRaw : candidateCleaned)
        let candCompact = compact(candCanon)
        guard !candCompact.isEmpty else { return .none }

        let shorter = min(targetCompact.count, candCompact.count)
        let longer = max(targetCompact.count, candCompact.count)
        if shorter >= 3, Double(shorter) / Double(longer) >= 0.62,
           (candCompact.contains(targetCompact) || targetCompact.contains(candCompact))
        {
            return .strongContainment
        }

        let targetTokens = Set(targetCanon.split(separator: " ").map(String.init))
        let candTokens = Set(candCanon.split(separator: " ").map(String.init))
        if targetTokens.count >= 2 && candTokens.count >= 2 {
            let intersection = targetTokens.intersection(candTokens).count
            let union = targetTokens.union(candTokens).count
            if union > 0 && Double(intersection) / Double(union) >= 0.68 {
                return .tokenOverlap
            }
        }

        return .none
    }

    private static func matchesArtist(target: String, candidate: String) -> Bool {
        let targetParts = artistTokens(target)
        let candParts = artistTokens(candidate)
        guard !targetParts.isEmpty, !candParts.isEmpty else { return false }

        for t in targetParts {
            for c in candParts {
                if t == c { return true }
                let shorter = min(t.count, c.count)
                let longer = max(t.count, c.count)
                if shorter >= 2, Double(shorter) / Double(longer) >= 0.55, (t.contains(c) || c.contains(t)) {
                    return true
                }
            }
        }
        return false
    }

    private static func artistTokens(_ raw: String) -> [String] {
        let normalized = canonical(raw)
        let separators = [" & ", " feat ", " ft ", " featuring ", " x ", " and ", ",", "/", "、", ";"]
        var working = normalized
        for sep in separators {
            working = working.replacingOccurrences(of: sep, with: "|")
        }
        let pieces = working
            .split(separator: "|")
            .map { compact(String($0)) }
            .filter { !$0.isEmpty }
        let whole = compact(normalized)
        return whole.isEmpty ? pieces : Array(Set(pieces + [whole]))
    }

    private static func canonical(_ text: String) -> String {
        let halfWidth = text.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? text
        let folded = halfWidth.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let allowed = folded.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(scalar)
            }
            return " "
        }
        return String(allowed)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private static func compact(_ canonicalText: String) -> String {
        canonicalText.replacingOccurrences(of: " ", with: "")
    }
}
