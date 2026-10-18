// Resolution of duplicate recognitions. Text is recognized in a whole-image pass and in
// overlapping tiles, so the same label or time zone word can be found more than once;
// overlapping finds are collapsed to the most complete, most confident one.

import CoreGraphics

/// Something found by text recognition at a place in the image.
protocol RecognizedItem {
    /// The recognized text.
    var text: String { get }
    /// The pixel box, top-left origin.
    var box: CGRect { get }
    /// Vision's confidence, from 0 to 1.
    var confidence: Float { get }
}

extension Array where Element: RecognizedItem {
    /// Two items are duplicates when their intersection covers at least this fraction of the smaller box.
    static var duplicateOverlap: CGFloat { 0.5 }

    /// Removes duplicate finds of the same text. Among overlapping items the one with the longest
    /// text wins, then the most confident, then the earliest.
    /// - Returns: The surviving items, in priority order.
    func removingDuplicates() -> [Element] {
        let ranked = enumerated().sorted { first, second in
            if first.element.text.count != second.element.text.count {
                return first.element.text.count > second.element.text.count
            }
            if first.element.confidence != second.element.confidence {
                return first.element.confidence > second.element.confidence
            }
            return first.offset < second.offset
        }
        var kept: [Element] = []
        for (_, item) in ranked where !kept.contains(where: { Self.overlapFraction($0.box, item.box) >= Self.duplicateOverlap }) {
            kept.append(item)
        }
        return kept
    }

    /// The area of the intersection of two boxes as a fraction of the smaller box's area.
    /// - Parameters:
    ///   - first: One box.
    ///   - second: The other box.
    /// - Returns: A value from 0 to 1.
    static func overlapFraction(_ first: CGRect, _ second: CGRect) -> CGFloat {
        let intersection = first.intersection(second)
        let smallerArea = Swift.min(first.width * first.height, second.width * second.height)
        guard !intersection.isNull, smallerArea > 0 else {
            return 0
        }
        return intersection.width * intersection.height / smallerArea
    }
}
