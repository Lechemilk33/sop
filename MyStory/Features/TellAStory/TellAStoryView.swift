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
            let newFlow = TellAStoryFlow(
                seed: seed,
                context: context,
                recorder: recorder,
                reader: reader,
                transcription: transcription,
                readsAutomatically: settings.readQuestionsAutomatically
            )
            flow = newFlow
            newFlow.readIfAutomatic()
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
                minHeight: Metrics.largeButtonHeight + 12
            ) {
                flow.chooseOwnStory()
            }
            PlaceTile(
                title: "Answer a question",
                subtitle: "Get a question to start you off",
                systemImage: Symbols.question,
                tone: .brick,
                minHeight: Metrics.largeButtonHeight + 12
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
        ScreenScaffold(back: backAction) {
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
                placeholder: "For example: The summer at the lake",
                text: $flow.ownTitle,
                isFocused: $isTyping
            )
            Text("You can skip this and name it later. To say it instead of typing, tap the microphone on the keyboard.")
                .appFont(.caption)
                .foregroundStyle(Palette.softInk)
                .fixedSize(horizontal: false, vertical: true)
        } footer: {
            BigButton("Start talking", systemImage: Symbols.tell, tone: .brick, size: .large) {
                isTyping = false
                Task { await flow.startRecording() }
            }
        }
    }

    private var backAction: BackAction? {
        guard flow.canGoBackToChoice else { return nil }
        return BackAction(title: "Tell a story") {
            isTyping = false
            flow.backToChoice()
        }
    }
}
