import AVFoundation

/// Turns raw recordings into compact AAC `.m4a` files and reads durations.
enum AudioConverter {
    enum ConversionError: Error {
        case cannotExport
    }

    /// Converts any audio file AVFoundation can read into AAC `.m4a`.
    static func convertToM4A(from source: URL, to destination: URL) async throws {
        let asset = AVURLAsset(url: source)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw ConversionError.cannotExport
        }
        try? FileManager.default.removeItem(at: destination)
        try await session.export(to: destination, as: .m4a)
    }

    /// Duration in seconds, or 0 if it can't be read.
    static func duration(of url: URL) async -> TimeInterval {
        let asset = AVURLAsset(url: url)
        guard let time = try? await asset.load(.duration) else { return 0 }
        let seconds = CMTimeGetSeconds(time)
        return seconds.isFinite ? seconds : 0
    }

    /// Finishes a raw recording: converts the crash-safe PCM `.caf` into `.m4a`
    /// and deletes the `.caf`. If conversion fails, the `.caf` itself is kept
    /// and returned, so a story is never lost.
    static func finalizeRecording(at cafURL: URL) async -> FinishedRecording {
        let m4aURL = cafURL.deletingPathExtension().appendingPathExtension("m4a")
        do {
            try await convertToM4A(from: cafURL, to: m4aURL)
            let seconds = await AudioConverter.duration(of: m4aURL)
            try? FileManager.default.removeItem(at: cafURL)
            return FinishedRecording(fileURL: m4aURL, fileExtension: "m4a", duration: seconds)
        } catch {
            let seconds = await AudioConverter.duration(of: cafURL)
            return FinishedRecording(fileURL: cafURL, fileExtension: "caf", duration: seconds)
        }
    }
}

/// A recording ready to be stored in a story.
struct FinishedRecording {
    let fileURL: URL
    let fileExtension: String
    let duration: TimeInterval
}
