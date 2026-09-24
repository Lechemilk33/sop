import Observation
import SwiftUI

/// Every place in his part of the app.
enum Screen {
    case home
    case tellStory(PromptSeed)
    case myStories
    case allStories
    case chapter(Chapter)
    case player(PlaybackRequest)
    /// "About this story": its name, who's in it, its chapter and photo.
    case storyDetails(Story)
    case renameStory(Story)
    case storyPeople(Story)
    case storyChapter(Story)
    case storyPhoto(Story)
    /// A new chapter, optionally with a story to put in it straight away.
    case newChapter(for: Story?)
    case editChapter(Chapter)
    case myPeople
    case person(Person)
    case personStories(Person)
    case familyGate

    /// The name shown on the "back" button of the next screen.
    var title: String {
        switch self {
        case .home: "Home"
        case .tellStory: "Tell a story"
        case .myStories: "My stories"
        case .allStories: "All my stories"
        case .chapter(let chapter): chapter.name
        case .player: "The story"
        case .storyDetails: "About this story"
        case .renameStory: "Name"
        case .storyPeople: "Who's in it"
        case .storyChapter: "Chapter"
        case .storyPhoto: "Photo"
        case .newChapter: "New chapter"
        case .editChapter: "Chapter"
        case .myPeople: "My people"
        case .person(let person): person.name
        case .personStories(let person): "Stories with \(person.name)"
        case .familyGate: "For family"
        }
    }

    /// Which of the three places the screen belongs to, for its colors.
    var place: Tone? {
        switch self {
        case .home, .familyGate: nil
        case .tellStory: .brick
        case .myPeople, .person, .personStories: .blue
        case .myStories, .allStories, .chapter, .player, .storyDetails, .renameStory,
             .storyPeople, .storyChapter, .storyPhoto, .newChapter, .editChapter: .marigold
        }
    }
}

struct Route: Identifiable {
    let id = UUID()
    let screen: Screen
}

/// Simple, predictable navigation: a stack of screens with Home at the bottom.
/// There are no swipe gestures; he moves only by tapping labeled buttons.
@MainActor
@Observable
final class Router {
    private(set) var stack: [Route] = []
    /// The item he last opened on each screen, so coming back to a long list
    /// shows the same place instead of the top.
    @ObservationIgnored private var anchors: [UUID: AnyHashable] = [:]

    var current: Screen { stack.last?.screen ?? .home }
    var currentID: UUID? { stack.last?.id }

    /// The previous screen's name, or `nil` when the previous screen is Home
    /// (Home has its own button in the top-right corner).
    var backTitle: String? {
        guard stack.count >= 2 else { return nil }
        return stack[stack.count - 2].screen.title
    }

    func push(_ screen: Screen) {
        stack.append(Route(screen: screen))
    }

    func pop(_ count: Int = 1) {
        stack.removeLast(min(max(0, count), stack.count))
        forgetAnchors()
    }

    func goHome() {
        stack.removeAll()
        forgetAnchors()
    }

    /// Swaps the current screen for another, e.g. "Saved" → "Listen to it".
    func replaceTop(with screen: Screen) {
        if !stack.isEmpty { stack.removeLast() }
        stack.append(Route(screen: screen))
        forgetAnchors()
    }

    /// Remembers what he's opening from the current screen (Home has none).
    func remember(_ anchor: some Hashable) {
        guard let id = currentID else { return }
        anchors[id] = AnyHashable(anchor)
    }

    func anchor(for id: UUID?) -> AnyHashable? {
        id.flatMap { anchors[$0] }
    }

    private func forgetAnchors() {
        let live = Set(stack.map(\.id))
        anchors = anchors.filter { live.contains($0.key) }
    }
}

/// The top bar wired to the router. A screen can say where its back button
/// goes instead of the previous screen.
struct ScreenTopBar: View {
    var back: BackAction?

    @Environment(Router.self) private var router

    var body: some View {
        if let back {
            TopBar(backTitle: back.title, onBack: back.action, onHome: { router.goHome() })
        } else {
            TopBar(
                backTitle: router.backTitle,
                onBack: { router.pop() },
                onHome: { router.goHome() }
            )
        }
    }
}
