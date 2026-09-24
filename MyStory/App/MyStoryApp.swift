import SwiftUI

@main
struct MyStoryApp: App {
    @State private var services: AppServices

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
        }
    }
}
