import CoreDomain
import Foundation

/// Pure parser for standard and enhanced LRC lyrics formats.
/// Supports `[mm:ss.xx]`, `[mm:ss.xxx]`, `[mm:ss]`, multiple timestamps per line,
/// `[offset:±ms]` timing shifts, and strips inline enhanced `<mm:ss.xx>` word markers.
public enum LRCParser {
    private static let timestampRegex = try! NSRegularExpression(
        pattern: #"\[(\d{1,3}):(\d{2})(?:[\.:](\d{1,3}))?\]"#
    )
    private static let offsetRegex = try! NSRegularExpression(
        pattern: #"^\[offset:\s*([+-]?\d+)\s*\]$"#,
        options: [.caseInsensitive]
    )
    private static let inlineWordTagRegex = try! NSRegularExpression(
        pattern: #"<\d{1,3}:\d{2}(?:[\.:]\d{1,3})?>"#
    )

    public static func parseSynced(_ rawLRC: String) -> [LyricLine] {
        let rawLines = rawLRC.components(separatedBy: .newlines)
        var offsetSeconds: TimeInterval = 0
        var parsedEntries: [(time: TimeInterval, text: String)] = []

        for rawLine in rawLines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let fullRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)

            // Check [offset:±ms] metadata tag
            if let offsetMatch = offsetRegex.firstMatch(in: trimmed, range: fullRange),
               let valueRange = Range(offsetMatch.range(at: 1), in: trimmed),
               let offsetMs = Double(trimmed[valueRange])
            {
                offsetSeconds = offsetMs / 1000.0
                continue
            }

            let matches = timestampRegex.matches(in: trimmed, range: fullRange)
            guard !matches.isEmpty else { continue }

            // Extract text after the last timestamp tag
            guard let lastMatch = matches.last,
                  let lastEnd = Range(lastMatch.range, in: trimmed)?.upperBound
            else {
                continue
            }

            let rawText = String(trimmed[lastEnd...])
            let strippedWordTags = inlineWordTagRegex.stringByReplacingMatches(
                in: rawText,
                range: NSRange(rawText.startIndex..<rawText.endIndex, in: rawText),
                withTemplate: ""
            )
            let cleanText = strippedWordTags.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanText.isEmpty else { continue }

            for match in matches {
                guard let minutesRange = Range(match.range(at: 1), in: trimmed),
                      let secondsRange = Range(match.range(at: 2), in: trimmed),
                      let minutes = Double(trimmed[minutesRange]),
                      let seconds = Double(trimmed[secondsRange])
                else {
                    continue
                }

                var fractional: Double = 0
                if match.range(at: 3).location != NSNotFound,
                   let fracRange = Range(match.range(at: 3), in: trimmed)
                {
                    let fracString = String(trimmed[fracRange])
                    if let fracValue = Double(fracString) {
                        switch fracString.count {
                        case 1: fractional = fracValue / 10.0
                        case 2: fractional = fracValue / 100.0
                        default: fractional = fracValue / 1000.0
                        }
                    }
                }

                let timestamp = max(0, minutes * 60.0 + seconds + fractional + offsetSeconds)
                parsedEntries.append((time: timestamp, text: cleanText))
            }
        }

        parsedEntries.sort { lhs, rhs in
            lhs.time < rhs.time
        }

        return parsedEntries.enumerated().map { index, entry in
            LyricLine(id: index, startTime: entry.time, text: entry.text)
        }
    }

    public static func parsePlain(_ rawText: String) -> [String] {
        rawText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
