// One X-axis: a run of labels of one kind, sorted left to right, with the full
// date-time of each label. A row exists only when its timeline is valid.

import Foundation

/// A validated time axis.
struct AxisRow: Sendable, Equatable {
    /// The labels, left to right.
    let labels: [AxisLabel]

    /// The full date-time of each label.
    let timeline: RowTimeline

    /// Whether the labels' dates are known rather than placeholders.
    var datesKnown: Bool {
        timeline.datesKnown
    }

    /// Creates a row from labels, sorting them left to right.
    /// - Parameters:
    ///   - labels: The labels, at least two.
    ///   - currentYear: The reference year for dated labels.
    /// - Returns: `nil` when there are fewer than two labels or their timeline is not strictly increasing.
    init?(labels: [AxisLabel], currentYear: Int) {
        let sorted = labels.sorted { $0.box.midX < $1.box.midX }
        guard sorted.count >= 2, let timeline = RowTimeline(labels: sorted, currentYear: currentYear) else {
            return nil
        }
        self.labels = sorted
        self.timeline = timeline
    }
}
