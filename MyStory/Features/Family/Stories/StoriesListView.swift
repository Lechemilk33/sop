import SwiftData
import SwiftUI

/// New stories to check, or every story.
struct StoriesListView: View {
    enum Mode {
        case needsReview
        case all
    }

    let mode: Mode

    @Query(sort: \Story.recordedAt, order: .reverse) private var stories: [Story]

    var body: some View {
        let shown = mode == .needsReview ? stories.filter(\.needsReview) : stories
        List {
            if shown.isEmpty {
                Section {
                    Text(mode == .needsReview ? "Nothing to check right now." : "No stories yet.")
                        .foregroundStyle(Palette.softInk)
                }
            } else {
                Section {
                    ForEach(shown) { story in
                        NavigationLink {
                            StoryEditorView(story: story)
                        } label: {
                            StoryListRow(story: story)
                        }
                    }
                } footer: {
                    if mode == .needsReview {
                        Text("Give each new story a short title and the right chapter. Saving marks it as checked.")
                    }
                }
            }
        }
        .familyBackground()
        .navigationTitle(mode == .needsReview ? "New stories" : "All stories")
    }
}

private struct StoryListRow: View {
    let story: Story

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(story.displayTitle)
                .font(.body.weight(.semibold))
                .lineLimit(2)
            Text([
                DayText.toldShort(story.recordedAt),
                DurationText.spoken(story.duration),
                story.chapter?.name ?? "No chapter",
                transcriptNote,
            ].compactMap { $0 }.joined(separator: " \u{00B7} "))
            .font(.footnote)
            .foregroundStyle(Palette.softInk)
        }
        .padding(.vertical, 4)
    }

    private var transcriptNote: String? {
        switch story.transcriptState {
        case .pending, .working: "Writing it down…"
        case .failed: "Couldn't write it down"
        case .unavailable: nil
        case .done: story.hasTranscript ? nil : "No words heard"
        }
    }
}
