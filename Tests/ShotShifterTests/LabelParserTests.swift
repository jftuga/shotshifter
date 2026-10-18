// Tests for turning recognized text into axis labels: the four formats, the comma form,
// unpadded month/day, recognition-confusion fixes, splitting merged observations,
// ignoring observations with other text, and removing duplicate finds.

import CoreGraphics
import Testing
@testable import ShotShifter

/// Tests for `LabelParser`.
struct LabelParserTests {
    /// Single-label observations parse to the right kind and fields.
    @Test func parsesEachFormat() throws {
        let time = try #require(LabelParser.labels(in: TestSupport.observation("14:05", x: 0)).first)
        #expect(time.kind == .time && time.hour == 14 && time.minute == 5 && time.date == nil)
        let seconds = try #require(LabelParser.labels(in: TestSupport.observation("14:00:30", x: 0)).first)
        #expect(seconds.kind == .timeWithSeconds && seconds.second == 30)
        let dateTime = try #require(LabelParser.labels(in: TestSupport.observation("10/16 14:00", x: 0)).first)
        #expect(dateTime.kind == .dateTime && dateTime.date == LabelDate(month: 10, day: 16, isPadded: true, hasComma: false) && dateTime.hour == 14)
        let date = try #require(LabelParser.labels(in: TestSupport.observation("10/16", x: 0)).first)
        #expect(date.kind == .date && date.hour == 0)
    }

    /// The comma form keeps its comma and stays one label.
    @Test func parsesCommaForm() throws {
        let labels = LabelParser.labels(in: TestSupport.observation("10/16, 14:00", x: 0))
        let label = try #require(labels.first)
        #expect(labels.count == 1)
        #expect(label.kind == .dateTime && label.date?.hasComma == true && label.text == "10/16, 14:00")
    }

    /// Unpadded month and day are accepted and marked as unpadded.
    @Test func parsesUnpaddedDate() throws {
        let label = try #require(LabelParser.labels(in: TestSupport.observation("3/14 20:00", x: 0)).first)
        #expect(label.kind == .dateTime && label.date == LabelDate(month: 3, day: 14, isPadded: false, hasComma: false))
    }

    /// Common recognition confusions are fixed before parsing.
    @Test func fixesConfusions() throws {
        let label = try #require(LabelParser.labels(in: TestSupport.observation("1O:3l", x: 0)).first)
        #expect(label.text == "10:31" && label.hour == 10 && label.minute == 31)
    }

    /// Invalid fields and malformed words do not parse.
    /// - Parameters:
    ///   - text: The recognized text.
    @Test(arguments: ["24:00", "12:60", "1:00", "12:5", "13/01", "02/30", "04/31", "0/5", "123/4", "10/16,", "12:00:60", "2026-10-16", "12.00", "AM"])
    func rejects(text: String) {
        #expect(LabelParser.labels(in: TestSupport.observation(text, x: 0)).isEmpty)
    }

    /// February 29 is a valid label.
    @Test func acceptsLeapDay() {
        #expect(LabelParser.labels(in: TestSupport.observation("02/29", x: 0)).count == 1)
    }

    /// A merged observation is split into its labels, each with its own box.
    @Test func splitsMergedObservation() {
        let labels = LabelParser.labels(in: TestSupport.observation("18:00 20:00 22:00", x: 0))
        #expect(labels.map(\.text) == ["18:00", "20:00", "22:00"])
        #expect(labels.map(\.box.minX) == [0, 60, 120])
    }

    /// Merged date-time labels pair each date with the time right after it.
    @Test func splitsMergedDateTimes() {
        let labels = LabelParser.labels(in: TestSupport.observation("3/14 20:00 3/14 22:00", x: 0))
        #expect(labels.map(\.text) == ["3/14 20:00", "3/14 22:00"])
        #expect(labels.allSatisfy { $0.kind == .dateTime })
    }

    /// A date followed by a time far away is two labels, not one date-time.
    @Test func keepsDistantDateAndTimeApart() {
        let observation = TextObservation(text: "10/16 14:00", box: CGRect(x: 0, y: 0, width: 1100, height: 20))
        #expect(LabelParser.labels(in: observation).map(\.kind) == [.date, .time])
    }

    /// An observation with any text that is not a label is ignored entirely.
    @Test func ignoresMixedText() {
        #expect(LabelParser.labels(in: TestSupport.observation("2026-10-16 08:00:00 to 2026-10-16 14:00:00", x: 0)).isEmpty)
        #expect(LabelParser.labels(in: TestSupport.observation("14:00 CPU", x: 0)).isEmpty)
    }

    /// Overlapping finds of one label collapse to the most complete one.
    @Test func removesDuplicates() {
        let observations = [
            TestSupport.observation("20:00", x: 50),
            TestSupport.observation("10/16 20:00", x: 0),
            TestSupport.observation("21:00", x: 300),
            TestSupport.observation("21:00", x: 301),
        ]
        let labels = LabelParser.labels(in: observations)
        #expect(Set(labels.map(\.text)) == ["10/16 20:00", "21:00"])
        #expect(labels.count == 2)
    }
}
