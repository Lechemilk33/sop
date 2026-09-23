import SwiftUI

/// Research-based tips for whoever sits with him while he tells stories.
/// Sources are listed in PLAN.md.
struct TipsView: View {
    @Environment(AppSettings.self) private var settings

    private var name: String {
        settings.displayName.isEmpty ? "him" : settings.displayName
    }

    var body: some View {
        List {
            tipSection("Let him lead", [
                "Sit beside \(name), not across. Hold the phone so he can see the question.",
                "Let the story go wherever it goes. Wandering off topic is part of it.",
                "Pauses are fine. Count to ten in your head before saying anything.",
            ])
            tipSection("Invite, don't quiz", [
                "Never ask \u{201C}Do you remember…?\u{201D}. Try \u{201C}Tell me about…\u{201D} instead.",
                "Follow up with \u{201C}What happened next?\u{201D}, \u{201C}Who was there?\u{201D}, \u{201C}How did that feel?\u{201D}",
                "Skip dates and exact years. They don't matter to the story.",
            ])
            tipSection("Never correct", [
                "If a detail is different from how you remember it, let it be. It's his story.",
                "Don't finish his sentences unless he asks for help.",
            ])
            tipSection("Keep it light", [
                "Short sessions are best: 15 to 30 minutes, at the time of day he's at his best.",
                "Stop while it's still enjoyable. There's always another day.",
                "Old photos and music are wonderful prompts. Add photos in the family area.",
            ])
            tipSection("Hard topics", [
                "If a question upsets him, move on. You can switch off any question in Questions.",
                "Ask him now how he'd want difficult subjects handled later, and write down his wishes. Be consistent with them.",
            ])
        }
        .familyBackground()
        .navigationTitle("Tips")
    }

    private func tipSection(_ title: String, _ tips: [String]) -> some View {
        Section(title) {
            ForEach(tips, id: \.self) { tip in
                Text(tip)
                    .padding(.vertical, 2)
            }
        }
    }
}
