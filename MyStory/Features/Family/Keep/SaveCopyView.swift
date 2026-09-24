import SwiftData
import SwiftUI

/// Makes the literal hard drive: one folder with every original recording,
/// the words, the photos, and a page that plays it all in any web browser.
struct SaveCopyView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    @State private var isWorking = false
    @State private var progress: Double = 0
    @State private var output: ArchiveExporter.Output?
    @State private var problem: String?

    var body: some View {
        List {
            Section {
                Label("Every original recording", systemImage: "waveform")
                Label("His words, typed out, in text files", systemImage: "doc.text")
                Label("The photos, and who is in them", systemImage: "photo.on.rectangle")
                Label("Questions the family recorded in their own voices", systemImage: "questionmark.bubble")
                Label("\u{201C}Open me.html\u{201D}: plays everything in any web browser, no app needed", systemImage: "globe")
            } header: {
                Text("What's in the copy")
            } footer: {
                Text("Plain files that will still open in decades. Keep copies in more than one place: a computer, a USB drive, and the cloud.")
            }

            Section {
                if let output {
                    ShareLink(item: output.zipURL) {
                        FamilyMenuRow(title: "Save or share the copy", systemImage: "square.and.arrow.up")
                    }
                    Text("\(StoryCountText.text(output.storyCount)) and \(output.photoCount == 1 ? "1 photo" : "\(output.photoCount) photos"). Choose Save to Files to put it on a USB drive or in iCloud Drive, or AirDrop it to a Mac.")
                        .font(.footnote)
                        .foregroundStyle(Palette.softInk)
                } else if isWorking {
                    VStack(alignment: .leading, spacing: 10) {
                        ProgressView(value: progress)
                            .tint(Palette.blue)
                        Text("Making the copy…")
                            .foregroundStyle(Palette.softInk)
                    }
                    .padding(.vertical, 6)
                } else {
                    Button {
                        Task { await makeCopy() }
                    } label: {
                        FamilyMenuRow(title: "Make the copy", systemImage: "square.and.arrow.down")
                    }
                }
                if let problem {
                    Text(problem)
                        .foregroundStyle(Palette.brick)
                }
            } footer: {
                if let saved = settings.lastCopySavedAt {
                    Text("Last copy made \(DayText.long(saved)).")
                }
            }
        }
        .familyBackground()
        .navigationTitle("Save a copy")
    }

    private func makeCopy() async {
        isWorking = true
        problem = nil
        progress = 0
        defer { isWorking = false }
        do {
            let exporter = ArchiveExporter(container: context.container, ownerName: settings.displayName)
            let result = try await exporter.makeArchive { value in
                progress = value
            }
            output = result
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
