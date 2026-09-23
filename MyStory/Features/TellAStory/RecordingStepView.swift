import SwiftUI

/// Step 2: listening. The question stays on screen, full size, so he never has
/// to hold it in his head. There is no Home button and no clock here, so
/// nothing can cut a story short and nothing hurries him; "I'm finished" is
/// the only way on.
struct RecordingStepView: View {
    let flow: TellAStoryFlow

    @Environment(StoryRecorder.self) private var recorder

    var body: some View {
        let isInterrupted = recorder.state == .interrupted
        ScreenScaffold(showsTopBar: false) {
            SectionHeader(title: "Tell a story", systemImage: Symbols.tell, tone: .brick)
            InfoCard(spacing: 10) {
                if let photo = flow.prompt.photo {
                    StoredImage(cacheKey: photo.imageCacheKey, data: photo.imageData ?? photo.thumbnailData, placeholderSymbol: Symbols.photo)
                        .frame(maxWidth: .infinity)
                        .frame(height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                if let person = flow.prompt.aboutPerson {
                    PersonBadge(person: person)
                }
                Text("You're answering")
                    .appFont(.caption)
                    .foregroundStyle(Palette.softInk)
                Text(flow.prompt.text)
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
}
