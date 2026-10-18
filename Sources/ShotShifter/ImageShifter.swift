// The processing pipeline for one image: recognize text, parse labels, find axis rows,
// shift them, find time zone words, and redraw. It works on an in-memory image and
// returns the new image with counts and warnings; file handling lives elsewhere.

import CoreGraphics
import Foundation

/// Shifts the X-axis labels of one image.
struct ImageShifter {
    /// The outcome of shifting one image.
    struct Result {
        /// The new image.
        let image: CGImage
        /// The number of labels in valid rows.
        let labelCount: Int
        /// The number of valid rows.
        let rowCount: Int
        /// Warnings to report for this file.
        let warnings: [String]
    }

    /// The amount to add to every label.
    let offset: TimeOffset

    /// Runs the pipeline on one image.
    /// - Parameters:
    ///   - image: The original image.
    /// - Returns: The new image, counts and warnings.
    /// - Throws: `ShotShifterError.noTimeAxis` when no row is found, or any recognition or rendering error.
    func shift(_ image: CGImage) async throws -> Result {
        let observations = try await TextRecognizer().recognize(image)
        let labels = LabelParser.labels(in: observations)
        let currentYear = RowTimeline.calendar.component(.year, from: .now)
        let detection = AxisRowDetector.detect(labels, currentYear: currentYear)
        guard !detection.rows.isEmpty else {
            throw ShotShifterError.noTimeAxis
        }
        var warnings = detection.unusedLabels
            .sorted { ($0.box.minY, $0.box.minX) < ($1.box.minY, $1.box.minX) }
            .map { "label \"\($0.text)\" is not part of a recognized axis and was left unchanged" }
        var replacements: [LabelReplacement] = []
        for (index, row) in detection.rows.enumerated() {
            for (label, text) in zip(row.labels, LabelShifter.shiftedTexts(for: row, offset: offset)) where text != label.text {
                replacements.append(LabelReplacement(box: label.box, oldText: label.text, newText: text, placement: .axis(row: index)))
            }
        }
        let zones = TimeZoneLabelFinder.find(in: observations, offset: offset)
        warnings += zones.warnings
        let rendered = try LabelRenderer(imageHeight: image.height).render(image, replacements: replacements + zones.replacements)
        return Result(image: rendered.image, labelCount: detection.rows.reduce(0) { $0 + $1.labels.count }, rowCount: detection.rows.count, warnings: warnings + rendered.warnings)
    }
}
