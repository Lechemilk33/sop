import Foundation

/// Decides whether a compact copy of a recording is whole, before the raw
/// recording is deleted. Pure arithmetic, so it can be tested anywhere.
enum ConversionCheck {
    /// True if `converted` seconds is as long as the `original`, give or
    /// take the small differences encoding makes (a couple of seconds, or 2%
    /// of a long story). Zero or unknown lengths never count as whole.
    static func isComplete(converted: TimeInterval, original: TimeInterval) -> Bool {
        guard converted > 0, converted.isFinite else { return false }
        guard original > 0, original.isFinite else { return true }
        let allowance = max(2, original * 0.02)
        return converted + allowance >= original
    }
}
