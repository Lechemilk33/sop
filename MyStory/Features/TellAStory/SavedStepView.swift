import Accessibility
import SwiftUI

/// "Saved", with exactly where the story went, and a way to name it and
/// choose who's in it straight away.
struct SavedStepView: View {
    let flow: TellAStoryFlow
    let story: Story

    @Environment(Router.self) private var router
    @Environment(AppSettings.self) private var settings

    var body: some View {
        ScreenScaffold {
            VStack(spacing: 18) {
                Image(systemName: Symbols.saved)
                    .font(.system(size: 58, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 124, height: 124)
                    .background(Circle().fill(Palette.green))
                    .accessibilityHidden(true)
                Text("Saved")
                    .appFont(.personName)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .appFont(.subtitle)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let stopNote {
                    Text(stopNote)
                        .appFont(.bodyBold)
                        .foregroundStyle(Palette.softInk)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        } footer: {
            VStack(spacing: Metrics.itemSpacing) {
                BigButton("Listen to it", systemImage: Symbols.play, tone: .marigold, size: .regular) {
                    router.replaceTop(with: .player(.single(story)))
                }
                BigButton("Name it and add people", systemImage: Symbols.organize, tone: .outline, size: .regular) {
                    flow.nameSavedStory(story)
                }
                BigButton("Tell another story", systemImage: Symbols.tell, tone: .brick, size: .regular) {
                    flow.startOver()
                }
            }
        }
        .onAppear {
            let announcement: String = "Saved"
            AccessibilityNotification.Announcement(announcement).post()
        }
    }

    /// Only a name he chose is quoted; an answer isn't called by its question.
    private var message: String {
        let thanks = settings.displayName.isEmpty ? "Thank you." : "Thank you, \(settings.displayName)."
        let what = story.promptText.isEmpty || story.title != story.promptText
            ? "\u{201C}\(story.displayTitle)\u{201D}"
            : "Your answer"
        if let chapter = story.chapter {
            return "\(thanks) \(what) is in My stories, under \(chapter.name)."
        }
        return "\(thanks) \(what) is in My stories."
    }

    private var stopNote: String? {
        switch flow.stopReason {
        case .storageAlmostFull:
            "The iPhone is almost full, so it stopped here. Ask your family to make some room."
        case .systemStopped:
            "The recording stopped here. Everything up to that point is saved."
        case .safetyLimit:
            "That was a long one, so it stopped here. You can tell more any time."
        case nil:
            nil
        }
    }
}

/// When a story couldn't be stored right away. It is safe on the iPhone and
/// the app adds it by itself as soon as it can.
struct KeptSafeView: View {
    var body: some View {
        ScreenScaffold {
            SectionHeader(title: "Tell a story", systemImage: Symbols.tell, tone: .brick)
            EmptyStateMessage(
                title: "Your story is safe",
                message: "It's kept on this iPhone and will appear in My stories soon. Your family can find it in the Family area."
            )
        }
    }
}

/// If the microphone is off, say so plainly and point to the family.
struct MicrophoneOffView: View {
    var body: some View {
        ScreenScaffold {
            SectionHeader(title: "Tell a story", systemImage: Symbols.microphoneOff, tone: .ink)
            EmptyStateMessage(
                title: "The microphone is turned off",
                message: "Ask your family to open the Family area and turn on the microphone for My Story."
            )
        }
    }
}
