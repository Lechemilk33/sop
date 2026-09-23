import Foundation

/// Safe, readable file names for the saved copy, so the folder makes sense
/// even without the app: "2026-09-12 Her first bike ride.m4a".
enum FileNaming {
    /// Removes characters that aren't allowed in file names on common systems,
    /// collapses whitespace, and keeps names to a sensible length.
    static func sanitized(_ raw: String, fallback: String = "Untitled", maxLength: Int = 80) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|").union(.controlCharacters).union(.newlines)
        let cleanedScalars = raw.unicodeScalars.map { forbidden.contains($0) ? " " : String($0) }.joined()
        let collapsed = cleanedScalars
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        var result = String(collapsed.prefix(maxLength))
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: " ."))
        return result.isEmpty ? fallback : result
    }

    /// Returns `base.ext`, or `base 2.ext`, `base 3.ext`… if the name is taken.
    /// Comparison ignores case, because many file systems do.
    static func unique(_ base: String, ext: String, taken: inout Set<String>) -> String {
        let suffix = ext.isEmpty ? "" : ".\(ext)"
        var candidate = base + suffix
        var counter = 2
        while taken.contains(candidate.lowercased()) {
            candidate = "\(base) \(counter)\(suffix)"
            counter += 1
        }
        taken.insert(candidate.lowercased())
        return candidate
    }

    /// "Dave's Stories", or "My Stories" without a name.
    static func folderName(for ownerName: String) -> String {
        let trimmed = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "My Stories" }
        return sanitized("\(Possessive.of(trimmed)) Stories", fallback: "My Stories")
    }
}

/// "Dave's", "James's".
enum Possessive {
    static func of(_ name: String) -> String {
        name + "\u{2019}s"
    }
}
