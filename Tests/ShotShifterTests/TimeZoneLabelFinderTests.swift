// Tests for time zone labels: the rewrite table from the specification, word splitting
// on punctuation, warn-only zones, and the one-warning-per-zone rule with every place
// the zone appears.

import Testing
@testable import ShotShifter

/// Tests for `TimeZoneLabelFinder`.
struct TimeZoneLabelFinderTests {
    /// Every row of the rewrite table produces the expected text.
    /// - Parameters:
    ///   - shown: The zone shown in the image.
    ///   - shift: The `--shift` value.
    ///   - expected: The rewritten zone.
    @Test(arguments: [
        ("UTC", "-5", "UTC-05:00"),
        ("UTC+02:00", "-2", "UTC"),
        ("GMT-5", "+5:30", "UTC+00:30"),
        ("UTC+05:30", "+9", "UTC+14:30"),
        ("GMT", "+1", "UTC+01:00"),
    ])
    func rewrites(shown: String, shift: String, expected: String) throws {
        let result = TimeZoneLabelFinder.find(in: [TestSupport.observation(shown, x: 0)], offset: try TimeOffset(parsing: shift))
        #expect(result.replacements.map(\.newText) == [expected])
        #expect(result.replacements.first?.oldText == shown)
        #expect(result.replacements.first?.placement == .timeZone)
        #expect(result.warnings.isEmpty)
    }

    /// Only the zone word is rewritten, and its box covers just that word.
    @Test func rewritesOnlyTheWord() throws {
        let result = TimeZoneLabelFinder.find(in: [TestSupport.observation("Browser Time (UTC)", x: 0)], offset: try TimeOffset(parsing: "+1"))
        let replacement = try #require(result.replacements.first)
        #expect(replacement.oldText == "UTC")
        #expect(replacement.box.minX == 140 && replacement.box.width == 30)
    }

    /// Named zones and abbreviations only warn, once per distinct word, with a box for each place it appears.
    @Test func warnsForOtherZones() throws {
        let observations = [TestSupport.observation("EST | America/New_York", x: 0), TestSupport.observation("EST", x: 0, y: 900)]
        let result = TimeZoneLabelFinder.find(in: observations, offset: try TimeOffset(parsing: "+1"))
        #expect(result.replacements.isEmpty)
        #expect(result.warnings.count == 2)
        #expect(Set(result.warnings.map(\.message)) == [
            "time zone label \"America/New_York\" was not rewritten and no longer matches the shifted axis",
            "time zone label \"EST\" was not rewritten and no longer matches the shifted axis",
        ])
        let est = try #require(result.warnings.first { $0.message.contains("\"EST\"") })
        #expect(est.boxes.map(\.minY).sorted() == [500, 900])
    }

    /// Words that are not zones, or malformed UTC offsets, are ignored.
    /// - Parameters:
    ///   - text: The recognized text.
    @Test(arguments: ["utc", "UTC+", "UTC+5:3", "UTC+05.30", "UTCX", "10/16", "Asia/Nowhere", "CPU"])
    func ignores(text: String) throws {
        let result = TimeZoneLabelFinder.find(in: [TestSupport.observation(text, x: 0)], offset: try TimeOffset(parsing: "+1"))
        #expect(result.replacements.isEmpty && result.warnings.isEmpty)
    }
}
