// Erasing and redrawing labels on a copy of the image. Every label is measured on the
// original pixels first, then all old labels are covered with their background color,
// then all new labels are drawn with Core Text in the system font, sized and colored to
// match the original ink. Axis labels on one line share the line's median size and
// baseline and its most common color. Layout uses top-left pixel coordinates until the moment of drawing.

import AppKit
import CoreGraphics
import CoreText
import Foundation

/// Draws replacement labels onto an image.
struct LabelRenderer {
    /// Recognized boxes are expanded by this fraction of their height to find the area to measure, and measured ink
    /// by this fraction of its height to find the area to erase, covering anti-aliased edges.
    static let padding: CGFloat = 0.25
    /// Time zone words use only this fraction left and right, so neighboring words in the same line survive.
    static let timeZoneSidePadding: CGFloat = 0.10

    /// The rendered image, where new labels were drawn, and any warnings.
    struct Result {
        /// The new image.
        let image: CGImage
        /// The glyph bounds of every new label drawn, top-left origin.
        let drawnBoxes: [CGRect]
        /// Warnings about labels that may overlap or could not be measured.
        let warnings: [ShiftWarning]
    }

    /// A replacement together with what was measured about the original label.
    private struct Measured {
        /// The job being drawn.
        let replacement: LabelReplacement
        /// The original label's colors, ink and erase bounds.
        let measurement: InkMeasurement
    }

    /// The font size, baseline and color used to draw one label.
    private struct TextStyle {
        /// The point size, equal to pixels in the bitmap.
        let size: CGFloat
        /// The baseline's y coordinate, top-left origin.
        let baseline: CGFloat
        /// The text color.
        let color: PixelColor
    }

    /// Everything needed to erase and draw one label.
    private struct Layout {
        /// The job being drawn.
        let replacement: LabelReplacement
        /// The rectangle to cover with the background, top-left origin.
        let eraseRect: CGRect
        /// The original label's colors and ink bounds.
        let measurement: InkMeasurement
        /// The font at its chosen size.
        let font: CTFont
        /// The text color.
        let color: PixelColor
        /// The left end of the baseline, top-left origin.
        let origin: CGPoint
        /// The new text's glyph bounds where it will be drawn, top-left origin.
        let drawnRect: CGRect
    }

    /// The image height, used to flip top-left coordinates for Core Graphics.
    private let imageHeight: CGFloat

    /// Creates a renderer for an image of a given height.
    /// - Parameters:
    ///   - imageHeight: The image height in pixels.
    init(imageHeight: Int) {
        self.imageHeight = CGFloat(imageHeight)
    }

    /// Measures, erases and redraws every replacement on a copy of the image.
    /// - Parameters:
    ///   - image: The original image.
    ///   - replacements: The labels to replace.
    /// - Returns: The new image, where new labels were drawn, and any warnings.
    /// - Throws: `ShotShifterError.renderFailed` when a bitmap cannot be created.
    func render(_ image: CGImage, replacements: [LabelReplacement]) throws -> Result {
        let context = try Self.makeContext(for: image)
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.draw(image, in: bounds)
        guard let sampler = PixelSampler(context: context) else {
            throw ShotShifterError.renderFailed
        }
        var warnings: [ShiftWarning] = []
        var measured: [Measured] = []
        for replacement in replacements {
            let sidePadding = replacement.placement == .timeZone ? Self.timeZoneSidePadding : Self.padding
            let box = replacement.box
            let measureRect = Self.clipped(box.insetBy(dx: -box.height * sidePadding, dy: -box.height * Self.padding), around: replacement, among: replacements)
            guard let measurement = sampler.measure(in: measureRect, core: box, sidePadding: sidePadding, verticalPadding: Self.padding) else {
                warnings.append(ShiftWarning(message: "label \"\(replacement.oldText)\" could not be measured and was left unchanged", boxes: [box]))
                continue
            }
            measured.append(Measured(replacement: replacement, measurement: measurement))
        }
        let layouts = zip(measured, Self.styles(for: measured)).map { item, style in
            Self.layout(item, style: style, eraseRect: item.measurement.eraseBounds.intersection(bounds))
        }
        warnings += Self.fitWarnings(layouts)
        for layout in layouts {
            context.setFillColor(Self.cgColor(layout.measurement.background, in: context))
            context.fill(bottomLeft(layout.eraseRect))
        }
        for layout in layouts {
            draw(layout, in: context)
        }
        guard let output = context.makeImage() else {
            throw ShotShifterError.renderFailed
        }
        return Result(image: output, drawnBoxes: layouts.map(\.drawnRect), warnings: warnings)
    }

