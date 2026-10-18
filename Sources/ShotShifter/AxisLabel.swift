// The parsed form of one X-axis tick label. A label has one of the four Grafana
// 24-hour formats, its time fields, an optional month and day, and the pixel box
// where it was found in the image.

import CoreGraphics

/// The four supported label formats.
enum LabelKind: Sendable, Equatable {
    /// `HH:mm:ss`, such as `14:00:30`.
    case timeWithSeconds
    /// `HH:mm`, such as `14:00`.
    case time
    /// `MM/DD HH:mm`, such as `10/16 14:00`, optionally with a comma after the date.
    case dateTime
    /// `MM/DD`, such as `10/16`; the label means midnight on that day.
    case date
}

/// The month and day part of a `date` or `dateTime` label.
struct LabelDate: Sendable, Equatable {
    /// The month, 1-12.
    let month: Int
    /// The day of the month, 1-31.
    let day: Int
    /// Whether month and day were both written with two digits, such as `03/14` rather than `3/14`.
    let isPadded: Bool
    /// Whether a comma followed the date, as in `10/16, 14:00`.
    let hasComma: Bool
}

/// One parsed X-axis label.
struct AxisLabel: Sendable, Equatable, RecognizedItem {
    /// The label's format.
    let kind: LabelKind
    /// The month and day, present for `date` and `dateTime` labels.
    let date: LabelDate?
    /// The hour, 0-23.
    let hour: Int
    /// The minute, 0-59.
    let minute: Int
    /// The second, 0-59; zero for formats without seconds.
    let second: Int
    /// The label text after recognition fixes, such as `10/16 14:00`.
    let text: String
    /// The label's pixel box, top-left origin.
    let box: CGRect
    /// Vision's confidence in the observation the label came from.
    let confidence: Float
}
