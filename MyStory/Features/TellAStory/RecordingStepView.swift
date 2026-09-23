import SwiftUI

/// Step 2: listening. The question stays on screen so he never has to hold it
/// in his head. There is no Home button here, so a stray tap can't cut a
/// story short; "I'm finished" is the only way on.
struct RecordingStepView: View {
    let flow: TellAStoryFlow

    @Environment(StoryRecorder.self) private var recorder

    var body: some View {
        let isInterrupted = recorder.state == .interrupted
        ScreenScaffold(showsTopBar: false) {
            SectionHeader(title: "Tell a story", systemImage: Symbols.tell, tone: .brick)
            InfoCard(spacing: 6) {
                Text("You're answering")
                    .appFont(.caption)
                    .foregroundStyle(Palette.softInk)
                Text(flow.prompt.text)
                    .appFont(.subtitle)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 12) {
                ListeningIndicator(level: recorder.level, isListening: recorder.state == .recording)
                Text(isInterrupted ? "Paused for a moment" : "I'm listening")
                    .appFont(.screenTitle)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(isInterrupted ? "Tap Keep going when you're ready." : "Take your time. There's no rush.")
                    .appFont(.bodyBold)
                    .foregroundStyle(Palette.softInk)
                    .multilineTextAlignment(.center)
                Text(DurationText.clock(recorder.elapsed))
                    .appFont(.bodyBold)
                    .monospacedDigit()
                    .foregroundStyle(Palette.softInk)
                    .accessibilityLabel(Text("Recorded \(DurationText.spoken(recorder.elapsed))"))
            }
            .frame(maxWidth: .infinity)
            Text("It keeps listening until you tap I'm finished. Everything saves as you talk.")
                .appFont(.caption)
                .foregroundStyle(Palette.softInk)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
        } footer: {
            VStack(spacing: Metrics.itemSpacing) {
                if isInterrupted {
                    BigButton("Keep going", systemImage: Symbols.tell, tone: .brick, size: .large) {
                        recorder.resume()
                    }
                }
                BigButton(
                    flow.isSaving ? "Saving…" : "I'm finished",
                    systemImage: Symbols.stop,
                    tone: .ink,
                    size: .large
                ) {
                    Task { await flow.finishRecording() }
                }
                .disabled(flow.isSaving)
            }
        }
    }
}
