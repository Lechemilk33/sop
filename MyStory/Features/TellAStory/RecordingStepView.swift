import SwiftUI

/// Listening. What he's talking about stays on screen, full size, so he never
/// has to hold it in his head. There is no Home button and no clock here, so
/// nothing can cut a story short and nothing hurries him; "I'm finished" is
/// the only way on.
struct RecordingStepView: View {
    let flow: TellAStoryFlow

    @Environment(StoryRecorder.self) private var recorder

    var body: some View {
        let isSaving = flow.isSaving || recorder.state == .finishing
        let isInterrupted = !isSaving && recorder.state == .interrupted
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
                RecorderLevelIndicator(isSaving: isSaving)
                Text(isSaving ? "Saving your story" : (isInterrupted ? "Paused for a moment" : "I'm listening"))
                    .appFont(.screenTitle)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(message(isSaving: isSaving, isInterrupted: isInterrupted))
                    .appFont(.bodyBold)
                    .foregroundStyle(Palette.softInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            if !isSaving {
                Text("It keeps listening until you tap I'm finished. Everything saves as you talk.")
                    .appFont(.caption)
                    .foregroundStyle(Palette.softInk)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } footer: {
            // While it saves there's nothing to tap, so nothing can go wrong.
            if !isSaving {
                VStack(spacing: Metrics.sectionSpacing) {
                    if isInterrupted {
                        BigButton("Keep going", systemImage: Symbols.tell, tone: .brick, size: .large) {
                            recorder.resume()
                        }
                    }
                    BigButton("I'm finished", systemImage: Symbols.stop, tone: .ink, size: .large) {
                        Task { await flow.finishRecording() }
                    }
                }
            }
        }
    }

    private func message(isSaving: Bool, isInterrupted: Bool) -> String {
        if isSaving {
            return "Just a moment."
        }
        if isInterrupted {
            return recorder.couldNotResume
                ? "Your iPhone is busy with something else. Try Keep going again in a moment."
                : "Tap Keep going when you're ready."
        }
        return "Take your time. There's no rush."
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

/// Reads his voice level itself, so only the indicator redraws ten times a
/// second while he talks, not the whole screen.
private struct RecorderLevelIndicator: View {
    let isSaving: Bool

    @Environment(StoryRecorder.self) private var recorder

    var body: some View {
        ListeningIndicator(
            level: isSaving ? 0 : recorder.level,
            isListening: !isSaving && recorder.state == .recording,
            isSaving: isSaving
        )
    }
}
