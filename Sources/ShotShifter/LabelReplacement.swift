// One drawing job for the renderer: where the original text is, what replaces it, and
// how the new text is placed. Axis labels are centered and checked against their row
// neighbors; time zone words are left-aligned and erased with narrower side padding.

import CoreGraphics

/// A label to erase and redraw.
struct LabelReplacement: Sendable, Equatable {
    /// How the new text is placed and checked.
    enum Placement: Sendable, Equatable {
        /// An X-axis label in the row with this index: centered on the original.
        case axis(row: Int)
        /// A time zone word: left-aligned to the original.
        case timeZone
    }

    /// The original text's pixel box, top-left origin.
    let box: CGRect
    /// The original text, used to size the new text.
    let oldText: String
    /// The text to draw.
    let newText: String
    /// How the new text is placed.
    let placement: Placement
}