    /// Creates an 8-bit RGBA bitmap the size of the image, in its color space (sRGB if it has none or a non-RGB one),
    /// with alpha only when the image has alpha.
    /// - Parameters:
    ///   - image: The source image.
    /// - Returns: The bitmap context.
    /// - Throws: `ShotShifterError.renderFailed` when the context cannot be created.
    static func makeContext(for image: CGImage) throws -> CGContext {
        let opaque: Set<CGImageAlphaInfo> = [.none, .noneSkipFirst, .noneSkipLast]
        let alphaInfo: CGImageAlphaInfo = opaque.contains(image.alphaInfo) ? .noneSkipLast : .premultipliedLast
        let space = image.colorSpace.flatMap { $0.model == .rgb ? $0 : nil } ?? CGColorSpace(name: CGColorSpace.sRGB)
        guard let space, let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: alphaInfo.rawValue) else {
            throw ShotShifterError.renderFailed
        }
        return context
    }

    /// Narrows a measuring box so it does not reach into the original boxes of neighboring labels in the same row,
    /// which keeps a neighbor's ink out of this label's ink bounds when labels sit close together.
    /// - Parameters:
    ///   - rect: The expanded box.
    ///   - replacement: The label being measured.
    ///   - replacements: All replacements.
    /// - Returns: The measuring box.
    private static func clipped(_ rect: CGRect, around replacement: LabelReplacement, among replacements: [LabelReplacement]) -> CGRect {
        guard case .axis = replacement.placement else {
            return rect
        }
        var minX = rect.minX
        var maxX = rect.maxX
        for other in replacements where other.placement == replacement.placement && other != replacement {
            if other.box.maxX <= replacement.box.minX {
                minX = max(minX, other.box.maxX)
            } else if other.box.minX >= replacement.box.maxX {
                maxX = min(maxX, other.box.minX)
            }
        }
        return CGRect(x: minX, y: rect.minY, width: maxX - minX, height: rect.height)
    }

    /// Chooses each label's style. A label's own style matches its ink height and baseline; axis labels on one line
    /// then share the line's median size and baseline and its most common text color, because axes are drawn in one
    /// style and a single label's measurement can be thrown off by something drawn over it.
    /// - Parameters:
    ///   - measured: The measured labels.
    /// - Returns: One style per measured label.
    private static func styles(for measured: [Measured]) -> [TextStyle] {
        let own = measured.map(ownStyle)
        return measured.indices.map { index in
            let replacement = measured[index].replacement
            guard case .axis = replacement.placement else {
                return own[index]
            }
            let line = measured.indices.filter { other in
                measured[other].replacement.placement != .timeZone && AxisRowDetector.areOnSameLine(measured[other].replacement.box, replacement.box)
            }.map { own[$0] }
            return TextStyle(size: median(line.map(\.size)), baseline: median(line.map(\.baseline)), color: PixelSampler.mostCommon(line.map(\.color)) ?? own[index].color)
        }
    }

    /// Derives a label's style from its own measurement: the size whose glyph ink matches the original ink height,
    /// and the baseline placed as far above the ink bottom as the original text's glyphs extend below their baseline.
    /// - Parameters:
    ///   - item: The measured label.
    /// - Returns: The label's own style.
    private static func ownStyle(_ item: Measured) -> TextStyle {
        let ink = item.measurement.inkBounds
        let size = fontSize(matching: item.replacement.oldText, inkHeight: ink.height)
        let oldBounds = glyphBounds(item.replacement.oldText, font: font(size: size))
        return TextStyle(size: size, baseline: ink.maxY + oldBounds.minY, color: item.measurement.textColor)
    }

    /// Places the new text: axis labels centered on the original ink, time zone words starting at its left edge.
    /// - Parameters:
    ///   - item: The measured label.
    ///   - style: The size, baseline and color to use.
    ///   - eraseRect: The rectangle that will be erased.
    /// - Returns: The layout.
    private static func layout(_ item: Measured, style: TextStyle, eraseRect: CGRect) -> Layout {
        let ink = item.measurement.inkBounds
        let font = font(size: style.size)
        let newBounds = glyphBounds(item.replacement.newText, font: font)
        let x = item.replacement.placement == .timeZone ? ink.minX - newBounds.minX : ink.midX - newBounds.midX
        let drawnRect = CGRect(x: x + newBounds.minX, y: style.baseline - newBounds.maxY, width: newBounds.width, height: newBounds.height)
        return Layout(replacement: item.replacement, eraseRect: eraseRect, measurement: item.measurement, font: font, color: style.color, origin: CGPoint(x: x, y: style.baseline), drawnRect: drawnRect)
    }

    /// The median of a non-empty list of values.
    /// - Parameters:
    ///   - values: The values.
    /// - Returns: The middle value, or the mean of the two middle values.
    private static func median(_ values: [CGFloat]) -> CGFloat {
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
    }

    /// The system font with monospaced digits, regular weight, as a Core Text font.
    /// - Parameters:
    ///   - size: The point size.
    /// - Returns: The font.
    private static func font(size: CGFloat) -> CTFont {
        NSFont.monospacedDigitSystemFont(ofSize: size, weight: .regular) as CTFont
    }

    /// Finds the point size at which the given text's glyph ink is the given height.
    /// The text is measured at 1 point and the size is then refined once at the estimated size,
    /// because the system font's shapes change slightly with size.
    /// - Parameters:
    ///   - text: The original label text.
    ///   - inkHeight: The original ink height in pixels.
    /// - Returns: The point size.
    private static func fontSize(matching text: String, inkHeight: CGFloat) -> CGFloat {
        var size: CGFloat = 1
        for _ in 0..<2 {
            let height = glyphBounds(text, font: font(size: size)).height
            guard height > 0 else {
                return size
            }
            size *= inkHeight / height
        }
        return size
    }

    /// Measures the glyph ink bounds of a line of text relative to its baseline origin (y up).
    /// - Parameters:
    ///   - text: The text.
    ///   - font: The font.
    /// - Returns: The glyph path bounds.
    private static func glyphBounds(_ text: String, font: CTFont) -> CGRect {
        CTLineGetBoundsWithOptions(line(text, font: font, color: nil), .useGlyphPathBounds)
    }

    /// Lays out a line of text.
    /// - Parameters:
    ///   - text: The text.
    ///   - font: The font.
    ///   - color: The text color, or `nil` when only measuring.
    /// - Returns: The Core Text line.
    private static func line(_ text: String, font: CTFont, color: CGColor?) -> CTLine {
        var attributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key(kCTFontAttributeName as String): font]
        if let color {
            attributes[NSAttributedString.Key(kCTForegroundColorAttributeName as String)] = color
        }
        return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    }

    /// Checks whether new labels fit: an axis label must not overlap its row neighbors once widened by half
    /// its ink height on each side, and a time zone word should be no wider than the one it replaces.
    /// - Parameters:
    ///   - layouts: All layouts.
    /// - Returns: One warning per label that may overlap, at its new glyph bounds.
    private static func fitWarnings(_ layouts: [Layout]) -> [ShiftWarning] {
        var warnings: [ShiftWarning] = []
        for layout in layouts {
            let ink = layout.measurement.inkBounds
            switch layout.replacement.placement {
            case .timeZone:
                if layout.drawnRect.width > ink.width {
                    warnings.append(ShiftWarning(message: "time zone label \"\(layout.replacement.newText)\" may overlap the text after it", boxes: [layout.drawnRect]))
                }
            case .axis:
                let row = layouts.filter { $0.replacement.placement == layout.replacement.placement }.sorted { $0.drawnRect.midX < $1.drawnRect.midX }
                guard let index = row.firstIndex(where: { $0.replacement == layout.replacement }) else {
                    continue
                }
                let widened = layout.drawnRect.insetBy(dx: -ink.height / 2, dy: 0)
                let neighbors = [index - 1, index + 1].filter { row.indices.contains($0) }.map { row[$0].drawnRect }
                if neighbors.contains(where: { $0.minX < widened.maxX && widened.minX < $0.maxX }) {
                    warnings.append(ShiftWarning(message: "label \"\(layout.replacement.newText)\" may overlap its neighbor", boxes: [layout.drawnRect]))
                }
            }
        }
        return warnings
    }

    /// Draws one new label with anti-aliasing and font smoothing in its sampled color.
    /// - Parameters:
    ///   - layout: The label's layout.
    ///   - context: The bitmap context.
    private func draw(_ layout: Layout, in context: CGContext) {
        let line = Self.line(layout.replacement.newText, font: layout.font, color: Self.cgColor(layout.color, in: context))
        context.saveGState()
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.setAllowsFontSmoothing(true)
        context.setShouldSmoothFonts(true)
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: layout.origin.x, y: bottomLeftY(layout.origin.y))
        CTLineDraw(line, context)
        context.restoreGState()
    }

    /// Converts a rectangle from top-left to bottom-left pixel coordinates.
    /// - Parameters:
    ///   - rect: The rectangle, top-left origin.
    /// - Returns: The rectangle, bottom-left origin.
    private func bottomLeft(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: bottomLeftY(rect.maxY), width: rect.width, height: rect.height)
    }

    /// Converts a y coordinate from a top-left origin to Core Graphics' bottom-left origin; the only such conversion.
    /// - Parameters:
    ///   - yTopLeft: The y coordinate measured from the top.
    /// - Returns: The y coordinate measured from the bottom.
    private func bottomLeftY(_ yTopLeft: CGFloat) -> CGFloat {
        imageHeight - yTopLeft
    }

    /// Converts a sampled bitmap color to a `CGColor` in the context's color space, undoing premultiplied alpha.
    /// - Parameters:
    ///   - color: The sampled color.
    ///   - context: The bitmap context the color came from.
    /// - Returns: The color, full opacity for opaque bitmaps.
    private static func cgColor(_ color: PixelColor, in context: CGContext) -> CGColor {
        let alpha = context.alphaInfo == .premultipliedLast ? CGFloat(color.alpha) / 255 : 1
        let scale = alpha > 0 ? 255 * alpha : 255
        let components = [CGFloat(color.red) / scale, CGFloat(color.green) / scale, CGFloat(color.blue) / scale, alpha]
        let space = context.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        return CGColor(colorSpace: space, components: components) ?? CGColor(red: components[0], green: components[1], blue: components[2], alpha: alpha)
    }
}
