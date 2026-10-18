// One piece of text recognized by Vision, already converted to integer pixel coordinates
// with a top-left origin. This is the only place Vision's normalized, bottom-left
// rectangles are converted, including the boxes of substrings inside merged observations.

import CoreGraphics
import Vision

/// A recognized string with its pixel box and a way to locate substrings within it.
struct TextObservation: Sendable {
    /// The recognized text, exactly as Vision returned it.
    let text: String

    /// The bounding box in pixels, top-left origin.
    let box: CGRect

    /// Vision's confidence in the text, from 0 to 1.
    let confidence: Float

    /// The Vision candidate, used to find substring boxes; `nil` for observations built in code.
    private let candidate: RecognizedText?

    /// The pixel rectangle of the image region that was recognized, top-left origin.
    private let region: CGRect

    /// Creates an observation from a Vision result.
    /// - Parameters:
    ///   - observation: The Vision observation.
    ///   - region: The pixel rectangle (top-left origin) of the image region Vision ran on.
    /// - Returns: `nil` when the observation has no candidate text.
    init?(observation: RecognizedTextObservation, region: CGRect) {
        guard let candidate = observation.topCandidates(1).first else {
            return nil
        }
        self.text = candidate.string
        self.confidence = candidate.confidence
        self.candidate = candidate
        self.region = region
        self.box = Self.pixelRect(observation.boundingBox, in: region)
    }

    /// Creates an observation without a Vision candidate; substring boxes are then estimated
    /// by assuming every character has the same width.
    /// - Parameters:
    ///   - text: The text.
    ///   - box: The pixel box, top-left origin.
    ///   - confidence: The recognition confidence.
    init(text: String, box: CGRect, confidence: Float = 1) {
        self.text = text
        self.box = box
        self.confidence = confidence
        self.candidate = nil
        self.region = .zero
    }

    /// Returns the pixel box of a substring of `text`.
    /// - Parameters:
    ///   - range: A range of indices into `text`.
    /// - Returns: The substring's box in pixels, top-left origin.
    func box(for range: Range<String.Index>) -> CGRect {
        if let candidate, let rectangle = candidate.boundingBox(for: range) {
            return Self.pixelRect(rectangle.boundingBox, in: region)
        }
        let unit = box.width / CGFloat(max(text.count, 1))
        let start = CGFloat(text.distance(from: text.startIndex, to: range.lowerBound))
        let length = CGFloat(text.distance(from: range.lowerBound, to: range.upperBound))
        return CGRect(x: box.minX + unit * start, y: box.minY, width: unit * length, height: box.height).integral
    }

    /// Converts a Vision normalized rectangle to integer pixels with a top-left origin.
    /// - Parameters:
    ///   - rect: The normalized rectangle, relative to `region`.
    ///   - region: The pixel rectangle Vision ran on, top-left origin.
    /// - Returns: The rectangle in whole-image pixel coordinates.
    private static func pixelRect(_ rect: NormalizedRect, in region: CGRect) -> CGRect {
        rect.toImageCoordinates(region.size, origin: .upperLeft)
            .offsetBy(dx: region.minX, dy: region.minY)
            .integral
    }
}
