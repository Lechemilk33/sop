import SwiftData
import SwiftUI

/// Hosts the three steps of telling a story.
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
                Palette.paper.ignoresSafeArea()
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
