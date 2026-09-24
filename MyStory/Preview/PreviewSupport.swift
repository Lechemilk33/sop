#if DEBUG
import SwiftData
import SwiftUI

/// Sample data for Xcode previews. Never part of the real app.
@MainActor
enum PreviewSupport {
    static let services: AppServices = {
        let services = AppServices(inMemory: true)
        services.settings.personName = "Dave"
        services.settings.hasCompletedSetup = true
        guard let live = services.live else { return services }
        let context = live.container.mainContext
        try? Seeder.run(in: context)

        let emily = Person(name: "Emily", relationship: "My daughter", sortOrder: 0)
        context.insert(emily)
        emily.facts = ["Lives in Chicago with her husband, Jake.", "She's a nurse. Birthday: May 4."]
        let mike = Person(name: "Mike", relationship: "My brother", sortOrder: 1)
        context.insert(mike)
        let sam = Person(name: "Sam", relationship: "My best friend", sortOrder: 2)
        context.insert(sam)

        let parent = Seeder.chapter(forKey: "parent", in: context)
        let samples: [(String, TimeInterval)] = [
            ("Her first bike ride", 245),
            ("The lake trip, 2004", 372),
            ("Teaching her to drive", 188),
        ]
        for (index, sample) in samples.enumerated() {
            let story = Story(
                title: sample.0,
                promptText: "What were your kids like when they were little?",
                recordedAt: Date().addingTimeInterval(Double(-86_400 * (index + 1)))
            )
            context.insert(story)
            story.duration = sample.1
            story.chapter = parent
            story.people = [emily]
            story.transcript = "She was maybe five. She made me promise not to let go of the seat. I let go anyway, and she rode all the way to the mailbox."
            story.transcriptState = .done
        }
        try? context.save()
        return services
    }()
}

extension View {
    /// Wraps a preview with the sample services.
    func previewServices() -> some View {
        let services = PreviewSupport.services
        return Group {
            if let live = services.live {
                self.withServices(services, live: live)
            } else {
                self
            }
        }
    }
}

#Preview("Home") {
    HomeView().previewServices()
}

#Preview("My people") {
    MyPeopleView().previewServices()
}

#Preview("My stories") {
    MyStoriesView().previewServices()
}

#Preview("Tell a story") {
    TellAStoryView(seed: .start).previewServices()
}

#Preview("Family area") {
    FamilyAreaView().previewServices()
}
#endif
