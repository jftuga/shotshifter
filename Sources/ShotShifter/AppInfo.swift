// Application identity constants for ShotShifter. The name, version and project URL
// live here so the version text printed by -v/--version has a single source of truth.

/// Constants that identify the application.
enum AppInfo {
    /// The application name.
    static let name = "ShotShifter"

    /// The semantic version of this release.
    static let version = "0.2.1"

    /// The project home page.
    static let url = "https://github.com/jftuga/ShotShifter"

    /// The two-line text printed by `-v` and `--version`.
    static let versionText = "\(name) v\(version)\n\(url)"
}
