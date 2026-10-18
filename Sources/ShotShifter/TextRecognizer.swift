// Text recognition with Vision's RecognizeTextRequest. The whole image is recognized
// once, which catches long merged lines, and then again in overlapping square tiles,
// because Vision misses many small, isolated axis labels in a large screenshot. Tile
// results cut by a tile edge are dropped; duplicates are resolved later by the parsers.

import CoreGraphics
import Foundation
import Vision

/// Runs Vision text recognition over an image and returns pixel-coordinate observations.
struct TextRecognizer {
    /// The side length of a recognition tile, in pixels.
    static let tileSize = 768

    /// A tile observation closer than this many pixels to an inner tile edge is treated as cut off.
    static let innerEdgeMargin: CGFloat = 4

    /// Recognizes all text in an image: one whole-image pass, then one pass per tile.
    /// - Parameters:
    ///   - image: The image to read.
    /// - Returns: Every observation from every pass, whole-image pass first.
    /// - Throws: `ShotShifterError.recognitionFailed` when Vision fails.
    func recognize(_ image: CGImage) async throws -> [TextObservation] {
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        var observations = try await Self.recognize(image, region: bounds)
        // Passes run one after another: concurrent text requests crash inside Vision's TextRecognition framework.
        for tile in Self.tiles(width: image.width, height: image.height) {
            guard let cropped = image.cropping(to: tile) else {
                continue
            }
            let found = try await Self.recognize(cropped, region: tile)
            observations += found.filter { !Self.touchesInnerEdge($0.box, of: tile, in: bounds) }
        }
        return observations
    }

    /// Returns overlapping tiles covering an image, or no tiles when one tile would cover it all.
    /// Neighboring tiles overlap by half a tile, so any text narrower than half a tile lies fully inside one of them.
    /// - Parameters:
    ///   - width: The image width in pixels.
    ///   - height: The image height in pixels.
    /// - Returns: The tile rectangles in pixels, top-left origin.
    static func tiles(width: Int, height: Int) -> [CGRect] {
        guard width > tileSize || height > tileSize else {
            return []
        }
        var tiles: [CGRect] = []
        for y in tileStarts(length: height) {
            for x in tileStarts(length: width) {
                tiles.append(CGRect(x: x, y: y, width: min(tileSize, width), height: min(tileSize, height)))
            }
        }
        return tiles
    }

    /// Returns tile start positions along one axis, half a tile apart, with the last tile ending at the image edge.
    /// - Parameters:
    ///   - length: The image length along the axis, in pixels.
    /// - Returns: The start positions.
    private static func tileStarts(length: Int) -> [Int] {
        guard length > tileSize else {
            return [0]
        }
        return Array(stride(from: 0, to: length - tileSize, by: tileSize / 2)) + [length - tileSize]
    }

    /// Whether a box reaches an edge of its tile that lies inside the image, meaning the text may be cut off.
    /// - Parameters:
    ///   - box: The observation box in pixels.
    ///   - tile: The tile the observation came from.
    ///   - bounds: The whole image's bounds.
    /// - Returns: `true` if the box touches an inner tile edge.
    private static func touchesInnerEdge(_ box: CGRect, of tile: CGRect, in bounds: CGRect) -> Bool {
        (tile.minX > bounds.minX && box.minX - tile.minX < innerEdgeMargin)
            || (tile.maxX < bounds.maxX && tile.maxX - box.maxX < innerEdgeMargin)
            || (tile.minY > bounds.minY && box.minY - tile.minY < innerEdgeMargin)
            || (tile.maxY < bounds.maxY && tile.maxY - box.maxY < innerEdgeMargin)
    }

    /// Runs one Vision request on an image or a cropped tile.
    /// - Parameters:
    ///   - image: The image or tile to read.
    ///   - region: Where `image` sits in the whole image, in pixels with a top-left origin.
    /// - Returns: The observations in whole-image pixel coordinates.
    /// - Throws: `ShotShifterError.recognitionFailed` when Vision fails.
    private static func recognize(_ image: CGImage, region: CGRect) async throws -> [TextObservation] {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = [Locale.Language(identifier: "en-US")]
        request.minimumTextHeightFraction = 0.005
        do {
            let results = try await request.perform(on: image)
            return results.compactMap { TextObservation(observation: $0, region: region) }
        } catch {
            throw ShotShifterError.recognitionFailed(error.localizedDescription)
        }
    }
}
