import SwiftUI

@main
struct MyStoryApp: App {
    @State private var services: AppServices
    @Environment(\.scenePhase) private var scenePhase

    init() {
        FontRegistrar.registerBundledFonts()
        AudioSessionController.configureForPlayback()
        _services = State(initialValue: AppServices())
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let live = services.live {
                    RootView()
                        .withServices(services, live: live)
                        .task { await services.start() }
                } else {
                    StartupErrorView(details: services.startupError)
                }
            }
            .environment(\.textScale, services.settings.textSize.scale)
            .environment(\.usesExtraClearLetters, services.settings.usesExtraClearLetters)
            .preferredColorScheme(.light)
            .tint(Palette.blue)
            .onChange(of: scenePhase) { _, phase in
                // The stored stories can't be read until the iPhone is first
                // unlocked after a restart; try again once it's in front.
                if phase == .active {
                    services.openStoreIfNeeded()
                }
            }
        }
    }
}
