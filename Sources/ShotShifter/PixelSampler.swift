// Pixel measurements around a label: the flat background color, the bounds of the text
// ink, and the text color. It reads a private copy of an 8-bit RGBA bitmap, so the
// measurements always describe the original image even after labels are erased.

import CoreGraphics

/// An 8-bit RGBA color as stored in the bitmap (premultiplied when the bitmap has alpha).
struct PixelColor: Hashable, Sendable {
    /// Red, 0-255.
    let red: UInt8
    /// Green, 0-255.
    let green: UInt8
    /// Blue, 0-255.
    let blue: UInt8
    /// Alpha, 0-255.
    let alpha: UInt8

    /// The color with every channel rounded to the nearest multiple of `step`, capped at 255.
    /// - Parameters:
    ///   - step: The rounding step.
    /// - Returns: The rounded color.
    func quantized(_ step: Int) -> PixelColor {
        let round = { (value: UInt8) -> UInt8 in UInt8(min(255, (Int(value) + step / 2) / step * step)) }
        return PixelColor(red: round(red), green: round(green), blue: round(blue), alpha: round(alpha))
    }

    /// The largest absolute difference across the four channels.
    /// - Parameters:
    ///   - other: The color to compare with.
    /// - Returns: The largest channel difference, 0-255.
    func maximumDifference(from other: PixelColor) -> Int {
        max(abs(Int(red) - Int(other.red)), abs(Int(green) - Int(other.green)), abs(Int(blue) - Int(other.blue)), abs(Int(alpha) - Int(other.alpha)))
    }

    /// The sum of absolute differences across the four channels.
    /// - Parameters:
    ///   - other: The color to compare with.
    /// - Returns: The summed difference.
    func summedDifference(from other: PixelColor) -> Int {
        abs(Int(red) - Int(other.red)) + abs(Int(green) - Int(other.green)) + abs(Int(blue) - Int(other.blue)) + abs(Int(alpha) - Int(other.alpha))
    }
}

/// What the sampler learned about one label.
struct InkMeasurement: Sendable, Equatable {
    /// The most common color on the measured box's border.
    let background: PixelColor
    /// The tightest pixel rectangle around all ink, top-left origin.
    let inkBounds: CGRect
    /// The rectangle to cover with the background: the ink plus padding for anti-aliased edges, never reaching a line.
    let eraseBounds: CGRect
    /// The most common color among the ink pixels farthest from the background.
    let textColor: PixelColor
}

/// Reads colors from a snapshot of an RGBA bitmap.
struct PixelSampler {
    /// Background colors are rounded to multiples of this before counting.
    static let quantizationStep = 4
    /// A pixel is ink when one channel differs from the background by more than this.
    static let inkThreshold = 48
    /// The fraction of ink pixels, farthest from the background, used to pick the text color.
    static let textColorFraction = 0.10

    /// The bitmap bytes, four per pixel in RGBA order.
    private let bytes: [UInt8]
    /// The bitmap width in pixels.
    private let width: Int
    /// The bitmap height in pixels.
    private let height: Int
    /// The number of bytes per row.
    private let bytesPerRow: Int
    /// Whether the fourth byte is alpha; in an opaque bitmap it is unused padding.
    private let hasAlpha: Bool

