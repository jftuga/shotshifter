// End-to-end tests of the whole pipeline on a synthetic dark-theme axis. They draw
// evenly spaced 20:00-23:00 labels with Core Graphics and Core Text, shift them by +2
// hours, and read the output back with Vision to confirm the new labels are there; a
// stray label that produces a warning checks that --strict leaves the file unwritten
// and that --box outlines the axis in green and the stray label in red.

import AppKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import ShotShifter

/// End-to-end tests for `ImageShifter`.
struct EndToEndTests {
    /// The image width in pixels.
    private static let width = 1600
    /// The image height in pixels.
    private static let height = 400

    /// Draws a dark panel with a plot area and four evenly spaced axis labels.
    /// - Parameters:
    ///   - strayLabel: Whether to add a lone `14:00` above the plot, which belongs to no axis.
    /// - Returns: The synthetic screenshot.
    /// - Throws: An expectation failure when the bitmap cannot be created.
    private func makeAxisImage(strayLabel: Bool = false) throws -> CGImage {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(data: nil, width: Self.width, height: Self.height, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(srgbRed: 0.07, green: 0.07, blue: 0.09, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: Self.width, height: Self.height))
        context.setFillColor(CGColor(srgbRed: 0.12, green: 0.14, blue: 0.18, alpha: 1))
        context.fill(CGRect(x: 80, y: 120, width: Self.width - 120, height: 240))
        let font = NSFont.monospacedDigitSystemFont(ofSize: 28, weight: .regular) as CTFont
        let color = CGColor(srgbRed: 0.8, green: 0.8, blue: 0.86, alpha: 1)
        let attributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key(kCTFontAttributeName as String): font, NSAttributedString.Key(kCTForegroundColorAttributeName as String): color]
        var texts = ["20:00", "21:00", "22:00", "23:00"].enumerated().map { index, text in (text, CGPoint(x: 260 + CGFloat(index) * 360, y: 70)) }
        if strayLabel {
            texts.append(("14:00", CGPoint(x: 260, y: 370)))
        }
        for (text, center) in texts {
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
            let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
            context.textPosition = CGPoint(x: center.x - bounds.midX, y: center.y)
            CTLineDraw(line, context)
        }
        return try #require(context.makeImage())
    }

    /// Writes an image as a PNG file.
    /// - Parameters:
    ///   - image: The image.
    ///   - url: The file to write.
    /// - Throws: An expectation failure when the file cannot be written.
    private func writePNG(_ image: CGImage, to url: URL) throws {
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        try #require(CGImageDestinationFinalize(destination))
    }

    /// Shifting the synthetic axis by +2 hours yields labels that read 22:00, 23:00, 00:00 and 01:00.
    @Test func shiftsSyntheticDarkAxis() async throws {
        let result = try await ImageShifter(offset: try TimeOffset(parsing: "+2"), drawsBoxes: false).shift(try makeAxisImage())
        #expect(result.rowCount == 1 && result.labelCount == 4)
        #expect(result.warnings.isEmpty)
        let texts = try await TextRecognizer().recognize(result.image).flatMap { $0.text.split(separator: " ").map(String.init) }
        for expected in ["22:00", "23:00", "00:00", "01:00"] {
            #expect(texts.contains(expected))
        }
        #expect(!texts.contains("20:00") && !texts.contains("21:00"))
    }

    /// With `--strict` a file whose shift produces a warning is not written and the batch fails;
    /// without it the same file is written and the batch succeeds.
    @Test func strictLeavesFilesWithWarningsUnwritten() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appendingPathComponent("axis.png")
        try writePNG(try makeAxisImage(strayLabel: true), to: input)
        let output = OutputPath.shifted(input.path)
        let offset = try TimeOffset(parsing: "+2")
        #expect(await BatchProcessor(offset: offset, force: false, strict: true, box: false).run([input.path]) == 1)
        #expect(!FileManager.default.fileExists(atPath: output))
        #expect(await BatchProcessor(offset: offset, force: false, strict: false, box: false).run([input.path]) == 0)
        #expect(FileManager.default.fileExists(atPath: output))
    }

    /// With boxes on, green outlines appear only around the axis and red ones only around the stray label
    /// above the plot; with boxes off, neither color appears.
    @Test func boxesOutlineHandledAndWarnedLabels() async throws {
        let image = try makeAxisImage(strayLabel: true)
        let offset = try TimeOffset(parsing: "+2")
        let boxed = try await ImageShifter(offset: offset, drawsBoxes: true).shift(image)
        let rows = try TestSupport.outlineRows(in: boxed.image)
        #expect(!rows.green.isEmpty && rows.green.allSatisfy { $0 > 250 })
        #expect(!rows.red.isEmpty && rows.red.allSatisfy { $0 < 120 })
        let plain = try TestSupport.outlineRows(in: try await ImageShifter(offset: offset, drawsBoxes: false).shift(image).image)
        #expect(plain.green.isEmpty && plain.red.isEmpty)
    }

    /// `--box` is rejected together with `--strict`, which never writes a file that could carry red outlines.
    @Test func boxConflictsWithStrict() {
        #expect(throws: (any Error).self) {
            try ShotShifterCommand.parseAsRoot(["--box", "--strict", "-s", "+2", "axis.png"])
        }
    }
}
