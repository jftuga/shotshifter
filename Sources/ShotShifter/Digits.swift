// Small digit helpers shared by the parsers and formatters. Parsers accept only ASCII
// digits, so Unicode digits from text recognition never parse as numbers, and every
// two-digit field (hours, minutes, padded dates) is printed the same way.

extension StringProtocol {
    /// Whether the string is non-empty and made only of ASCII digits `0` through `9`.
    var isASCIIDigits: Bool {
        !isEmpty && allSatisfy { $0.isASCII && $0.isNumber }
    }
}

extension Int {
    /// The value printed with at least two digits, such as `05` or `14`.
    var twoDigits: String {
        self < 10 && self >= 0 ? "0\(self)" : "\(self)"
    }
}