    /// Copies the pixels of an 8-bit, four-channel RGBA bitmap context.
    /// - Parameters:
    ///   - context: The bitmap context, with red first and 32 bits per pixel, either premultiplied alpha or padding last.
    /// - Returns: `nil` when the context has no accessible pixel data.
    init?(context: CGContext) {
        guard let data = context.data, context.bitsPerPixel == 32 else {
            return nil
        }
        width = context.width
        height = context.height
        bytesPerRow = context.bytesPerRow
        hasAlpha = context.alphaInfo == .premultipliedLast
        bytes = Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: bytesPerRow * height))
    }

    /// Measures the label inside a box. A row whose ink runs from the box's left edge to its right edge is a line
    /// (such as an axis line), not text. Ink rows are taken from the text rows inside `core`, extended up and down
    /// while neighboring rows are also text rows, so a chart or line next to the label is not mistaken for part of it.
    /// - Parameters:
    ///   - rect: The box to measure, in pixels with a top-left origin; it is clamped to the image.
    ///   - core: The recognized text box, which seeds the ink rows.
    ///   - sidePadding: The erase area extends left and right by this fraction of the ink height.
    ///   - verticalPadding: The erase area extends up and down by this fraction of the ink height, stopping short of lines.
    /// - Returns: The measurement, or `nil` when the box is empty or the core holds no text ink.
    func measure(in rect: CGRect, core: CGRect, sidePadding: CGFloat, verticalPadding: CGFloat) -> InkMeasurement? {
        let area = rect.integral.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard !area.isNull, area.width > 0, area.height > 0 else {
            return nil
        }
        let minX = Int(area.minX), maxX = Int(area.maxX) - 1, minY = Int(area.minY), maxY = Int(area.maxY) - 1
        var border: [PixelColor] = []
        for x in minX...maxX {
            border.append(color(x: x, y: minY))
            border.append(color(x: x, y: maxY))
        }
        for y in minY...maxY {
            border.append(color(x: minX, y: y))
            border.append(color(x: maxX, y: y))
        }
        guard let background = Self.mostCommon(border.map { $0.quantized(Self.quantizationStep) }) else {
            return nil
        }
        var inkByRow: [Int: [(x: Int, color: PixelColor)]] = [:]
        for y in minY...maxY {
            for x in minX...maxX {
                let pixel = color(x: x, y: y)
                if pixel.maximumDifference(from: background) > Self.inkThreshold {
                    inkByRow[y, default: []].append((x, pixel))
                }
            }
        }
        let lineRows = Set(inkByRow.filter { $0.value.first?.x == minX && $0.value.last?.x == maxX }.keys)
        let isTextRow = { (y: Int) -> Bool in inkByRow[y] != nil && !lineRows.contains(y) }
        let seedTop = max(minY, Int(core.minY))
        let seedBottom = min(maxY, Int(core.maxY) - 1)
        guard seedTop <= seedBottom, let seed = Self.longestRun(in: seedTop...seedBottom, where: isTextRow) else {
            return nil
        }
        var inkMinY = seed.lowerBound
        var inkMaxY = seed.upperBound
        while isTextRow(inkMinY - 1) {
            inkMinY -= 1
        }
        while isTextRow(inkMaxY + 1) {
            inkMaxY += 1
        }
        let ink = (inkMinY...inkMaxY).flatMap { inkByRow[$0] ?? [] }
        guard let inkMinX = ink.map(\.x).min(), let inkMaxX = ink.map(\.x).max() else {
            return nil
        }
        let strongest = ink.map(\.color).sorted { $0.summedDifference(from: background) > $1.summedDifference(from: background) }
        let count = max(1, Int(Double(strongest.count) * Self.textColorFraction))
        guard let textColor = Self.mostCommon(strongest.prefix(count).map { $0.quantized(Self.quantizationStep) }) else {
            return nil
        }
        let inkHeight = CGFloat(inkMaxY - inkMinY + 1)
        let padX = Int((inkHeight * sidePadding).rounded(.up))
        let padY = Int((inkHeight * verticalPadding).rounded(.up))
        let eraseTop = max(inkMinY - padY, (lineRows.filter { $0 < inkMinY }.max() ?? Int.min) + 1)
        let eraseBottom = min(inkMaxY + padY, (lineRows.filter { $0 > inkMaxY }.min() ?? Int.max) - 1)
        return InkMeasurement(
            background: background,
            inkBounds: CGRect(x: inkMinX, y: inkMinY, width: inkMaxX - inkMinX + 1, height: inkMaxY - inkMinY + 1),
            eraseBounds: CGRect(x: inkMinX - padX, y: eraseTop, width: inkMaxX - inkMinX + 1 + 2 * padX, height: eraseBottom - eraseTop + 1),
            textColor: textColor
        )
    }

    /// Finds the longest run of consecutive rows that pass a test; the first such run wins a tie.
    /// Text from a neighboring line that reaches into the recognized box forms a shorter, separate run.
    /// - Parameters:
    ///   - rows: The rows to search.
    ///   - isIncluded: The test.
    /// - Returns: The longest run, or `nil` when no row passes.
    private static func longestRun(in rows: ClosedRange<Int>, where isIncluded: (Int) -> Bool) -> ClosedRange<Int>? {
        var best: ClosedRange<Int>?
        var start: Int?
        for row in rows.lowerBound...(rows.upperBound + 1) {
            if row <= rows.upperBound && isIncluded(row) {
                start = start ?? row
            } else if let runStart = start {
                if (best?.count ?? 0) < row - runStart {
                    best = runStart...(row - 1)
                }
                start = nil
            }
        }
        return best
    }

    /// Reads one pixel.
    /// - Parameters:
    ///   - x: The column.
    ///   - y: The row, counted from the top.
    /// - Returns: The pixel's color; alpha is 255 in an opaque bitmap.
    private func color(x: Int, y: Int) -> PixelColor {
        let offset = y * bytesPerRow + x * 4
        return PixelColor(red: bytes[offset], green: bytes[offset + 1], blue: bytes[offset + 2], alpha: hasAlpha ? bytes[offset + 3] : 255)
    }

    /// The most frequent color in a list; ties go to the color seen first.
    /// - Parameters:
    ///   - colors: The colors to count.
    /// - Returns: The most common color, or `nil` for an empty list.
    static func mostCommon(_ colors: [PixelColor]) -> PixelColor? {
        var counts: [PixelColor: Int] = [:]
        var best: PixelColor?
        for color in colors {
            counts[color, default: 0] += 1
            if let current = best, counts[current, default: 0] >= counts[color, default: 0] {
                continue
            }
            best = color
        }
        return best
    }
}
