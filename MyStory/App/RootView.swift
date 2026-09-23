import SwiftUI

/// Shows the first-run setup, or his screens. The family area opens over
/// everything once the family code is entered.
struct RootView: View {
    @Environment(Router.self) private var router
    @Environment(AppSettings.self) private var settings
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var appState = appState
        ZStack {
            Palette.paper.ignoresSafeArea()
            if settings.hasCompletedSetup {
                screen(for: router.current)
                    .id(router.currentID)
                    .transition(.opacity)
            } else {
                FamilySetupView()
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: router.currentID)
        .fullScreenCover(isPresented: $appState.isFamilyAreaPresented) {
            FamilyAreaView()
        }
    }

    @ViewBuilder
    private func screen(for screen: Screen) -> some View {
        switch screen {
        case .home:
            HomeView()
        case .tellStory(let seed):
            TellAStoryView(seed: seed)
        case .myLife:
            MyLifeView()
        case .chapter(let chapter):
            ChapterView(chapter: chapter)
        case .player(let request):
            StoryPlayerView(request: request)
        case .myPeople:
            MyPeopleView()
        case .person(let person):
            PersonView(person: person)
        case .personStories(let person):
            PersonStoriesView(person: person)
        case .familyGate:
            FamilyGateView()
        }
    }
}

/// Shown only if the stored stories can't be opened at all.
struct StartupErrorView: View {
    let details: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Something went wrong")
                .appFont(.screenTitle)
            Text("My Story couldn't open. Please close the app and open it again. If this keeps happening, restart the iPhone.")
                .appFont(.body)
            if let details {
                Text(details)
                    .font(.footnote)
                    .foregroundStyle(Palette.softInk)
            }
        }
        .foregroundStyle(Palette.ink)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.paper.ignoresSafeArea())
    }
}
