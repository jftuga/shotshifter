// Review outlines for --box, drawn over a finished image. Every label that was handled
// gets a green outline and every box a warning refers to gets a red one instead. An axis
// label without any outline was not shifted, so the outlines also show misses that
// produce no warning; a green outline means a label was shifted, not that it was read right.

import CoreGraphics

/// Outlines handled labels and warnings on a copy of an image.
enum BoxMarker {
    /// The outline color for handled labels.
    static let handledColor = CGColor(srgbRed: 0, green: 0.8, blue: 0, alpha: 1)
    /// The outline color for warnings.
    static let warningColor = CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
    /// The line width as a fraction of the box height, so outlines scale with the screenshot's resolution.
    static let lineWidthFraction: CGFloat = 0.15
    /// The thinnest line drawn, in pixels.
    static let minimumLineWidth: CGFloat = 2

    /// Draws the outlines on a copy of the image. A box that is both handled and warned about is outlined in red only.
    /// - Parameters:
    ///   - image: The finished image.
    ///   - handled: The boxes of labels that were shifted or already correct, top-left origin.
    ///   - warned: The boxes warnings refer to, top-left origin.
    /// - Returns: The outlined image.
    /// - Throws: `ShotShifterError.renderFailed` when a bitmap cannot be created.
    static func mark(_ image: CGImage, handled: [CGRect], warned: [CGRect]) throws -> CGImage {
        let handledOnly = handled.filter { !warned.contains($0) }
        let all = handledOnly + warned
        let context = try LabelRenderer.makeContext(for: image)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        context.translateBy(x: 0, y: CGFloat(image.height))
        context.scaleBy(x: 1, y: -1)
        context.setFillColor(handledColor)
        for box in handledOnly {
            context.fill(edges(of: box, among: all))
        }
        context.setFillColor(warningColor)
        for box in warned {
            context.fill(edges(of: box, among: all))
        }
        guard let output = context.makeImage() else {
            throw ShotShifterError.renderFailed
        }
        return output
    }

    /// The pixel-aligned edges of one outline, with its inner edge about half a line width outside the box so it does
    /// not cover the text. The top and bottom are always drawn; a side is left out when it would cross another outlined
    /// box, because on crowded axes labels nearly touch and a side would cover the neighbor's text.
    /// - Parameters:
    ///   - box: The box to outline, top-left origin.
    ///   - all: Every box being outlined.
    /// - Returns: The rectangles to fill, top-left origin.
    static func edges(of box: CGRect, among all: [CGRect]) -> [CGRect] {
        let width = max(minimumLineWidth, (box.height * lineWidthFraction).rounded())
        let inner = box.insetBy(dx: -(width / 2).rounded(.up), dy: -(width / 2).rounded(.up)).integral
        let outer = inner.insetBy(dx: -width, dy: -width)
        let top = CGRect(x: outer.minX, y: outer.minY, width: outer.width, height: width)
        let bottom = CGRect(x: outer.minX, y: inner.maxY, width: outer.width, height: width)
        let sides = [CGRect(x: outer.minX, y: outer.minY, width: width, height: outer.height), CGRect(x: inner.maxX, y: outer.minY, width: width, height: outer.height)]
        return [top, bottom] + sides.filter { side in !all.contains { $0 != box && $0.intersects(side) } }
    }
}
