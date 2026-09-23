import SwiftUI

/// Shows the first-run setup, or his screens. The family area opens over
/// everything once the family code is entered.
struct RootView: View {
    @Environment(Router.self) private var router
    @Environment(AppSettings.self) private var settings
    @Environment(AppState.self) private var appState
    @Environment(AppServices.self) private var services
    @Environment(StoryRecorder.self) private var recorder
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var backgroundedAt: Date?

    /// After this long away, he comes back to Home rather than a deep screen.
    private let returnHomeAfter: TimeInterval = 10 * 60

    var body: some View {
        @Bindable var appState = appState
        ZStack {
            Palette.paper.ignoresSafeArea()
            if settings.hasCompletedSetup {
                screen(for: router.current)
                    .id(router.currentID)
                    .transition(.opacity)
                    // Never smaller than the iPhone's default text size on his screens.
                    .dynamicTypeSize(.large...)
            } else {
                FamilySetupView()
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: router.currentID)
        .fullScreenCover(isPresented: $appState.isFamilyAreaPresented) {
            FamilyAreaView()
        }
        .onChange(of: scenePhase) { _, phase in
            handle(phase)
        }
    }

    private func handle(_ phase: ScenePhase) {
        switch phase {
        case .background:
            backgroundedAt = Date()
            // The family area never stays open for him to find later.
            appState.isFamilyAreaPresented = false
        case .active:
            if let since = backgroundedAt,
               Date().timeIntervalSince(since) > returnHomeAfter,
               recorder.state == .idle {
                router.goHome()
            }
            backgroundedAt = nil
            Task { await services.didBecomeActive() }
        default:
            break
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
