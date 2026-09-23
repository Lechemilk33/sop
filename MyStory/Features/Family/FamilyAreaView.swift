import SwiftData
import SwiftUI

/// Where the family sets things up and looks after the stories. It uses
/// standard iPhone lists and forms, because the family are the ones using it.
struct FamilyAreaView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Environment(StoryPlayer.self) private var player
    @Environment(ClipPlayer.self) private var clipPlayer

    @Query(filter: #Predicate<Story> { $0.needsReview }) private var storiesToCheck: [Story]
    @Query private var allStories: [Story]
    @Query private var people: [Person]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    BackupStatusRow()
                    Label {
                        Text("\(StoryCountText.text(allStories.count)) and \(people.count == 1 ? "1 person" : "\(people.count) people") saved")
                    } icon: {
                        Image(systemName: "books.vertical.fill")
                            .foregroundStyle(Palette.marigoldRim)
                    }
                }

                Section("Add") {
                    NavigationLink {
                        PersonEditorView(person: nil)
                    } label: {
                        FamilyMenuRow(title: "Add a person", systemImage: "person.crop.circle.badge.plus")
                    }
                    NavigationLink {
                        QuestionEditorView(question: nil)
                    } label: {
                        FamilyMenuRow(title: "Add a question", systemImage: "text.bubble")
                    }
                    NavigationLink {
                        FamilyPhotosView()
                    } label: {
                        FamilyMenuRow(title: "Add photos", systemImage: "photo.on.rectangle.angled")
                    }
                    NavigationLink {
                        ImportRecordingsView()
                    } label: {
                        FamilyMenuRow(title: "Bring in old recordings", systemImage: "tray.and.arrow.down")
                    }
                }

                Section("Look after") {
                    NavigationLink {
                        StoriesListView(mode: .needsReview)
                    } label: {
                        FamilyMenuRow(title: "Check new stories", systemImage: "checklist", badge: storiesToCheck.count)
                    }
                    NavigationLink {
                        StoriesListView(mode: .all)
                    } label: {
                        FamilyMenuRow(title: "All stories", systemImage: "book")
                    }
                    NavigationLink {
                        FamilyPeopleView()
                    } label: {
                        FamilyMenuRow(title: "People", systemImage: "person.2")
                    }
                    NavigationLink {
                        FamilyQuestionsView()
                    } label: {
                        FamilyMenuRow(title: "Questions", systemImage: "questionmark.bubble")
                    }
                    NavigationLink {
                        TipsView()
                    } label: {
                        FamilyMenuRow(title: "Tips for sitting with \(nameOrHim)", systemImage: "lightbulb")
                    }
                    NavigationLink {
                        SaveCopyView()
                    } label: {
                        FamilyMenuRow(title: "Save a copy of everything", systemImage: "square.and.arrow.down")
                    }
                    NavigationLink {
                        FamilySettingsView()
                    } label: {
                        FamilyMenuRow(title: "Settings", systemImage: "gearshape")
                    }
                }
            }
            .familyBackground()
            .navigationTitle("Family area")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        clipPlayer.stop()
                        dismiss()
                    } label: {
                        Label("Done", systemImage: "house")
                            .labelStyle(.titleAndIcon)
                    }
                    .accessibilityLabel("Back to \(nameOrHim)\u{2019}s home screen")
                }
            }
        }
        .tint(Palette.brick)
        .onAppear { player.stop() }
    }

    private var nameOrHim: String {
        settings.displayName.isEmpty ? "him" : settings.displayName
    }
}

/// Whether stories are backed up to iCloud.
struct BackupStatusRow: View {
    var body: some View {
        if CloudSync.isEnabled {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Backing up to iCloud")
                        .font(.body.weight(.semibold))
                    Text("Stories are copied to this iPhone's iCloud account.")
                        .font(.footnote)
                        .foregroundStyle(Palette.softInk)
                }
            } icon: {
                Image(systemName: "checkmark.icloud.fill")
                    .foregroundStyle(Palette.green)
            }
        } else {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Saved on this iPhone only")
                        .font(.body.weight(.semibold))
                    Text("Use Save a copy of everything regularly. iCloud backup can be turned on later (see the README).")
                        .font(.footnote)
                        .foregroundStyle(Palette.softInk)
                }
            } icon: {
                Image(systemName: "exclamationmark.icloud")
                    .foregroundStyle(Palette.brick)
            }
        }
    }
}
