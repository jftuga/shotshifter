// An end-to-end test of the whole pipeline on a synthetic dark-theme axis. It draws
// evenly spaced 20:00-23:00 labels with Core Graphics and Core Text, shifts them by +2
// hours, and reads the output back with Vision to confirm the new labels are there.

import AppKit
import CoreGraphics
import CoreText
import Foundation
import Testing
@testable import ShotShifter

/// End-to-end tests for `ImageShifter`.
struct EndToEndTests {
    /// The image width in pixels.
    private static let width = 1600
    /// The image height in pixels.
    private static let height = 400

    /// Draws a dark panel with a plot area and four evenly spaced axis labels.
    /// - Returns: The synthetic screenshot.
    /// - Throws: An expectation failure when the bitmap cannot be created.
    private func makeAxisImage() throws -> CGImage {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(data: nil, width: Self.width, height: Self.height, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(srgbRed: 0.07, green: 0.07, blue: 0.09, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: Self.width, height: Self.height))
        context.setFillColor(CGColor(srgbRed: 0.12, green: 0.14, blue: 0.18, alpha: 1))
        context.fill(CGRect(x: 80, y: 120, width: Self.width - 120, height: 240))
        let font = NSFont.monospacedDigitSystemFont(ofSize: 28, weight: .regular) as CTFont
        let color = CGColor(srgbRed: 0.8, green: 0.8, blue: 0.86, alpha: 1)
        for (index, text) in ["20:00", "21:00", "22:00", "23:00"].enumerated() {
            let attributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key(kCTFontAttributeName as String): font, NSAttributedString.Key(kCTForegroundColorAttributeName as String): color]
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
            let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
            context.textPosition = CGPoint(x: 260 + CGFloat(index) * 360 - bounds.midX, y: 70)
            CTLineDraw(line, context)
        }
        return try #require(context.makeImage())
    }

    /// Shifting the synthetic axis by +2 hours yields labels that read 22:00, 23:00, 00:00 and 01:00.
    @Test func shiftsSyntheticDarkAxis() async throws {
        let result = try await ImageShifter(offset: try TimeOffset(parsing: "+2")).shift(try makeAxisImage())
        #expect(result.rowCount == 1 && result.labelCount == 4)
        #expect(result.warnings.isEmpty)
        let texts = try await TextRecognizer().recognize(result.image).flatMap { $0.text.split(separator: " ").map(String.init) }
        for expected in ["22:00", "23:00", "00:00", "01:00"] {
            #expect(texts.contains(expected))
        }
        #expect(!texts.contains("20:00") && !texts.contains("21:00"))
    }
}
