import Accessibility
import SwiftUI

/// Step 3: "Saved", with exactly where the story went.
struct SavedStepView: View {
    let flow: TellAStoryFlow
    let story: Story

    @Environment(Router.self) private var router
    @Environment(AppSettings.self) private var settings

    var body: some View {
        ScreenScaffold(showsTopBar: false) {
            VStack(spacing: 18) {
                Image(systemName: Symbols.saved)
                    .font(.system(size: 64, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 132, height: 132)
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
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 32)
        } footer: {
            VStack(spacing: Metrics.itemSpacing) {
                BigButton("Listen to it", systemImage: Symbols.play, tone: .marigold, size: .large) {
                    router.replaceTop(with: .player(.single(story)))
                }
                BigButton("Tell another story", systemImage: Symbols.tell, tone: .brick, size: .large) {
                    flow.startOver()
                }
                BigButton("Home", systemImage: Symbols.home, tone: .outline, size: .regular) {
                    router.goHome()
                }
            }
        }
        .onAppear {
            let announcement: String = "Saved"
            AccessibilityNotification.Announcement(announcement).post()
        }
    }

    private var message: String {
        let thanks = settings.displayName.isEmpty ? "Thank you." : "Thank you, \(settings.displayName)."
        if let chapter = story.chapter {
            return "\(thanks) It's in My life, under \(chapter.name)."
        }
        return "\(thanks) It's in My life."
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
