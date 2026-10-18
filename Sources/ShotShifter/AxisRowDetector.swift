// Detection of time axes among the parsed labels. Labels are grouped into lines by
// vertical position, and each line is split into rows of constant minutes-per-pixel,
// because Grafana spaces ticks evenly in both time and pixels. Panels side by side put
// several axes on one line; each becomes its own row.

import CoreGraphics
import Foundation

/// Finds the valid time axes among a set of labels.
enum AxisRowDetector {
    /// The largest relative difference in minutes-per-pixel allowed within one row.
    static let stepTolerance = 0.10

    /// The outcome of row detection.
    struct Result: Sendable, Equatable {
        /// The valid rows.
        let rows: [AxisRow]
        /// Labels that ended up in no valid row.
        let unusedLabels: [AxisLabel]
    }

    /// Groups labels into lines, splits lines into rows, and keeps the valid rows.
    /// - Parameters:
    ///   - labels: Every parsed label.
    ///   - currentYear: The reference year for dated labels.
    /// - Returns: The valid rows and the labels left over.
    static func detect(_ labels: [AxisLabel], currentYear: Int) -> Result {
        var rows: [AxisRow] = []
        var unused: [AxisLabel] = []
        for line in lines(from: labels) {
            for run in runs(in: line, currentYear: currentYear) {
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

    /// Splits one line, sorted left to right, into runs of one kind with a constant minutes-per-pixel.
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
        var runStep: Double?
        for label in line.dropFirst() {
            if let previous = current.last, label.kind == previous.kind, let step = minutesPerPixel(from: previous, to: label, currentYear: currentYear) {
                if let runStep {
                    if abs(step - runStep) <= stepTolerance * runStep {
                        current.append(label)
                        continue
                    }
                } else {
                    runStep = step
                    current.append(label)
                    continue
                }
            }
            runs.append(current)
            current = [label]
            runStep = nil
        }
        runs.append(current)
        return runs
    }

    /// The time difference between two neighboring labels divided by the pixel distance between their centers.
    /// - Parameters:
    ///   - left: The left label.
    ///   - right: The right label, of the same kind.
    ///   - currentYear: The reference year for dated labels.
    /// - Returns: Minutes per pixel, or `nil` when the labels are not in increasing order in time or in position.
    static func minutesPerPixel(from left: AxisLabel, to right: AxisLabel, currentYear: Int) -> Double? {
        let distance = Double(right.box.midX - left.box.midX)
        guard distance > 0, let timeline = RowTimeline(labels: [left, right], currentYear: currentYear) else {
            return nil
        }
        return timeline.dates[1].timeIntervalSince(timeline.dates[0]) / 60 / distance
    }
}
