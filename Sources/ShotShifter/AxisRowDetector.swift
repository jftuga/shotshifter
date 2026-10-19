// Detection of time axes among the parsed labels. Labels are grouped into lines by
// vertical position, misread labels whose time does not match their position are set
// aside, and each line is split into rows of constant minutes-per-pixel, because
// Grafana spaces ticks evenly in both time and pixels. Panels side by side put several
// axes on one line; each becomes its own row.

import CoreGraphics
import Foundation

/// Finds the valid time axes among a set of labels.
enum AxisRowDetector {
    /// The largest relative difference in minutes-per-pixel allowed within one row.
    static let stepTolerance = 0.10

    /// The time scale of a stretch of evenly spaced labels.
    private struct Cadence {
        /// Minutes per pixel.
        let minutesPerPixel: Double
        /// Minutes between neighboring ticks.
        let tickMinutes: Double
    }

    /// The outcome of row detection.
    struct Result: Sendable, Equatable {
        /// The valid rows.
        let rows: [AxisRow]
        /// Labels that ended up in no valid row.
        let unusedLabels: [AxisLabel]
    }

    /// Groups labels into lines, sets misread labels aside, splits lines into rows, and keeps the valid rows.
    /// - Parameters:
    ///   - labels: Every parsed label.
    ///   - currentYear: The reference year for dated labels.
    /// - Returns: The valid rows and the labels left over.
    static func detect(_ labels: [AxisLabel], currentYear: Int) -> Result {
        var rows: [AxisRow] = []
        var unused: [AxisLabel] = []
        for line in lines(from: labels) {
            let checked = removingMisreadLabels(from: line, currentYear: currentYear)
            unused += checked.misread
            for run in runs(in: checked.kept, currentYear: currentYear) {
                if let row = AxisRow(labels: run, currentYear: currentYear) {
                    rows.append(row)
                } else {
                    unused += run
                }
            }
        }
        return Result(rows: rows, unusedLabels: unused)
    }

    /// Groups labels into lines: two labels share a line when their vertical centers differ by
    /// less than half the taller label's height.
    /// - Parameters:
    ///   - labels: The labels.
    /// - Returns: The lines, top to bottom, each sorted left to right.
    static func lines(from labels: [AxisLabel]) -> [[AxisLabel]] {
        var lines: [[AxisLabel]] = []
        for label in labels.sorted(by: { $0.box.midY < $1.box.midY }) {
            if let last = lines.last?.last, areOnSameLine(last.box, label.box) {
                lines[lines.count - 1].append(label)
            } else {
                lines.append([label])
            }
        }
        return lines.map { line in line.sorted { $0.box.midX < $1.box.midX } }
    }

    /// Whether two boxes sit on the same text line: their vertical centers differ by less than half the taller box's height.
    /// - Parameters:
    ///   - first: One box.
    ///   - second: The other box.
    /// - Returns: `true` when the boxes share a line.
    static func areOnSameLine(_ first: CGRect, _ second: CGRect) -> Bool {
        abs(first.midY - second.midY) < max(first.height, second.height) / 2
    }

