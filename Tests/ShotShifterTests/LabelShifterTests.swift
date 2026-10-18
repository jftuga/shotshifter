// Tests for shifting rows and formatting the new labels. Every worked example from the
// specification is checked, plus unpadded dates and a 24-hour shift that leaves
// time-only labels unchanged.

import Testing
@testable import ShotShifter

/// Tests for `LabelShifter`.
struct LabelShifterTests {
    /// The worked examples from the specification: labels before, shift, labels after.
    static let examples: [([String], String, [String])] = [
        (["22:00", "23:00", "00:00", "01:00"], "+2", ["00:00", "01:00", "02:00", "03:00"]),
        (["21:00", "22:00", "23:00"], "+1", ["22:00", "23:00", "00:00"]),
        (["14:00:00", "14:00:30", "14:01:00"], "+5:30", ["19:30:00", "19:30:30", "19:31:00"]),
        (["10/31 22:00", "11/01 04:00"], "-5", ["10/31 17:00", "10/31 23:00"]),
        (["10/16, 22:00", "10/17, 04:00"], "+5:30", ["10/17, 03:30", "10/17, 09:30"]),
        (["12/31 22:00", "01/01 04:00"], "+3", ["01/01 01:00", "01/01 07:00"]),
        (["10/14", "10/15", "10/16"], "-5", ["10/13 19:00", "10/14 19:00", "10/15 19:00"]),
        (["10/14", "10/15", "10/16"], "+24", ["10/15", "10/16", "10/17"]),
    ]

    /// Every worked example in the specification produces the expected row.
    /// - Parameters:
    ///   - before: The original labels.
    ///   - shift: The `--shift` value.
    ///   - after: The expected new labels.
    @Test(arguments: examples)
    func workedExamples(before: [String], shift: String, after: [String]) throws {
        let row = try TestSupport.row(before)
        #expect(LabelShifter.shiftedTexts(for: row, offset: try TimeOffset(parsing: shift)) == after)
    }

    /// A row with unpadded month/day keeps printing unpadded dates.
    @Test func keepsUnpaddedDates() throws {
        let row = try TestSupport.row(["3/14 20:00", "3/14 22:00", "3/15 00:00"])
        #expect(LabelShifter.shiftedTexts(for: row, offset: try TimeOffset(parsing: "-5")) == ["3/14 15:00", "3/14 17:00", "3/14 19:00"])
    }

    /// A 24-hour shift leaves time-only labels unchanged.
    @Test func dayShiftKeepsTimes() throws {
        let row = try TestSupport.row(["20:00", "21:00"])
        #expect(LabelShifter.shiftedTexts(for: row, offset: try TimeOffset(parsing: "-24")) == ["20:00", "21:00"])
    }
}
