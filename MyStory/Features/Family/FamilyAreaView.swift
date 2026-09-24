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
                        FamilyChaptersView()
                    } label: {
                        FamilyMenuRow(title: "Chapters", systemImage: "folder")
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
        .tint(Palette.blue)
        .onAppear { player.stop() }
    }

    private var nameOrHim: String {
        settings.displayName.isEmpty ? "him" : settings.displayName
    }
}

/// Whether stories are backed up to iCloud, checked each time it's shown.
struct BackupStatusRow: View {
    @State private var status: CloudSync.Status = .checking

    var body: some View {
        Group {
            switch status {
            case .checking:
                row(
                    title: "Checking iCloud backup…",
                    detail: "",
                    systemImage: "icloud",
                    color: Palette.softInk
                )
            case .backingUp:
                row(
                    title: "Backing up to iCloud",
                    detail: "Stories are copied to this iPhone's iCloud account.",
                    systemImage: "checkmark.icloud.fill",
                    color: Palette.green
                )
            case .notSignedIn:
                row(
                    title: "Not backing up right now",
                    detail: "This iPhone isn't signed in to iCloud, or iCloud is off for My Story. Check the iPhone's Settings app, under his name, then iCloud. Until then, use Save a copy of everything.",
                    systemImage: "exclamationmark.icloud",
                    color: Palette.brick
                )
            case .thisPhoneOnly:
                row(
                    title: "Saved on this iPhone only",
                    detail: "Use Save a copy of everything regularly. iCloud backup can be turned on later (see the README).",
                    systemImage: "exclamationmark.icloud",
                    color: Palette.brick
                )
            }
        }
        .task { status = await CloudSync.currentStatus() }
    }

    private func row(title: String, detail: String, systemImage: String, color: Color) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                if !detail.isEmpty {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(Palette.softInk)
                }
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(color)
        }
    }
}
