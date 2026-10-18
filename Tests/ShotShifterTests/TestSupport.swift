// Shared helpers for the logic tests. They build observations, labels and rows from plain
// strings laid out evenly on one line, so tests can describe an axis the way it reads.

import CoreGraphics
import Testing
@testable import ShotShifter

/// Builders for test inputs.
enum TestSupport {
    /// The reference year used by every timeline test.
    static let year = 2026

    /// Creates an observation whose characters are each 10 pixels wide.
    /// - Parameters:
    ///   - text: The recognized text.
    ///   - x: The left edge in pixels.
    ///   - y: The top edge in pixels.
    /// - Returns: The observation.
    static func observation(_ text: String, x: CGFloat, y: CGFloat = 500) -> TextObservation {
        TextObservation(text: text, box: CGRect(x: x, y: y, width: CGFloat(text.count) * 10, height: 20))
    }

    /// Parses evenly spaced labels on one line, one observation per label.
    /// - Parameters:
    ///   - texts: The label texts, left to right.
    ///   - startX: The left edge of the first label.
    ///   - spacing: The distance between neighboring labels' left edges.
    ///   - y: The top edge of the line.
    /// - Returns: The parsed labels.
    static func labels(_ texts: [String], startX: CGFloat = 100, spacing: CGFloat = 150, y: CGFloat = 500) -> [AxisLabel] {
        texts.enumerated().flatMap { index, text in
            LabelParser.labels(in: observation(text, x: startX + CGFloat(index) * spacing, y: y))
        }
    }

    /// Builds a validated row from label texts.
    /// - Parameters:
    ///   - texts: The label texts, left to right.
    /// - Returns: The row.
    /// - Throws: An expectation failure when the labels do not form a valid row.
    static func row(_ texts: [String]) throws -> AxisRow {
        let labels = labels(texts)
        try #require(labels.count == texts.count)
        return try #require(AxisRow(labels: labels, currentYear: year))
    }
}
