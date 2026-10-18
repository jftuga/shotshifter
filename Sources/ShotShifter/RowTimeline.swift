// Assignment of a full date-time to every label in a row. Labels carry no year, so date
// rows use the current year (or a recent leap year when a label is 02/29) and roll over
// into the next year when the month and day go backwards. Time-only rows get placeholder
// dates that only order the labels. All math uses a Gregorian calendar in GMT.

import Foundation

/// The full date-times of a row's labels, left to right.
struct RowTimeline: Sendable, Equatable {
    /// The Gregorian calendar in GMT, so the machine's time zone and daylight saving never matter.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    /// How many years back to search for a year in which every 02/29 label is valid.
    private static let yearSearchLimit = 8

    /// One date-time per label, strictly increasing.
    let dates: [Date]

    /// Whether the dates come from the labels (`date`, `dateTime`) or are placeholders (`time`, `timeWithSeconds`).
    let datesKnown: Bool

    /// Builds the timeline for labels sorted left to right.
    /// - Parameters:
    ///   - labels: The row's labels, left to right, all of one kind.
    ///   - currentYear: The year used as the reference year for dated labels.
    /// - Returns: `nil` if the labels are empty or their date-times do not strictly increase.
    init?(labels: [AxisLabel], currentYear: Int) {
        guard let first = labels.first else {
            return nil
        }
        let dates: [Date]?
        if first.date != nil {
            dates = (0..<Self.yearSearchLimit).lazy.compactMap { Self.datedTimeline(labels, baseYear: currentYear - $0) }.first
            datesKnown = true
        } else {
            dates = Self.placeholderTimeline(labels)
            datesKnown = false
        }
        guard let dates, zip(dates, dates.dropFirst()).allSatisfy({ $0 < $1 }) else {
            return nil
        }
        self.dates = dates
    }

    /// Dates for labels that carry a month and day, starting in `baseYear` and moving to the next
    /// year whenever the month and day go backwards.
    /// - Parameters:
    ///   - labels: The labels, left to right.
    ///   - baseYear: The year of the first label.
    /// - Returns: The dates, or `nil` if a label has no date or names a day that does not exist in its year.
    private static func datedTimeline(_ labels: [AxisLabel], baseYear: Int) -> [Date]? {
        var year = baseYear
        var previous: LabelDate?
        var dates: [Date] = []
        for label in labels {
            guard let date = label.date else {
                return nil
            }
            if let previous, (date.month, date.day) < (previous.month, previous.day) {
                year += 1
            }
            previous = date
            let components = DateComponents(year: year, month: date.month, day: date.day, hour: label.hour, minute: label.minute, second: label.second)
            guard let value = calendar.date(from: components), calendar.component(.day, from: value) == date.day else {
                return nil
            }
            dates.append(value)
        }
        return dates
    }

    /// Placeholder dates for time-only labels: one day is added whenever the time of day does not increase.
    /// - Parameters:
    ///   - labels: The labels, left to right.
    /// - Returns: The placeholder dates.
    private static func placeholderTimeline(_ labels: [AxisLabel]) -> [Date]? {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        var day = 0
        var previousSeconds: Int?
        var dates: [Date] = []
        for label in labels {
            let seconds = label.hour * 3600 + label.minute * 60 + label.second
            if let previousSeconds, seconds <= previousSeconds {
                day += 1
            }
            previousSeconds = seconds
            guard let value = calendar.date(byAdding: DateComponents(day: day, second: seconds), to: start) else {
                return nil
            }
            dates.append(value)
        }
        return dates
    }
}
