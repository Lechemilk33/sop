import SwiftUI

/// One question, "Read it to me", "Start talking", "A different question".
struct QuestionStepView: View {
    let flow: TellAStoryFlow

    @Environment(QuestionReader.self) private var reader

    var body: some View {
        ScreenScaffold(back: BackAction(title: "Tell a story") { flow.backToChoice() }) {
            SectionHeader(title: "Answer a question", systemImage: Symbols.question, tone: .brick)
            if let note = flow.note {
                Instruction(note)
            }
            PromptCard(prompt: flow.prompt)
            BigButton(
                reader.isReading ? "Stop reading" : "Read it to me",
                systemImage: reader.isReading ? Symbols.stop : Symbols.read,
                tone: .outline,
                size: .compact
            ) {
                flow.toggleReading()
            }
        } footer: {
            VStack(spacing: Metrics.itemSpacing) {
                BigButton("Start talking", systemImage: Symbols.tell, tone: .brick, size: .large) {
                    Task { await flow.startRecording() }
                }
                BigButton("A different question", systemImage: Symbols.differentQuestion, tone: .outline, size: .regular) {
                    flow.nextQuestion()
                }
            }
        }
    }
}
