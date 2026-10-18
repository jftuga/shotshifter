// Tests for building a row's timeline: placeholder days for time-only rows, year
// rollover for dated rows, the leap-year reference for 02/29, and rejection of rows
// whose date-times do not strictly increase.

import Foundation
import Testing
@testable import ShotShifter

/// Tests for `RowTimeline`.
struct RowTimelineTests {
    /// Builds a timeline from label texts.
    /// - Parameters:
    ///   - texts: The label texts, left to right.
    /// - Returns: The timeline, or `nil` if it is invalid.
    private func timeline(_ texts: [String]) -> RowTimeline? {
        RowTimeline(labels: TestSupport.labels(texts), currentYear: TestSupport.year)
    }

    /// Formats a date in GMT for comparison.
    /// - Parameters:
    ///   - date: The date.
    /// - Returns: The date as `yyyy-MM-dd HH:mm:ss`.
    private func text(_ date: Date) -> String {
        let parts = RowTimeline.calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return "\(parts.year ?? 0)-\((parts.month ?? 0).twoDigits)-\((parts.day ?? 0).twoDigits) \((parts.hour ?? 0).twoDigits):\((parts.minute ?? 0).twoDigits):\((parts.second ?? 0).twoDigits)"
    }

    /// Time-only rows move to the next day whenever the time does not increase.
    @Test func addsDaysToTimeRows() throws {
        let result = try #require(timeline(["22:00", "23:00", "00:00", "01:00"]))
        #expect(!result.datesKnown)
        let hours = zip(result.dates, result.dates.dropFirst()).map { $1.timeIntervalSince($0) / 3600 }
        #expect(hours == [1, 1, 1])
    }

    /// Dated rows use the current year and roll over to the next year.
    @Test func rollsOverYear() throws {
        let result = try #require(timeline(["12/31 22:00", "01/01 04:00"]))
        #expect(result.datesKnown)
        #expect(result.dates.map(text) == ["2026-12-31 22:00:00", "2027-01-01 04:00:00"])
    }

    /// A row with 02/29 uses the most recent leap year.
    @Test func usesLeapYearForLeapDay() throws {
        let result = try #require(timeline(["02/28", "02/29", "03/01"]))
        #expect(result.dates.map(text) == ["2024-02-28 00:00:00", "2024-02-29 00:00:00", "2024-03-01 00:00:00"])
    }

    /// Date-times that do not strictly increase are not a timeline.
    @Test func rejectsNonIncreasingDates() {
        #expect(timeline(["10/16 14:00", "10/16 14:00"]) == nil)
        #expect(timeline(["10/16 14:00", "10/16 13:00"]) == nil)
    }
}
