// Tests for turning recognized text into axis labels: the four formats, the comma form,
// unpadded month/day, recognition-confusion fixes, splitting merged observations and
// glued times, ignoring observations with other text while reporting the labels inside
// them, and removing duplicate finds in favor of agreed and tile reads.

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
    @Test(arguments: ["24:00", "12:60", "1:00", "12:5", "13/01", "02/30", "04/31", "0/5", "123/4", "10/16,", "12:00:60", "2026-10-16", "12.00", "AM", "04:3004:4", "04:3024:00", "04:3004:40:00"])
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

    /// Touching labels on a crowded axis, read as one word, are split into their times (img027:
    /// Vision returned `04:3004:4004:50` inside a merged line, and the whole line was ignored).
    @Test func splitsGluedTimes() {
        let labels = LabelParser.labels(in: TestSupport.observation("04:20 04:3004:4004:50 05:00", x: 0))
        #expect(labels.map(\.text) == ["04:20", "04:30", "04:40", "04:50", "05:00"])
        #expect(labels.map(\.box.minX) == [0, 60, 110, 160, 220])
    }

    /// Glued times with seconds are split too.
    @Test func splitsGluedTimesWithSeconds() {
        let labels = LabelParser.labels(in: TestSupport.observation("19:00:0019:01:00", x: 0))
        #expect(labels.map(\.text) == ["19:00:00", "19:01:00"])
        #expect(labels.allSatisfy { $0.kind == .timeWithSeconds })
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

    /// Labels inside an observation that also holds other text are reported, unless another
    /// observation yields the same label cleanly.
    @Test func reportsMixedLabels() {
        let observations = [
            TestSupport.observation("14:00 CPU 15:00", x: 0),
            TestSupport.observation("21:00", x: 300),
            TestSupport.observation("21:00 x", x: 300),
            TestSupport.observation("2026-10-16 x", x: 600),
        ]
        #expect(LabelParser.mixedLabels(in: observations).map(\.text).sorted() == ["14:00", "15:00"])
    }

    /// A tile read beats an equally confident whole-image read of the same label (img048 and img110:
    /// the downscaled whole-image pass read 12:20 as `10:00` and 19:30:00 as `10:30:00` at full
    /// confidence, while the tiles read them correctly, and the whole-image read won by coming first).
    /// - Parameters:
    ///   - wholeImage: The whole-image pass's misread.
    ///   - tile: The tile pass's correct read.
    @Test(arguments: [("10:00", "12:20"), ("10:20", "10:30"), ("10:30:00", "19:30:00")])
    func prefersTileReads(wholeImage: String, tile: String) {
        let observations = [
            TestSupport.observation(wholeImage, x: 500),
            TestSupport.observation(tile, x: 501, fromTile: true),
        ]
        #expect(LabelParser.labels(in: observations).map(\.text) == [tile])
    }

    /// The reading most passes agree on beats a lone tile read (img306: the whole-image pass and one
    /// tile read 11:39:00 correctly, another tile read the compressed text as `11:38:00`).
    @Test func prefersAgreedReads() {
        let observations = [
            TestSupport.observation("11:39:00", x: 500),
            TestSupport.observation("11:38:00", x: 501, fromTile: true),
            TestSupport.observation("11:39:00", x: 502, fromTile: true),
        ]
        #expect(LabelParser.labels(in: observations).map(\.text) == ["11:39:00"])
    }

    /// The surviving label takes the tightest box among the finds that agree with it (img156: a tile
    /// read of the merged line `15:45 15:50` boxed 15:45 60 pixels wide and 10 pixels off center).
    @Test func keepsTightestBox() throws {
        let observations = [
            TextObservation(text: "15:45", box: CGRect(x: 144, y: 500, width: 60, height: 20), fromTile: true),
            TextObservation(text: "15:45", box: CGRect(x: 146, y: 500, width: 40, height: 20)),
        ]
        let label = try #require(LabelParser.labels(in: observations).first)
        #expect(label.box == CGRect(x: 146, y: 500, width: 40, height: 20))
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
