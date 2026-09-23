import SwiftUI

/// Step 1: one question, "Read it to me", "Start talking", "A different question".
struct QuestionStepView: View {
    let flow: TellAStoryFlow

    @Environment(QuestionReader.self) private var reader

    var body: some View {
        ScreenScaffold {
            SectionHeader(title: "Tell a story", systemImage: Symbols.tell, tone: .brick)
            if flow.showsTooShortNote {
                Text("That was very short. Take your time and try again.")
                    .appFont(.bodyBold)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
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
