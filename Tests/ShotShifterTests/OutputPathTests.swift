// Tests for output file naming: "-shifted" goes before the last extension, in the
// same directory, and names without an extension simply gain the suffix.

import Testing
@testable import ShotShifter

/// Tests for `OutputPath`.
struct OutputPathTests {
    /// Each input path maps to the expected output path.
    /// - Parameters:
    ///   - input: The input path.
    ///   - expected: The expected output path.
    @Test(arguments: [
        ("graph1.png", "graph1-shifted.png"),
        ("/tmp/cpu.load.jpg", "/tmp/cpu.load-shifted.jpg"),
        ("screenshot", "screenshot-shifted"),
        ("graph1-shifted.png", "graph1-shifted-shifted.png"),
        ("dir.v2/screenshot", "dir.v2/screenshot-shifted"),
        ("./a/b.c/.hidden", "./a/b.c/.hidden-shifted"),
    ])
    func names(input: String, expected: String) {
        #expect(OutputPath.shifted(input) == expected)
    }
}
