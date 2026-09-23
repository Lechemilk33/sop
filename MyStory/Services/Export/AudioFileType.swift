import Foundation

/// Works out what kind of recording some audio data is from its first bytes.
/// Voice clips are stored without a file extension, and a clip that couldn't
/// be converted stays in its original `.caf` form.
enum AudioFileType {
    /// "caf", "wav" or "m4a"; `fallback` if the data isn't recognized.
    static func fileExtension(of data: Data, fallback: String = "m4a") -> String {
        let header = [UInt8](data.prefix(12))
        if header.starts(with: Array("caff".utf8)) {
            return "caf"
        }
        if header.count == 12, header.starts(with: Array("RIFF".utf8)), Array(header[8..<12]) == Array("WAVE".utf8) {
            return "wav"
        }
        if header.count >= 8, Array(header[4..<8]) == Array("ftyp".utf8) {
            return "m4a"
        }
        return fallback
    }
}
