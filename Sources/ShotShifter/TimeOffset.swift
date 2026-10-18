// Parsing and validation of the --shift value. An offset is written [+|-]H[:MM] and is
// held as a signed number of minutes. The same digit grammar is reused to read the
// offset part of time zone labels such as UTC+05:30.

/// A fixed, non-zero amount of time to add to every X-axis label.
struct TimeOffset: Equatable, Sendable {
    /// The largest accepted hour value, covering the gap between UTC-12 and UTC+14.
    static let maximumHours = 26

    /// The signed offset in minutes; never zero.
    let minutes: Int

    /// Parses a `--shift` value such as `5`, `-5`, `+5:30` or `-03:30`.
    /// - Parameters:
    ///   - text: The raw command-line value.
    /// - Throws: `ShotShifterError.invalidOffset` when the value is malformed or out of range,
    ///   `ShotShifterError.zeroOffset` when it is zero.
    init(parsing text: String) throws {
        guard let minutes = Self.minutes(from: text, signRequired: false) else {
            throw ShotShifterError.invalidOffset(text)
        }
        guard minutes != 0 else {
            throw ShotShifterError.zeroOffset
        }
        self.minutes = minutes
    }

    /// Reads `[+|-]H[:MM]`: one or two hour digits (0-26) and optionally exactly two minute digits (00-59).
    /// - Parameters:
    ///   - text: The text to read.
    ///   - signRequired: Whether a leading `+` or `-` must be present.
    /// - Returns: The signed number of minutes, which may be zero, or `nil` if the text does not match.
    static func minutes(from text: some StringProtocol, signRequired: Bool) -> Int? {
        var body = Substring(text)
        var sign = 1
        if let first = body.first, first == "+" || first == "-" {
            sign = first == "-" ? -1 : 1
            body = body.dropFirst()
        } else if signRequired {
            return nil
        }
        let parts = body.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 1 || parts.count == 2 else {
            return nil
        }
        let hourText = parts[0]
        guard (1...2).contains(hourText.count), hourText.isASCIIDigits, let hours = Int(hourText), hours <= maximumHours else {
            return nil
        }
        var minutes = 0
        if parts.count == 2 {
            let minuteText = parts[1]
            guard minuteText.count == 2, minuteText.isASCIIDigits, let value = Int(minuteText), value <= 59 else {
                return nil
            }
            minutes = value
        }
        return sign * (hours * 60 + minutes)
    }
}
