import SwiftData
import SwiftUI

/// Makes the literal hard drive: one folder with every original recording,
/// the words, the photos, and a page that plays it all in any web browser.
struct SaveCopyView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Environment(AppServices.self) private var services

    var body: some View {
        let maker = services.copyMaker
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
                if maker.isWorking {
                    VStack(alignment: .leading, spacing: 10) {
                        ProgressView(value: maker.progress)
                            .tint(Palette.blue)
                        Text("Making the copy\u{2026} Keep My Story open until it's done.")
                            .foregroundStyle(Palette.softInk)
                    }
                    .padding(.vertical, 6)
                } else if let output = maker.madeCopy {
                    ShareLink(item: output.zipURL) {
                        FamilyMenuRow(title: "Save or share the copy", systemImage: "square.and.arrow.up")
                    }
                    Text("\(StoryCountText.text(output.storyCount)) and \(output.photoCount == 1 ? "1 photo" : "\(output.photoCount) photos"). Choose Save to Files to put it on a USB drive or in iCloud Drive, or AirDrop it to a Mac.")
                        .font(.footnote)
                        .foregroundStyle(Palette.softInk)
                } else {
                    Button {
                        Task {
                            await maker.makeCopy(container: context.container, ownerName: settings.displayName, settings: settings)
                        }
                    } label: {
                        FamilyMenuRow(title: "Make the copy", systemImage: "square.and.arrow.down")
                    }
                }
                if let problem = maker.problem {
                    Text(problem)
                        .foregroundStyle(Palette.brick)
                }
            } footer: {
                if let saved = settings.lastCopySavedAt {
                    Text("The last copy was made on \(DayText.long(saved)). It's only safe once it's saved somewhere other than this iPhone.")
                }
            }
        }
        .familyBackground()
        .navigationTitle("Save a copy")
    }
}
