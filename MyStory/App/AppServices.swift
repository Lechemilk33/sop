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
    let copyMaker = CopyMaker()
    let cloudSync = CloudSyncMonitor()
    private(set) var live: Live?
    private(set) var startupError: String?

    private let inMemory: Bool
    @ObservationIgnored private var hasStarted = false
    /// Two rescue passes at once could both pick up the same file.
    @ObservationIgnored private var isRecovering = false
    /// Built-in chapters and questions from another iPhone arrived through
    /// iCloud and need tidying, which waits until he's back on Home.
    @ObservationIgnored private var needsTidying = false

    init(inMemory: Bool = false) {
        settings = AppSettings()
        self.inMemory = inMemory
        openStoreIfNeeded()
    }

    /// Opens the stored stories. Right after the iPhone restarts, before it's
    /// first unlocked, they can't be read yet, so this is tried again each
    /// time the app comes to the front.
    func openStoreIfNeeded() {
        guard live == nil else { return }
        do {
            let container = try PersistenceController.makeContainer(inMemory: inMemory)
            live = Live(container: container, transcription: TranscriptionService(container: container))
            startupError = nil
        } catch {
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
        // With iCloud on, another iPhone's copies of the built-in chapters
        // and questions can arrive at any time; they're merged the next time
        // he's on Home.
        cloudSync.onDownloadFinished = { [weak self] in
            self?.needsTidying = true
            self?.tidyIfNeeded()
        }
        cloudSync.start()
        await recoverRecordings(live)
        live.transcription.enqueueUnfinished()
        await live.transcription.refreshReadiness()
        await PortraitRefresh.runIfNeeded(in: context)
    }

    /// Each time the app comes back to the front: apply a family-code reset
    /// from the Settings app, rescue any story that couldn't be stored
    /// earlier (never while something is being recorded), and carry on
    /// writing down stories that were cut short.
    func didBecomeActive() async {
        guard hasStarted, let live else { return }
        familyLock.applyResetRequestIfNeeded()
        if recorder.state == .idle {
            await recoverRecordings(live)
        }
        live.transcription.enqueueUnfinished()
    }

    /// Called when he's on Home, where no screen can be showing a chapter or
    /// question that tidying removes.
    func tidyIfNeeded() {
        guard needsTidying, router.stack.isEmpty, !appState.isFamilyAreaPresented, let live else { return }
        needsTidying = false
        try? Seeder.run(in: live.container.mainContext)
    }

    private func recoverRecordings(_ live: Live) async {
        guard !isRecovering else { return }
        isRecovering = true
        defer { isRecovering = false }
        let rescue = Task {
            await RecordingRecovery.recoverUnfinishedRecordings(into: live.container.mainContext, transcription: live.transcription)
        }
        // If the phone is locked meanwhile, the story being rescued is
        // finished, and the rest wait for next time.
        let activity = BackgroundActivity("Rescue stories") {
            rescue.cancel()
        }
        await rescue.value
        activity.end()
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
