// Tests for parsing the --shift value: every accepted form and every rejected form
// listed in the specification, including zero offsets and out-of-range fields.

import Testing
@testable import ShotShifter

/// Tests for `TimeOffset`.
struct TimeOffsetTests {
    /// Accepted offsets parse to the expected number of minutes.
    /// - Parameters:
    ///   - text: The `--shift` value.
    ///   - minutes: The expected offset in minutes.
    @Test(arguments: [
        ("5", 300), ("+5", 300), ("-5", -300), ("+5:30", 330), ("-03:30", -210),
        ("26", 1560), ("-26", -1560), ("0:30", 30), ("+00:01", 1), ("12:59", 779),
    ])
    func accepts(text: String, minutes: Int) throws {
        #expect(try TimeOffset(parsing: text).minutes == minutes)
    }

    /// Malformed or out-of-range offsets are rejected as invalid.
    /// - Parameters:
    ///   - text: The `--shift` value.
    @Test(arguments: ["", "27", "100", "5:60", "5:3", "5:300", "5.5", "5h", "++5", "+-5", "-", "+", ":30", "5:", "5:30:00", " 5", "５"])
    func rejectsInvalid(text: String) {
        #expect(throws: ShotShifterError.invalidOffset(text)) {
            try TimeOffset(parsing: text)
        }
    }

    /// Zero offsets are rejected as zero.
    /// - Parameters:
    ///   - text: The `--shift` value.
    @Test(arguments: ["0", "+0:00", "-00:00", "00"])
    func rejectsZero(text: String) {
        #expect(throws: ShotShifterError.zeroOffset) {
            try TimeOffset(parsing: text)
        }
    }

    /// The shared reader requires a sign when asked and allows zero.
    @Test func readsSignedMinutes() {
        #expect(TimeOffset.minutes(from: "+02:00", signRequired: true) == 120)
        #expect(TimeOffset.minutes(from: "-0", signRequired: true) == 0)
        #expect(TimeOffset.minutes(from: "5", signRequired: true) == nil)
    }
}
