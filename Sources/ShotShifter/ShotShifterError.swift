// The single error type used throughout ShotShifter. Each case describes one way a
// command-line value or a single input file can fail; the batch reports the
// description and moves on to the next file.

/// Every error ShotShifter throws.
enum ShotShifterError: Error, CustomStringConvertible, Equatable {
    /// The `--shift` value is malformed or out of range.
    case invalidOffset(String)
    /// The `--shift` value is zero.
    case zeroOffset
    /// The input file does not exist or cannot be read.
    case unreadableFile
    /// The input is readable but is not a PNG or JPEG image.
    case unsupportedImageType(String)
    /// Vision text recognition failed.
    case recognitionFailed(String)
    /// No X-axis time labels were found in the image.
    case noTimeAxis
    /// A bitmap for drawing the new labels could not be created.
    case renderFailed
    /// The output file already exists and `--force` was not given.
    case outputExists(String)
    /// Encoding or moving the output file failed.
    case writeFailed(String)

    /// A one-line, human-readable description of the error.
    var description: String {
        switch self {
        case .invalidOffset(let value):
            "invalid shift \"\(value)\": expected [+|-]H[:MM] with hours 0-26 and minutes 00-59"
        case .zeroOffset:
            "shift must not be zero"
        case .unreadableFile:
            "file does not exist or cannot be read"
        case .unsupportedImageType(let type):
            "unsupported image type \(type); only PNG and JPEG are supported"
        case .recognitionFailed(let reason):
            "text recognition failed: \(reason)"
        case .noTimeAxis:
            "no time axis labels found"
        case .renderFailed:
            "cannot create a bitmap to draw the new labels"
        case .outputExists(let path):
            "\(path) exists; use -f to overwrite"
        case .writeFailed(let reason):
            "cannot write output: \(reason)"
        }
    }
}
