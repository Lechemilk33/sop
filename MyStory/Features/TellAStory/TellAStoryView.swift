import SwiftData
import SwiftUI

/// Hosts the steps of telling a story.
struct TellAStoryView: View {
    let seed: PromptSeed

    @Environment(\.modelContext) private var context
    @Environment(StoryRecorder.self) private var recorder
    @Environment(QuestionReader.self) private var reader
    @Environment(TranscriptionService.self) private var transcription
    @Environment(AppSettings.self) private var settings

    @State private var flow: TellAStoryFlow?

    var body: some View {
        Group {
            if let flow {
                switch flow.step {
                case .choose:
                    TellChoiceView(flow: flow)
                case .naming:
                    NameStoryView(flow: flow)
                case .question:
                    QuestionStepView(flow: flow)
                case .recording:
                    RecordingStepView(flow: flow)
                case .saved(let story):
                    SavedStepView(flow: flow, story: story)
                case .renaming(let story):
                    SavedNameView(flow: flow, story: story)
                case .choosingPeople(let story):
                    SavedPeopleView(flow: flow, story: story)
                case .keptSafe:
                    KeptSafeView()
                case .microphoneOff:
                    MicrophoneOffView()
                }
            } else {
                Backdrop(tone: .brick)
            }
        }
        .onAppear {
            guard flow == nil else { return }
            flow = TellAStoryFlow(
                seed: seed,
                context: context,
                recorder: recorder,
                reader: reader,
                transcription: transcription,
                readsAutomatically: settings.readQuestionsAutomatically
            )
        }
        .onDisappear {
            flow?.leave()
        }
    }
}

/// Step 1: his own story, or a question to start him off.
struct TellChoiceView: View {
    let flow: TellAStoryFlow

    var body: some View {
        ScreenScaffold {
            SectionHeader(title: "Tell a story", systemImage: Symbols.tell, tone: .brick)
            if let person = flow.aboutPerson {
                InfoCard {
                    Text("A story about")
                        .appFont(.caption)
                        .foregroundStyle(Palette.softInk)
                    PersonBadge(person: person)
                }
            } else if let chapter = flow.seedChapter {
                InfoCard {
                    Text("A story for your chapter")
                        .appFont(.caption)
                        .foregroundStyle(Palette.softInk)
                    Label {
                        Text(chapter.name)
                            .appFont(.subtitle)
                            .foregroundStyle(Palette.ink)
                    } icon: {
                        Medallion(systemImage: chapter.symbolName, tone: .marigold, size: Metrics.smallMedallion)
                    }
                }
            }
            Instruction("How would you like to start?")
            PlaceTile(
                title: "My own story",
                subtitle: "Talk about anything you like, and give it a name",
                systemImage: Symbols.ownStory,
                tone: .brick,
                minHeight: Metrics.largeButtonHeight + 16
            ) {
                flow.chooseOwnStory()
            }
            PlaceTile(
                title: "Answer a question",
                subtitle: "Get a question to start you off",
                systemImage: Symbols.question,
                tone: .brick,
                minHeight: Metrics.largeButtonHeight + 16
            ) {
                flow.chooseQuestion()
            }
        }
    }
}

/// Step 2 of his own story: a name, if he'd like one. It can be anything,
/// and he can skip it; the story is named by the day he told it.
struct NameStoryView: View {
    let flow: TellAStoryFlow

    @FocusState private var isTyping: Bool

    var body: some View {
        @Bindable var flow = flow
        ScreenScaffold(back: BackAction(title: "Tell a story") {
            isTyping = false
            flow.backToChoice()
        }) {
            SectionHeader(title: "My own story", systemImage: Symbols.ownStory, tone: .brick)
            if let note = flow.note {
                Instruction(note)
            }
            if let person = flow.aboutPerson {
                PersonBadge(person: person)
            }
            Text("What would you like to call it?")
                .appFont(.question)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            TextEntryField(
                example: "For example: The summer at the lake. You can also skip this.",
                text: $flow.ownTitle,
                isFocused: $isTyping
            )
            TypingTip()
        } footer: {
            BigButton("Start talking", systemImage: Symbols.tell, tone: .brick, size: .large) {
                isTyping = false
                Task { await flow.startRecording() }
            }
        }
    }
}

/// After saving: a name for the story. An empty box keeps its name.
struct SavedNameView: View {
    let flow: TellAStoryFlow
    let story: Story

    @State private var name = ""
    @FocusState private var isTyping: Bool

    var body: some View {
        ScreenScaffold(back: BackAction(title: "Saved") {
            isTyping = false
            flow.finishOrganizing(story)
        }) {
            SectionHeader(title: "Name your story", systemImage: Symbols.rename, tone: .brick)
            CurrentName(story: story)
            Text("What would you like to call it?")
                .appFont(.question)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            TextEntryField(
                example: "For example: The summer at the lake. Leave it empty to keep the name it has.",
                text: $name,
                isFocused: $isTyping
            )
            TypingTip()
        } footer: {
            BigButton(
                StoryTitles.cleaned(name).isEmpty ? "Keep this name" : "Save the name",
                systemImage: Symbols.done,
                tone: .brick,
                size: .large
            ) {
                isTyping = false
                flow.saveName(name, for: story)
            }
        }
    }
}

/// After saving: who's in the story. Each tap is saved straight away.
struct SavedPeopleView: View {
    let flow: TellAStoryFlow
    let story: Story

    @Query(sort: \Person.sortOrder) private var people: [Person]

    var body: some View {
        ScreenScaffold(back: BackAction(title: "Saved") {
            flow.finishOrganizing(story)
        }) {
            SectionHeader(title: "Choose the people in it", systemImage: Symbols.people, tone: .brick)
            CurrentName(story: story)
            if people.isEmpty {
                EmptyStateMessage(
                    title: "No one here yet",
                    message: "Your family will add the people in your life, with their photos. Then you can choose them here."
                )
            } else {
                Instruction("Tap everyone who's part of this story. Tap again to take someone off.")
                PeopleGrid(people: people, selected: Set((story.people ?? []).map(\.persistentModelID))) { person in
                    StoryEditing.togglePerson(person, in: story)
                }
            }
        } footer: {
            BigButton("Done", systemImage: Symbols.done, tone: .brick, size: .large) {
                flow.finishOrganizing(story)
            }
        }
    }
}

/// The story's current name, under a screen's title, so he always knows
/// which story he's changing.
struct CurrentName: View {
    let story: Story

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Now called")
                .appFont(.caption)
                .foregroundStyle(Palette.softInk)
            Text("\u{201C}\(story.displayTitle)\u{201D}")
                .appFont(.subtitle)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
