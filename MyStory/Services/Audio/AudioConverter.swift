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

    /// When a recording was made, from the file's own details (Voice Memos
    /// keeps this even after the file is saved elsewhere). Nil if unknown or
    /// clearly wrong.
    static func recordingDate(of url: URL) async -> Date? {
        let asset = AVURLAsset(url: url)
        guard let item = try? await asset.load(.creationDate) else { return nil }
        var date = try? await item.load(.dateValue)
        if date == nil, let text = try? await item.load(.stringValue) {
            date = ISO8601DateFormatter().date(from: text)
        }
        guard let date, date <= Date(), date > Date(timeIntervalSince1970: 0) else { return nil }
        return date
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
    ///
    /// - Parameter measuredDuration: how long the recorder says it recorded,
    ///   used when the file's own duration can't be read.
    static func finalizeRecording(at cafURL: URL, measuredDuration: TimeInterval = 0) async -> FinishedRecording {
        let m4aURL = cafURL.deletingPathExtension().appendingPathExtension("m4a")
        do {
            try await convertToM4A(from: cafURL, to: m4aURL)
            let seconds = await AudioConverter.duration(of: m4aURL)
            guard seconds > 0 else { throw ConversionError.cannotExport }
            try? FileManager.default.removeItem(at: cafURL)
            return FinishedRecording(fileURL: m4aURL, fileExtension: "m4a", duration: seconds, measuredDuration: measuredDuration)
        } catch {
            try? FileManager.default.removeItem(at: m4aURL)
            let seconds = await AudioConverter.duration(of: cafURL)
            return FinishedRecording(
                fileURL: cafURL,
                fileExtension: "caf",
                duration: seconds > 0 ? seconds : measuredDuration,
                measuredDuration: measuredDuration
            )
        }
    }
}

/// A recording ready to be stored in a story.
struct FinishedRecording {
    let fileURL: URL
    let fileExtension: String
    /// Length of the file, falling back to the recorder's own count.
    let duration: TimeInterval
    /// What the recorder counted while recording (0 if unknown).
    let measuredDuration: TimeInterval

    /// The best estimate of how long he talked.
    var bestDuration: TimeInterval {
        max(duration, measuredDuration)
    }
}
