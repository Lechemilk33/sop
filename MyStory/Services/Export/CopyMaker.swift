import Foundation
import Observation
import SwiftData

/// Makes the saved copy and remembers how it went, so the family can leave
/// the page and come back to it, and two copies are never made at once.
/// The screen stays on while it works, and a locked phone gets a little
/// time to finish.
@MainActor
@Observable
final class CopyMaker {
    private(set) var isWorking = false
    private(set) var progress: Double = 0
    private(set) var problem: String?
    private var output: ArchiveExporter.Output?

    /// The copy made earlier, while it's still on the iPhone.
    var madeCopy: ArchiveExporter.Output? {
        guard let output, FileManager.default.fileExists(atPath: output.zipURL.path) else { return nil }
        return output
    }

    func makeCopy(container: ModelContainer, ownerName: String, settings: AppSettings) async {
        guard !isWorking else { return }
        isWorking = true
        problem = nil
        progress = 0
        output = nil
        ScreenAwake.set(.savingCopy, true)
        let activity = BackgroundActivity("Save a copy")
        defer {
            isWorking = false
            ScreenAwake.set(.savingCopy, false)
            activity.end()
        }
        do {
            let exporter = ArchiveExporter(container: container, ownerName: ownerName)
            output = try await exporter.makeArchive { [weak self] value in
                self?.progress = value
            }
            settings.lastCopySavedAt = Date()
        } catch ArchiveExporter.ExportError.nothingToSave {
            problem = "There's nothing to save yet."
        } catch ArchiveExporter.ExportError.notEnoughSpace(let needed) {
            let amount = ByteCountFormatter.string(fromByteCount: needed, countStyle: .file)
            problem = "The iPhone needs about \(amount) free to make the copy. Free up space in Settings \u{2192} General \u{2192} iPhone Storage, then try again. His stories are safe either way."
        } catch {
            problem = "The copy couldn't be made. Please try again. His stories are safe either way."
        }
    }
}
