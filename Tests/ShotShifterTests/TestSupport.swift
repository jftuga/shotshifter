// Shared helpers for the tests. They build observations, labels and rows from plain
// strings laid out evenly on one line, so tests can describe an axis the way it reads,
// and find the rows of an image that hold --box outline colors.

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
    ///   - fromTile: Whether the text was read in a tile pass.
    /// - Returns: The observation.
    static func observation(_ text: String, x: CGFloat, y: CGFloat = 500, fromTile: Bool = false) -> TextObservation {
        TextObservation(text: text, box: CGRect(x: x, y: y, width: CGFloat(text.count) * 10, height: 20), fromTile: fromTile)
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

    /// Finds the rows, top-left origin, that contain pure outline-green or outline-red pixels.
    /// - Parameters:
    ///   - image: The image to scan.
    /// - Returns: The rows holding green pixels and the rows holding red pixels.
    /// - Throws: An expectation failure when the bitmap cannot be created.
    static func outlineRows(in image: CGImage) throws -> (green: Set<Int>, red: Set<Int>) {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let pixels = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        var green: Set<Int> = []
        var red: Set<Int> = []
        for y in 0..<image.height {
            for x in 0..<image.width {
                let offset = (y * image.width + x) * 4
                let (r, g, b) = (pixels[offset], pixels[offset + 1], pixels[offset + 2])
                if g > 150 && r < 40 && b < 40 {
                    green.insert(y)
                } else if r > 200 && g < 40 && b < 40 {
                    red.insert(y)
                }
            }
        }
        return (green, red)
    }
}
