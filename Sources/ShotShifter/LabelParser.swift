// Conversion of recognized text into X-axis labels. Each observation is split into
// words, common recognition confusions are fixed, and every word must parse as part of
// a label or the whole observation is ignored. A date word directly followed by a time
// word becomes one date-time label; duplicates from overlapping recognition passes are removed.

import CoreGraphics

/// Parses recognized text into `AxisLabel` values.
enum LabelParser {
    /// One parsed word and its pixel box.
    private struct Token {
        /// The word's text after recognition fixes.
        let text: String
        /// The word's pixel box.
        let box: CGRect
        /// The parsed date, when the word is a date.
        let date: LabelDate?
        /// The parsed time, when the word is a time.
        let time: (hour: Int, minute: Int, second: Int?)?
    }

    /// Parses every observation and removes duplicate labels found by more than one pass.
    /// - Parameters:
    ///   - observations: The recognized text.
    /// - Returns: The labels found, in no particular order.
    static func labels(in observations: [TextObservation]) -> [AxisLabel] {
        observations.flatMap { labels(in: $0) }.removingDuplicates()
    }

    /// Parses one observation, which may hold several labels that Vision merged.
    /// - Parameters:
    ///   - observation: The recognized text.
    /// - Returns: The labels, or an empty array if any word is not part of a label.
    static func labels(in observation: TextObservation) -> [AxisLabel] {
        var tokens: [Token] = []
        for word in observation.text.split(whereSeparator: \.isWhitespace) {
            guard let token = token(from: fixingConfusions(word), box: observation.box(for: word.startIndex..<word.endIndex)) else {
                return []
            }
            tokens.append(token)
        }
        var labels: [AxisLabel] = []
        var index = 0
        while index < tokens.count {
            let token = tokens[index]
            let next = index + 1 < tokens.count ? tokens[index + 1] : nil
            if let time = token.time {
                labels.append(AxisLabel(kind: time.second == nil ? .time : .timeWithSeconds, date: nil, hour: time.hour, minute: time.minute, second: time.second ?? 0, text: token.text, box: token.box, confidence: observation.confidence))
                index += 1
            } else if let date = token.date, let next, let time = next.time, time.second == nil, next.box.minX - token.box.maxX < token.box.height {
                labels.append(AxisLabel(kind: .dateTime, date: date, hour: time.hour, minute: time.minute, second: 0, text: "\(token.text) \(next.text)", box: token.box.union(next.box), confidence: observation.confidence))
                index += 2
            } else if let date = token.date, !date.hasComma {
                labels.append(AxisLabel(kind: .date, date: date, hour: 0, minute: 0, second: 0, text: token.text, box: token.box, confidence: observation.confidence))
                index += 1
            } else {
                return []
            }
        }
        return labels
    }

    /// Replaces the recognition confusions `O`/`o` with `0` and `I`/`l` with `1`.
    /// - Parameters:
    ///   - word: The recognized word.
    /// - Returns: The fixed word.
    static func fixingConfusions(_ word: some StringProtocol) -> String {
        String(word.map { character in
            switch character {
            case "O", "o": "0"
            case "I", "l": "1"
            default: character
            }
        })
    }

    /// Parses one word as a date (`M/D`, `MM/DD`, optionally followed by a comma) or a time (`HH:mm`, `HH:mm:ss`).
    /// - Parameters:
    ///   - text: The word after recognition fixes.
    ///   - box: The word's pixel box.
    /// - Returns: The token, or `nil` if the word is neither.
    private static func token(from text: String, box: CGRect) -> Token? {
        if let date = parseDate(text) {
            return Token(text: text, box: box, date: date, time: nil)
        }
        if let time = parseTime(text) {
            return Token(text: text, box: box, date: nil, time: time)
        }
        return nil
    }

    /// Parses `M/D` or `MM/DD`, with an optional trailing comma. February 29 is accepted.
    /// - Parameters:
    ///   - text: The word to parse.
    /// - Returns: The date, or `nil` if the word is not a valid month and day.
    static func parseDate(_ text: String) -> LabelDate? {
        let hasComma = text.hasSuffix(",")
        let parts = text.dropLast(hasComma ? 1 : 0).split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2, parts.allSatisfy({ (1...2).contains($0.count) && $0.isASCIIDigits }), let month = Int(parts[0]), let day = Int(parts[1]) else {
            return nil
        }
        guard (1...12).contains(month), (1...maximumDay(inMonth: month)).contains(day) else {
            return nil
        }
        return LabelDate(month: month, day: day, isPadded: parts.allSatisfy { $0.count == 2 }, hasComma: hasComma)
    }

    /// Parses `HH:mm` or `HH:mm:ss`, every field exactly two digits.
    /// - Parameters:
    ///   - text: The word to parse.
    /// - Returns: The time fields, with `second` `nil` for `HH:mm`, or `nil` if the word is not a valid time.
    static func parseTime(_ text: String) -> (hour: Int, minute: Int, second: Int?)? {
        let parts = text.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2 || parts.count == 3, parts.allSatisfy({ $0.count == 2 && $0.isASCIIDigits }) else {
            return nil
        }
        let values = parts.compactMap { Int($0) }
        guard values[0] <= 23, values.dropFirst().allSatisfy({ $0 <= 59 }) else {
            return nil
        }
        return (values[0], values[1], values.count == 3 ? values[2] : nil)
    }

    /// The largest valid day in a month, counting February as 29 days.
    /// - Parameters:
    ///   - month: The month, 1-12.
    /// - Returns: The number of days.
    private static func maximumDay(inMonth month: Int) -> Int {
        switch month {
        case 2: 29
        case 4, 6, 9, 11: 30
        default: 31
        }
    }
}
