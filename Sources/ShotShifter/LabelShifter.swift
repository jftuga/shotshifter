// Application of the offset to a row and formatting of the new label text. Each label
// keeps its original format, except that a date-only label whose shifted time is no
// longer midnight gains a time, because its tick no longer sits on a day boundary.

import Foundation

/// Computes the new text of every label in a row.
enum LabelShifter {
    /// Returns the shifted text for each label in a row, left to right.
    /// - Parameters:
    ///   - row: The axis row.
    ///   - offset: The amount to add.
    /// - Returns: One new text per label.
    static func shiftedTexts(for row: AxisRow, offset: TimeOffset) -> [String] {
        let padded = row.labels.allSatisfy { $0.date?.isPadded ?? true }
        return zip(row.labels, row.timeline.dates).map { label, date in
            text(for: label, at: date.addingTimeInterval(TimeInterval(offset.minutes * 60)), padded: padded)
        }
    }

    /// Formats a shifted date-time in the format of the original label.
    /// - Parameters:
    ///   - label: The original label.
    ///   - date: The shifted date-time.
    ///   - padded: Whether to print month and day with two digits.
    /// - Returns: The new label text.
    static func text(for label: AxisLabel, at date: Date, padded: Bool) -> String {
        let parts = RowTimeline.calendar.dateComponents([.month, .day, .hour, .minute, .second], from: date)
        let hour = parts.hour ?? 0
        let minute = parts.minute ?? 0
        let time = "\(hour.twoDigits):\(minute.twoDigits)"
        let month = parts.month ?? 1
        let day = parts.day ?? 1
        let dayText = padded ? "\(month.twoDigits)/\(day.twoDigits)" : "\(month)/\(day)"
        switch label.kind {
        case .time:
            return time
        case .timeWithSeconds:
            return "\(time):\((parts.second ?? 0).twoDigits)"
        case .dateTime:
            return "\(dayText)\(label.date?.hasComma == true ? "," : "") \(time)"
        case .date:
            return hour == 0 && minute == 0 ? dayText : "\(dayText) \(time)"
        }
    }
}
