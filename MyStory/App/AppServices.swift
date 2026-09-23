import Observation
import SwiftData
import SwiftUI

/// Everything the app needs, created once at launch.
@MainActor
@Observable
final class AppServices {
    /// Services that need the stored data.
    struct Live {
        let container: ModelContainer
        let transcription: TranscriptionService
    }

    let settings: AppSettings
    let router = Router()
    let appState = AppState()
    let recorder = StoryRecorder()
    let player = StoryPlayer()
    let clipPlayer = ClipPlayer()
    let reader = QuestionReader()
    let familyLock = FamilyLock()
    let live: Live?
    let startupError: String?

    private var hasStarted = false

    init(inMemory: Bool = false) {
        settings = AppSettings()
        do {
            let container = try PersistenceController.makeContainer(inMemory: inMemory)
            live = Live(container: container, transcription: TranscriptionService(container: container))
            startupError = nil
        } catch {
            live = nil
            startupError = error.localizedDescription
        }
    }

    /// Runs once after launch: built-in questions, rescuing any story that was
    /// being recorded when the app closed, and finishing transcriptions.
    func start() async {
        guard !hasStarted, let live else { return }
        hasStarted = true
        familyLock.applyResetRequestIfNeeded()
        let context = live.container.mainContext
        try? Seeder.run(in: context)
        await RecordingRecovery.recoverUnfinishedRecordings(into: context, transcription: live.transcription)
        live.transcription.enqueueUnfinished()
        await live.transcription.refreshReadiness()
    }

    /// Each time the app comes back to the front: apply a family-code reset
    /// from the Settings app, and rescue any story that couldn't be stored
    /// earlier (never while something is being recorded).
    func didBecomeActive() async {
        guard hasStarted, let live else { return }
        familyLock.applyResetRequestIfNeeded()
        if recorder.state == .idle {
            await RecordingRecovery.recoverUnfinishedRecordings(into: live.container.mainContext, transcription: live.transcription)
        }
    }
}

/// App-wide presentation state.
@MainActor
@Observable
final class AppState {
    var isFamilyAreaPresented = false
}

extension View {
    /// Makes every service available to the views below.
    func withServices(_ services: AppServices, live: AppServices.Live) -> some View {
        self
            .modelContainer(live.container)
            .environment(services)
            .environment(services.settings)
            .environment(services.router)
            .environment(services.appState)
            .environment(services.recorder)
            .environment(services.player)
            .environment(services.clipPlayer)
            .environment(services.reader)
            .environment(live.transcription)
    }
}
