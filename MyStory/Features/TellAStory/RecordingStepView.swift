import SwiftUI

/// Listening. What he's talking about stays on screen, full size, so he never
/// has to hold it in his head. There is no Home button and no clock here, so
/// nothing can cut a story short and nothing hurries him; "I'm finished" is
/// the only way on.
struct RecordingStepView: View {
    let flow: TellAStoryFlow

    @Environment(StoryRecorder.self) private var recorder

    var body: some View {
        let isInterrupted = recorder.state == .interrupted
        ScreenScaffold(showsTopBar: false) {
            InfoCard(spacing: 10) {
                if flow.kind == .question, let photo = flow.prompt.photo {
                    WholePhoto(cacheKey: photo.imageCacheKey, data: photo.imageData ?? photo.thumbnailData, maxHeight: 150)
                }
                if let person = flow.aboutPerson ?? (flow.kind == .question ? flow.prompt.aboutPerson : nil) {
                    PersonBadge(person: person)
                }
                Text(flow.kind == .question ? "You're answering" : "Your story")
                    .appFont(.caption)
                    .foregroundStyle(Palette.softInk)
                Text(subject)
                    .appFont(.question)
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
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            Text("It keeps listening until you tap I'm finished. Everything saves as you talk.")
                .appFont(.caption)
                .foregroundStyle(Palette.softInk)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
        } footer: {
            VStack(spacing: Metrics.sectionSpacing) {
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

    /// The question, or the name he gave his own story.
    private var subject: String {
        if flow.kind == .question {
            return flow.prompt.text
        }
        let name = StoryTitles.cleaned(flow.ownTitle)
        return name.isEmpty ? "Talk about anything you like" : name
    }
}