    /// Sets aside labels whose time does not match their position. Ticks fall on exact multiples of the
    /// tick interval, so positions only decide how many ticks apart two labels are, and their times must
    /// differ by exactly that many ticks; recognized boxes can be off center by a good part of a tick
    /// without changing the count. A label is misread when it does not match its left neighbor while its
    /// right neighbor still does; the first label of a line, which has no left neighbor, is misread when
    /// it does not match its right neighbor.
    /// Predictions use the cadence of three consecutive ticks: the last three kept labels, or else the
    /// next three labels. Two labels are not enough, because the step between the last tick of one panel
    /// and the first tick of the next can match the step across a whole panel by coincidence. Without
    /// this check, a misread tick in the middle of an axis would form a two-label row with its right
    /// neighbor and be shifted to a wrong time.
    /// - Parameters:
    ///   - line: The line's labels, left to right.
    ///   - currentYear: The reference year for dated labels.
    /// - Returns: The labels kept and the labels set aside, each left to right.
    static func removingMisreadLabels(from line: [AxisLabel], currentYear: Int) -> (kept: [AxisLabel], misread: [AxisLabel]) {
        var kept: [AxisLabel] = []
        var misread: [AxisLabel] = []
        for (index, label) in line.enumerated() {
            let right = Array(line.dropFirst(index + 1).prefix(3))
            var isMisread = false
            if let cadence = cadence(of: Array(kept.suffix(3)), currentYear: currentYear) ?? cadence(of: right, currentYear: currentYear), let next = right.first {
                if let left = kept.last {
                    isMisread = !matches(from: left, to: label, cadence, currentYear: currentYear) && matches(from: left, to: next, cadence, currentYear: currentYear)
                } else {
                    isMisread = !matches(from: label, to: next, cadence, currentYear: currentYear)
                }
            }
            if isMisread {
                misread.append(label)
            } else {
                kept.append(label)
            }
        }
        return (kept, misread)
    }

    /// The cadence of three consecutive ticks. Grafana's ticks are exactly evenly spaced in time, so the
    /// two time steps must be equal, and the middle label must sit one tick from the first.
    /// - Parameters:
    ///   - labels: The labels, left to right.
    ///   - currentYear: The reference year for dated labels.
    /// - Returns: The cadence, or `nil` unless there are exactly three labels that form consecutive ticks.
    private static func cadence(of labels: [AxisLabel], currentYear: Int) -> Cadence? {
        guard labels.count == 3, let first = elapsedMinutes(from: labels[0], to: labels[1], currentYear: currentYear), let second = elapsedMinutes(from: labels[1], to: labels[2], currentYear: currentYear), abs(first - second) < 0.001 else {
            return nil
        }
        let distance = Double(labels[2].box.midX - labels[0].box.midX)
        guard distance > 0 else {
            return nil
        }
        let cadence = Cadence(minutesPerPixel: (first + second) / distance, tickMinutes: first)
        return matches(from: labels[0], to: labels[1], cadence, currentYear: currentYear) ? cadence : nil
    }

    /// Whether the time from one label to another is exactly the number of ticks their distance spans.
    /// - Parameters:
    ///   - left: The left label.
    ///   - right: The right label.
    ///   - cadence: The cadence to count ticks with.
    ///   - currentYear: The reference year for dated labels.
    /// - Returns: `true` when the labels are at least one tick apart and their times differ by that many ticks.
    private static func matches(from left: AxisLabel, to right: AxisLabel, _ cadence: Cadence, currentYear: Int) -> Bool {
        guard let minutes = elapsedMinutes(from: left, to: right, currentYear: currentYear) else {
            return false
        }
        let ticks = (cadence.minutesPerPixel * Double(right.box.midX - left.box.midX) / cadence.tickMinutes).rounded()
        return ticks >= 1 && abs(minutes - ticks * cadence.tickMinutes) < 0.001
    }

    /// Splits one line, sorted left to right, into runs of one kind with a constant minutes-per-pixel.
    /// The first two labels of a run set its cadence. A later label continues the run when its step is
    /// within `stepTolerance` of the cadence, or when its time is exactly the number of ticks its
    /// position spans, which keeps labels whose recognized boxes are a few pixels off center.
    /// - Parameters:
    ///   - line: The line's labels, left to right.
    ///   - currentYear: The reference year for dated labels.
    /// - Returns: The runs, left to right; single-label runs included.
    static func runs(in line: [AxisLabel], currentYear: Int) -> [[AxisLabel]] {
        guard let first = line.first else {
            return []
        }
        var runs: [[AxisLabel]] = []
        var current = [first]
        var cadence: Cadence?
        for label in line.dropFirst() {
            if let previous = current.last, let step = minutesPerPixel(from: previous, to: label, currentYear: currentYear) {
                guard let cadence else {
                    cadence = Cadence(minutesPerPixel: step, tickMinutes: step * Double(label.box.midX - previous.box.midX))
                    current.append(label)
                    continue
                }
                if abs(step - cadence.minutesPerPixel) <= stepTolerance * cadence.minutesPerPixel || matches(from: previous, to: label, cadence, currentYear: currentYear) {
                    current.append(label)
                    continue
                }
            }
            runs.append(current)
            current = [label]
            cadence = nil
        }
        runs.append(current)
        return runs
    }

