// The batch loop over input files. Files are processed one at a time in the order
// given; a failure ends only that file. It prints the result line, warnings and errors,
// and turns the outcome into the process exit status. In strict mode a file with any
// warning is not written; in box mode outputs carry review outlines. When standard error
// is a terminal, warnings are printed in yellow and errors in red.

import Foundation

/// Processes a list of image files with one offset.
struct BatchProcessor {
    /// The kind of a message printed for one file.
    enum Level: String {
        /// A file was written with a problem, or was skipped.
        case warning
        /// A file could not be processed.
        case error

        /// The ANSI escape sequence that colors the message: yellow for warnings, red for errors.
        var color: String {
            switch self {
            case .warning: "\u{1B}[33m"
            case .error: "\u{1B}[31m"
            }
        }
    }

    /// The ANSI escape sequence that restores the default color.
    private static let resetColor = "\u{1B}[0m"
    /// Whether standard error is a terminal, so messages may be colored.
    private static let colorsMessages = isatty(STDERR_FILENO) != 0

    /// The amount to add to every label.
    let offset: TimeOffset
    /// Whether existing outputs are replaced.
    let force: Bool
    /// Whether a file with any warning is left unwritten.
    let strict: Bool
    /// Whether outputs outline handled labels in green and warnings in red.
    let box: Bool

    /// Processes every file and reports the outcome.
    /// - Parameters:
    ///   - paths: The input paths as given on the command line.
    /// - Returns: The exit status: 0 when every file was written, 1 otherwise.
    func run(_ paths: [String]) async -> Int32 {
        var failures = 0
        for path in paths {
            do {
                try await process(path)
            } catch ShotShifterError.outputExists(let output) {
                report(.warning, path: path, message: ShotShifterError.outputExists(output).description)
                failures += 1
            } catch {
                report(.error, path: path, message: "\(error)")
                failures += 1
            }
        }
        guard failures == 0 else {
            Self.write("\(failures) of \(paths.count) files were not written", to: .standardError)
            return 1
        }
        return 0
    }

    /// Shifts one file and writes its output.
    /// - Parameters:
    ///   - path: The input path.
    /// - Throws: `ShotShifterError.outputExists` when the output exists without `--force`, `ShotShifterError.strictWarnings`
    ///   when there are warnings in strict mode, or any load, pipeline or write error.
    private func process(_ path: String) async throws {
        let outputPath = OutputPath.shifted(path)
        if !force && FileManager.default.fileExists(atPath: outputPath) {
            throw ShotShifterError.outputExists(outputPath)
        }
        let file = try ImageFile.load(path: path)
        let result = try await ImageShifter(offset: offset, drawsBoxes: box).shift(file.image)
        for warning in result.warnings {
            report(.warning, path: path, message: warning.message)
        }
        if strict && !result.warnings.isEmpty {
            throw ShotShifterError.strictWarnings(result.warnings.count)
        }
        try file.write(result.image, to: outputPath)
        Self.write("\(path) -> \(outputPath) (\(Self.counted(result.labelCount, "label")) in \(Self.counted(result.rowCount, "row")))", to: .standardOutput)
    }

    /// Prints a warning or error line for one file to standard error, colored when standard error is a terminal.
    /// - Parameters:
    ///   - level: Whether the line is a warning or an error.
    ///   - path: The input path.
    ///   - message: The message.
    private func report(_ level: Level, path: String, message: String) {
        let line = "\(level.rawValue): \(path): \(message)"
        Self.write(Self.colorsMessages ? level.color + line + Self.resetColor : line, to: .standardError)
    }

    /// Writes one line, unbuffered, so results and messages appear in the order files are processed.
    /// - Parameters:
    ///   - line: The line, without a newline.
    ///   - handle: Standard output or standard error.
    private static func write(_ line: String, to handle: FileHandle) {
        handle.write(Data((line + "\n").utf8))
    }

    /// Formats a count with a singular or plural noun, such as `1 row` or `14 labels`.
    /// - Parameters:
    ///   - count: The count.
    ///   - noun: The singular noun.
    /// - Returns: The phrase.
    private static func counted(_ count: Int, _ noun: String) -> String {
        "\(count) \(noun)\(count == 1 ? "" : "s")"
    }
}
