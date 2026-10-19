// Resolution of duplicate recognitions. Text is recognized in a whole-image pass and in
// overlapping tiles, so the same label or time zone word can be found more than once;
// overlapping finds are collapsed to the most complete one, then to the reading most passes
// agree on, preferring tile reads, which see the text at full resolution, over the
// whole-image pass, which Vision downscales. The surviving reading keeps the tightest box
// among the finds that agree with it.

import CoreGraphics

/// Something found by text recognition at a place in the image.
protocol RecognizedItem {
    /// The recognized text.
    var text: String { get }
    /// The pixel box, top-left origin.
    var box: CGRect { get }
    /// Vision's confidence, from 0 to 1.
    var confidence: Float { get }
    /// Whether the text was read in a tile pass rather than the whole-image pass.
    var fromTile: Bool { get }
}

extension Array where Element: RecognizedItem {
    /// Two items are duplicates when their intersection covers at least this fraction of the smaller box.
    static var duplicateOverlap: CGFloat { 0.5 }

    /// Removes duplicate finds of the same text. Among overlapping items the one with the longest
    /// text wins, then the one whose text the most overlapping items share, then one read in a tile,
    /// then the most confident, then the earliest. Agreement and tile reads come before confidence
    /// because Vision reports full confidence for its misreads of downscaled digits. The winning text
    /// is represented by the narrowest item that agrees with it, because the boxes Vision gives for
    /// words inside a merged line can be wider than the word and off center.
    /// - Returns: The surviving items, in priority order.
    func removingDuplicates() -> [Element] {
        let votes = map { item in filter { $0.text == item.text && Self.overlapFraction($0.box, item.box) >= Self.duplicateOverlap }.count }
        let ranked = enumerated().sorted { first, second in
            if first.element.text.count != second.element.text.count {
                return first.element.text.count > second.element.text.count
            }
            if votes[first.offset] != votes[second.offset] {
                return votes[first.offset] > votes[second.offset]
            }
            if first.element.fromTile != second.element.fromTile {
                return first.element.fromTile
            }
            if first.element.confidence != second.element.confidence {
                return first.element.confidence > second.element.confidence
            }
            return first.offset < second.offset
        }
        var kept: [Element] = []
        for (_, item) in ranked where !kept.contains(where: { Self.overlapFraction($0.box, item.box) >= Self.duplicateOverlap }) {
            let agreeing = filter { $0.text == item.text && Self.overlapFraction($0.box, item.box) >= Self.duplicateOverlap }
            kept.append(agreeing.min { $0.box.width < $1.box.width } ?? item)
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
