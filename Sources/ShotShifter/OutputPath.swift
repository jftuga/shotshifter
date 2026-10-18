// Derivation of the output file name. The output sits beside the input with "-shifted"
// inserted before the last extension. It works on the path string as given on the
// command line, so messages show paths the way the user typed them.

/// Builds the output path for an input image.
enum OutputPath {
    /// The text inserted before the extension.
    static let suffix = "-shifted"

    /// Returns the output path for an input path, such as `graph1.png` to `graph1-shifted.png`.
    /// A leading dot in the file name (a hidden file) is not treated as an extension.
    /// - Parameters:
    ///   - inputPath: The input path as given on the command line.
    /// - Returns: The output path in the same directory.
    static func shifted(_ inputPath: String) -> String {
        let nameStart = inputPath.lastIndex(of: "/").map { inputPath.index(after: $0) } ?? inputPath.startIndex
        let name = inputPath[nameStart...]
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else {
            return inputPath + suffix
        }
        return inputPath[..<dot] + suffix + inputPath[dot...]
    }
}
