// The command-line entry point. It declares the options, validates them, handles
// --version, shows help when run without arguments, and hands the files to
// BatchProcessor; it contains no processing logic.

import ArgumentParser

/// The `shotshifter` command.
@main
struct ShotShifterCommand: AsyncParsableCommand {
    /// The command name and help text.
    static let configuration = CommandConfiguration(
        commandName: "shotshifter",
        abstract: "Shift the time axis of dashboard screenshots to another time zone."
    )

    /// The amount to add to every X-axis time.
    @Option(name: .shortAndLong, parsing: .unconditional, help: ArgumentHelp("The amount to add to every X-axis time, as [+|-]H[:MM] (hours 0-26).", valueName: "offset"), transform: { try TimeOffset(parsing: $0) })
    var shift: TimeOffset?

    /// Whether to overwrite existing output files.
    @Flag(name: .shortAndLong, help: "Overwrite an output file that already exists.")
    var force = false

    /// Whether to leave a file unwritten when shifting it produces any warning.
    @Flag(name: .long, help: "Do not write an output that has any warning; such files count as not written.")
    var strict = false

    /// Whether to outline handled labels in green and warnings in red on the output.
    @Flag(name: [.customShort("b"), .long], help: "Outline every shifted label in green and everything a warning refers to in red; cannot be used with --strict.")
    var box = false

    /// Whether to print the version text and exit.
    @Flag(name: .shortAndLong, help: "Print the version and exit.")
    var version = false

    /// The images to process.
    @Argument(help: ArgumentHelp("PNG or JPEG screenshots to shift.", valueName: "file"))
    var files: [String] = []

    /// Runs the command, showing help with exit status 0 when no arguments are given.
    static func main() async {
        await main(CommandLine.arguments.count > 1 ? nil : ["--help"])
    }

    /// Handles `--version` and otherwise requires a shift and at least one file, and rejects `--box` with `--strict`.
    /// - Throws: `CleanExit` for `--version`, `ValidationError` for missing or conflicting arguments.
    mutating func validate() throws {
        if version {
            throw CleanExit.message(AppInfo.versionText)
        }
        guard shift != nil else {
            throw ValidationError("Missing expected argument '--shift <offset>'")
        }
        guard !files.isEmpty else {
            throw ValidationError("Missing expected argument '<file> ...'")
        }
        guard !(box && strict) else {
            throw ValidationError("--box cannot be used with --strict, which never writes a file with warnings")
        }
    }

    /// Processes the files and exits with the batch's status.
    /// - Throws: `ExitCode` with status 1 when any file was not written.
    mutating func run() async throws {
        guard let shift else {
            throw ValidationError("Missing expected argument '--shift <offset>'")
        }
        let status = await BatchProcessor(offset: shift, force: force, strict: strict, box: box).run(files)
        if status != 0 {
            throw ExitCode(status)
        }
    }
}
