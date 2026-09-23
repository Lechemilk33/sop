import Observation
import SwiftUI

/// Every place in his part of the app.
enum Screen {
    case home
    case tellStory(PromptSeed)
    case myLife
    case chapter(Chapter)
    case player(PlaybackRequest)
    case myPeople
    case person(Person)
    case personStories(Person)
    case familyGate

    /// The name shown on the "back" button of the next screen.
    var title: String {
        switch self {
        case .home: "Home"
        case .tellStory: "Tell a story"
        case .myLife: "My life"
        case .chapter(let chapter): chapter.name
        case .player: "The story"
        case .myPeople: "My people"
        case .person(let person): person.name
        case .personStories(let person): "Stories with \(person.name)"
        case .familyGate: "For family"
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

    func pop() {
        guard !stack.isEmpty else { return }
        stack.removeLast()
    }

    func goHome() {
        stack.removeAll()
    }

    /// Swaps the current screen for another, e.g. "Saved" → "Listen to it".
    func replaceTop(with screen: Screen) {
        if !stack.isEmpty { stack.removeLast() }
        stack.append(Route(screen: screen))
    }
}

/// The top bar wired to the router.
struct ScreenTopBar: View {
    @Environment(Router.self) private var router

    var body: some View {
        TopBar(
            backTitle: router.backTitle,
            onBack: { router.pop() },
            onHome: { router.goHome() }
        )
    }
}