    /// Keeps the labels that would belong to one of the rows: on the row's line, of its kind, and a whole
    /// number of the row's ticks from its nearest label, as their positions predict. A time in a tooltip
    /// or log line that happens to share an axis line does not fit.
    /// - Parameters:
    ///   - labels: The labels to filter.
    ///   - rows: The detected rows.
    ///   - currentYear: The reference year for dated labels.
    /// - Returns: The labels that fit a row.
    static func labelsFittingRows(_ labels: [AxisLabel], rows: [AxisRow], currentYear: Int) -> [AxisLabel] {
        labels.filter { label in
            rows.contains { fits(label, row: $0, currentYear: currentYear) }
        }
    }

    /// Whether a label would belong to a row.
    /// - Parameters:
    ///   - label: The label.
    ///   - row: The row.
    ///   - currentYear: The reference year for dated labels.
    /// - Returns: `true` when the label is on the row's line, of its kind, and a whole number of ticks from the row's nearest label.
    private static func fits(_ label: AxisLabel, row: AxisRow, currentYear: Int) -> Bool {
        let dates = row.timeline.dates
        guard let first = row.labels.first, let last = row.labels.last, let start = dates.first, let end = dates.last, first.kind == label.kind, areOnSameLine(first.box, label.box) else {
            return false
        }
        let distance = Double(last.box.midX - first.box.midX)
        guard distance > 0, let tick = zip(dates, dates.dropFirst()).map({ $1.timeIntervalSince($0) / 60 }).min(), let nearest = row.labels.min(by: { abs($0.box.midX - label.box.midX) < abs($1.box.midX - label.box.midX) }) else {
            return false
        }
        let cadence = Cadence(minutesPerPixel: end.timeIntervalSince(start) / 60 / distance, tickMinutes: tick)
        if nearest.box.midX < label.box.midX {
            return matches(from: nearest, to: label, cadence, currentYear: currentYear)
        }
        return matches(from: label, to: nearest, cadence, currentYear: currentYear)
    }

    /// The time difference between two neighboring labels divided by the pixel distance between their centers.
    /// - Parameters:
    ///   - left: The left label.
    ///   - right: The right label.
    ///   - currentYear: The reference year for dated labels.
    /// - Returns: Minutes per pixel, or `nil` when the labels differ in kind or are not in increasing order in time or in position.
    static func minutesPerPixel(from left: AxisLabel, to right: AxisLabel, currentYear: Int) -> Double? {
        let distance = Double(right.box.midX - left.box.midX)
        guard distance > 0, let minutes = elapsedMinutes(from: left, to: right, currentYear: currentYear) else {
            return nil
        }
        return minutes / distance
    }

    /// The minutes from one label's time to the next one's, as a row's timeline counts them.
    /// - Parameters:
    ///   - left: The earlier label.
    ///   - right: The later label.
    ///   - currentYear: The reference year for dated labels.
    /// - Returns: The minutes, or `nil` when the labels differ in kind or their times do not increase.
    private static func elapsedMinutes(from left: AxisLabel, to right: AxisLabel, currentYear: Int) -> Double? {
        guard left.kind == right.kind, let timeline = RowTimeline(labels: [left, right], currentYear: currentYear) else {
            return nil
        }
        return timeline.dates[1].timeIntervalSince(timeline.dates[0]) / 60
    }
}
