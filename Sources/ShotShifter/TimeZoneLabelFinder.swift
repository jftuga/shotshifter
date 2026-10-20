// Detection of time zone text anywhere in the image. UTC and GMT forms are rewritten to
// the shifted offset so the image keeps naming the right zone; named zones and
// abbreviations cannot be rewritten with a fixed offset, so they only produce warnings.

import CoreGraphics
import Foundation

/// Finds time zone words and decides how to handle them.
enum TimeZoneLabelFinder {
    /// The rewrites and warnings for one image.
    struct Result: Sendable, Equatable {
        /// UTC/GMT words to redraw.
        let replacements: [LabelReplacement]
        /// One warning per distinct zone word that is left unchanged, with every place the word appears.
        let warnings: [ShiftWarning]
    }

    /// One time zone word found in the image.
    private struct Match: RecognizedItem {
        /// The word as recognized.
        let text: String
        /// The word's pixel box.
        let box: CGRect
        /// The recognition confidence.
        let confidence: Float
        /// Whether the word was read in a tile pass.
        let fromTile: Bool
        /// The rewritten word, or `nil` for a warn-only zone.
        let newText: String?
    }

    /// The characters, besides whitespace, that separate words.
    private static let separators: Set<Character> = [",", "(", ")", "|"]

    /// Scans every observation for time zone words.
    /// - Parameters:
    ///   - observations: All recognized text.
    ///   - offset: The shift applied to the axis.
    /// - Returns: The rewrites and warnings.
    static func find(in observations: [TextObservation], offset: TimeOffset) -> Result {
        var matches: [Match] = []
        for observation in observations {
            for range in wordRanges(in: observation.text) {
                let word = String(observation.text[range])
                let newText: String?
                if let minutes = utcOffsetMinutes(of: word) {
                    newText = utcText(offsetMinutes: minutes + offset.minutes)
                } else if isOtherTimeZone(word) {
                    newText = nil
                } else {
                    continue
                }
                matches.append(Match(text: word, box: observation.box(for: range), confidence: observation.confidence, fromTile: observation.fromTile, newText: newText))
            }
        }
        let unique = matches.removingDuplicates()
        let replacements = unique.compactMap { match in
            match.newText.map { LabelReplacement(box: match.box, oldText: match.text, newText: $0, placement: .timeZone) }
        }
        let warnOnly = unique.filter { $0.newText == nil }
        var warned: Set<String> = []
        let warnings = warnOnly.filter { warned.insert($0.text).inserted }.map { first in
            ShiftWarning(message: "time zone label \"\(first.text)\" was not rewritten and no longer matches the shifted axis", boxes: warnOnly.filter { $0.text == first.text }.map(\.box))
        }
        return Result(replacements: replacements, warnings: warnings)
    }

    /// Splits text into words on whitespace and on `,`, `(`, `)` and `|`.
    /// - Parameters:
    ///   - text: The text to split.
    /// - Returns: The range of each word in `text`.
    static func wordRanges(in text: String) -> [Range<String.Index>] {
        text.split(whereSeparator: { $0.isWhitespace || separators.contains($0) }).map { $0.startIndex..<$0.endIndex }
    }

    /// Reads a UTC-based zone word: `UTC`, `GMT`, or either followed by `+` or `-` and `H`, `HH`, `H:MM` or `HH:MM`.
    /// - Parameters:
    ///   - word: The word to read.
    /// - Returns: The zone's offset from UTC in minutes, or `nil` if the word is not a UTC-based zone.
    static func utcOffsetMinutes(of word: String) -> Int? {
        guard let prefix = ["UTC", "GMT"].first(where: { word.hasPrefix($0) }) else {
            return nil
        }
        let rest = word.dropFirst(prefix.count)
        return rest.isEmpty ? 0 : TimeOffset.minutes(from: rest, signRequired: true)
    }

    /// Whether a word names a zone that is not UTC-based: an identifier containing `/`, or a known abbreviation.
    /// - Parameters:
    ///   - word: The word to check.
    /// - Returns: `true` for a warn-only zone.
    static func isOtherTimeZone(_ word: String) -> Bool {
        if word.contains("/"), TimeZone(identifier: word) != nil {
            return true
        }
        return word != "UTC" && word != "GMT" && TimeZone.abbreviationDictionary[word] != nil
    }

    /// Formats a UTC offset: `UTC` when zero, otherwise `UTC` with a sign and `HH:MM`.
    /// - Parameters:
    ///   - offsetMinutes: The offset from UTC in minutes.
    /// - Returns: The zone text, such as `UTC-05:00`.
    static func utcText(offsetMinutes: Int) -> String {
        guard offsetMinutes != 0 else {
            return "UTC"
        }
        let magnitude = abs(offsetMinutes)
        return "UTC\(offsetMinutes < 0 ? "-" : "+")\((magnitude / 60).twoDigits):\((magnitude % 60).twoDigits)"
    }
}
