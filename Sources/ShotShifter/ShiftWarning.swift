// A warning produced while shifting one image. It carries the message printed for the
// file and the pixel boxes it refers to, so --box can outline them; a time zone warning
// covers every place its word appears.

import CoreGraphics

/// One warning and where it applies in the image.
struct ShiftWarning: Sendable, Equatable {
    /// The message, printed after the file name.
    let message: String
    /// The pixel boxes the warning refers to, top-left origin.
    let boxes: [CGRect]
}
